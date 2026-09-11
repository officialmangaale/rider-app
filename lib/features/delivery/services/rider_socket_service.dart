import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/app_constants.dart';
import '../models/delivery_models.dart';

class RiderSocketService {
  RiderSocketService({
    required this.tokenProvider,
    required this.onDeliveryOrderRequest,
    required this.onOrderRequestExpired,
    required this.onOrderAssignedToOther,
    required this.onRestaurantOwnedOrderAssigned,
    required this.onConnectionChanged,
  });

  /// Read on every connection attempt, never cached. The access token is
  /// refreshed behind this service's back by ApiClient; a token captured at
  /// construction is rejected by the server once it expires, and every
  /// reconnect after that fails while REST calls keep working.
  final String? Function() tokenProvider;
  final Function(RiderOrderRequestModel request) onDeliveryOrderRequest;
  final Function(int requestId, int orderId) onOrderRequestExpired;
  final Function(int requestId, int orderId) onOrderAssignedToOther;
  final Function(int orderId, int? restaurantId) onRestaurantOwnedOrderAssigned;
  final ValueChanged<bool> onConnectionChanged;

  static const _handshakeTimeout = Duration(seconds: 15);

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  int _reconnectAttempt = 0;

  /// Incremented for every new channel and on disconnect. Callbacks from an
  /// older channel compare against it and do nothing, so a channel being
  /// replaced cannot mark the live one disconnected or schedule a reconnect
  /// that opens a second parallel socket.
  int _generation = 0;
  final Random _random = Random();
  final Set<String> _seenEventIds = <String>{};

  String get _token => (tokenProvider() ?? '').trim();

  void connect() {
    if (_isConnected || _isConnecting) {
      _debug(
        'connect skipped connected=$_isConnected connecting=$_isConnecting',
      );
      return;
    }
    if (_token.isEmpty) {
      _debug('connect skipped tokenPresent=false');
      return;
    }
    _shouldReconnect = true;
    _reconnectTimer?.cancel();
    _connectInternal();
  }

  void _connectInternal() {
    final token = _token;
    if (token.isEmpty) {
      // Signed out between attempts. Reconnecting would only be rejected.
      _debug('reconnect stopped tokenPresent=false');
      _isConnecting = false;
      _setConnected(false);
      return;
    }

    final generation = ++_generation;
    final previous = _channel;
    _channel = null;
    previous?.sink.close();

    _isConnecting = true;
    try {
      final uri = Uri.parse(
        AppConstants.riderWsUrl,
      ).replace(queryParameters: {'token': token});
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      _debug('connecting generation=$generation');
      unawaited(
        // Bounded, so a handshake that never completes cannot leave the
        // service "connecting" forever and skipping every later connect().
        channel.ready
            .timeout(_handshakeTimeout)
            .then((_) {
              if (generation != _generation) return;
              _isConnecting = false;
              _reconnectAttempt = 0;
              _setConnected(true);
              _debug('connected generation=$generation');
            })
            .catchError((Object error) {
              if (generation != _generation) return;
              _isConnecting = false;
              channel.sink.close();
              _setConnected(false);
              // The handshake status is not exposed here; a 401 (bad token)
              // and a 400 (proxy dropped the upgrade) look the same.
              _debug('connection failed generation=$generation error=$error');
              _scheduleReconnect();
            }),
      );

      channel.stream.listen(
        (message) {
          if (generation != _generation) return;
          _setConnected(true);
          _handleMessage(message);
        },
        onDone: () {
          if (generation != _generation) return;
          _isConnecting = false;
          _debug('disconnected generation=$generation');
          _setConnected(false);
          _scheduleReconnect();
        },
        onError: (Object error) {
          if (generation != _generation) return;
          _isConnecting = false;
          _debug('stream error generation=$generation error=$error');
          _setConnected(false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _isConnecting = false;
      _debug('connect error=$e');
      _setConnected(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    final exponent = min(_reconnectAttempt++, 8);
    final baseMilliseconds = min(1000 * (1 << exponent), 30000);
    final jitter = _random.nextInt(max(250, baseMilliseconds ~/ 4));
    _reconnectTimer = Timer(
      Duration(milliseconds: baseMilliseconds + jitter),
      () {
        if (!_shouldReconnect || _isConnected) return;
        _connectInternal();
      },
    );
  }

  void _handleMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message as String) as Map<String, dynamic>;
      final eventId = '${decoded['event_id'] ?? ''}'.trim();
      if (eventId.isNotEmpty) {
        if (_seenEventIds.contains(eventId)) return;
        _seenEventIds.add(eventId);
        if (_seenEventIds.length > 2000) {
          _seenEventIds.remove(_seenEventIds.first);
        }
      }
      final type = decoded['type'] as String?;
      final normalizedType = (type ?? '').trim().toUpperCase();
      final data = _asMap(decoded['data']);
      _debug('event type=${type ?? 'missing'}');

      if (normalizedType == 'DELIVERY_ORDER_REQUEST') {
        onDeliveryOrderRequest(RiderOrderRequestModel.fromJson(data));
      } else if (normalizedType == 'ORDER_REQUEST_EXPIRED' ||
          normalizedType == 'REQUEST_EXPIRED') {
        final requestId = _asInt(data['request_id'] ?? decoded['request_id']);
        final orderId = _asInt(data['order_id'] ?? decoded['order_id']);
        onOrderRequestExpired(requestId, orderId);
      } else if (normalizedType == 'ORDER_ASSIGNED_TO_OTHER_RIDER') {
        final requestId = _asInt(data['request_id'] ?? decoded['request_id']);
        final orderId = _asInt(data['order_id'] ?? decoded['order_id']);
        onOrderAssignedToOther(requestId, orderId);
      } else if (normalizedType == 'ORDER_ASSIGNED' ||
          normalizedType == 'RIDER_ASSIGNED' ||
          normalizedType == 'RIDER_ASSIGNED_TO_ORDER') {
        final orderId = _asInt(data['order_id'] ?? decoded['order_id']);
        final restaurantId = _asIntOrNull(
          data['restaurant_id'] ?? decoded['restaurant_id'],
        );
        final assignmentType = '${data['assignment_type'] ?? ''}'
            .trim()
            .toLowerCase();
        if (orderId > 0 &&
            (assignmentType == 'restaurant_owned' ||
                assignmentType == 'restaurant_own_rider' ||
                normalizedType == 'RIDER_ASSIGNED')) {
          onRestaurantOwnedOrderAssigned(orderId, restaurantId);
        }
      } else if (normalizedType == 'ORDER_STATUS_UPDATED' ||
          normalizedType == 'DELIVERY_STATUS_UPDATED') {
        final orderId = _asInt(data['order_id'] ?? decoded['order_id']);
        if (orderId > 0) {
          onRestaurantOwnedOrderAssigned(
            orderId,
            _asIntOrNull(data['restaurant_id']),
          );
        }
      }
    } catch (e) {
      _debug('parse error=$e');
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _generation++;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnecting = false;
    _seenEventIds.clear();
    _reconnectAttempt = 0;
    _setConnected(false);
  }

  void _setConnected(bool value) {
    if (_isConnected == value) {
      return;
    }
    _isConnected = value;
    onConnectionChanged(value);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return const <String, dynamic>{};
  }

  int _asInt(Object? value) => _asIntOrNull(value) ?? 0;

  int? _asIntOrNull(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  void _debug(String message) {
    assert(() {
      debugPrint('[RiderSocket] $message');
      return true;
    }());
  }
}
