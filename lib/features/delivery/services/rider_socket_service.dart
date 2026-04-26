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
  });

  final String token;
  final Function(RiderOrderRequestModel request) onDeliveryOrderRequest;
  final Function(int requestId, int orderId) onOrderRequestExpired;
  final Function(int requestId, int orderId) onOrderAssignedToOther;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _shouldReconnect = true;

  void connect() {
    if (_isConnected) return;
    _shouldReconnect = true;
    _connectInternal();
  }

  void _connectInternal() {
    try {
      final uri = Uri.parse(AppConstants.riderWsUrl).replace(queryParameters: {
        'token': token,
      });
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.stream.listen(
        (message) {
          _isConnected = true;
          _handleMessage(message);
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _isConnected = false;
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

      if (type == 'DELIVERY_ORDER_REQUEST') {
        onDeliveryOrderRequest(RiderOrderRequestModel.fromJson(decoded));
      } else if (type == 'ORDER_REQUEST_EXPIRED') {
        final requestId = decoded['request_id'] as int;
        final orderId = decoded['order_id'] as int;
        onOrderRequestExpired(requestId, orderId);
      } else if (type == 'ORDER_ASSIGNED_TO_OTHER_RIDER') {
        final requestId = decoded['request_id'] as int;
        final orderId = decoded['order_id'] as int;
        onOrderAssignedToOther(requestId, orderId);
      }
    } catch (e) {
      debugPrint('Error parsing websocket message: $e');
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }
}
