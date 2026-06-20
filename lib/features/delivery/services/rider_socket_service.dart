import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/app_constants.dart';
import '../models/delivery_models.dart';

class RiderSocketService {
  RiderSocketService({
    required this.token,
    required this.onDeliveryOrderRequest,
    required this.onOrderRequestExpired,
    required this.onOrderAssignedToOther,
    required this.onRestaurantOwnedOrderAssigned,
    required this.onConnectionChanged,
  });

  final String token;
  final Function(RiderOrderRequestModel request) onDeliveryOrderRequest;
  final Function(int requestId, int orderId) onOrderRequestExpired;
  final Function(int requestId, int orderId) onOrderAssignedToOther;
  final Function(int orderId, int? restaurantId) onRestaurantOwnedOrderAssigned;
  final ValueChanged<bool> onConnectionChanged;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;

  void connect() {
    if (_isConnected || token.isEmpty) {
      _debug('connect skipped tokenPresent=${token.isNotEmpty}');
      return;
    }
    _shouldReconnect = true;
    _connectInternal();
  }

  void _connectInternal() {
    try {
      final uri = Uri.parse(AppConstants.riderWsUrl).replace(queryParameters: {
        'token': token,
      });
      _channel = WebSocketChannel.connect(uri);

      _debug('connecting tokenPresent=${token.isNotEmpty}');
      unawaited(
        _channel!.ready.then((_) {
          _setConnected(true);
          _debug('connected');
        }).catchError((error) {
          _setConnected(false);
          _debug('connection failed error=$error');
          _scheduleReconnect();
        }),
      );

      _channel!.stream.listen(
        (message) {
          _setConnected(true);
          _handleMessage(message);
        },
        onDone: () {
          _debug('disconnected');
          _setConnected(false);
          _scheduleReconnect();
        },
        onError: (error) {
          _debug('stream error=$error');
          _setConnected(false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _debug('connect error=$e');
      _setConnected(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connectInternal();
    });
  }

  void _handleMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message as String) as Map<String, dynamic>;
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
    _reconnectTimer?.cancel();
    _channel?.sink.close();
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
