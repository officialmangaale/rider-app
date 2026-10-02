import 'dart:convert';

import 'delivery_models.dart';

enum DeliveryRequestAction { open, accept, decline }

/// Notifications are routing hints. Only the authenticated pending-offers API
/// can establish whether this rider may act on the request.
class DeliveryRequestIntent {
  const DeliveryRequestIntent({
    required this.requestId,
    this.orderId,
    this.expiresAt,
    this.action = DeliveryRequestAction.open,
  });

  final int requestId;
  final int? orderId;
  final DateTime? expiresAt;
  final DeliveryRequestAction action;

  bool matches(RiderOrderRequestModel request) =>
      requestId == request.requestId &&
      (orderId == null || orderId == request.orderId) &&
      (expiresAt == null || expiresAt!.isAtSameMomentAs(request.expiresAt));

  static DeliveryRequestIntent? fromPush(Map<String, dynamic> data) {
    if ('${data['type'] ?? ''}'.trim().toUpperCase() !=
        'DELIVERY_ORDER_REQUEST') {
      return null;
    }
    return _parse(data, DeliveryRequestAction.open);
  }

  static DeliveryRequestIntent? fromLocal(String? payload, String? actionId) {
    if (payload == null) return null;
    final action = switch (actionId) {
      'accept' => DeliveryRequestAction.accept,
      'decline' => DeliveryRequestAction.decline,
      _ => DeliveryRequestAction.open,
    };
    // Notifications posted by older builds have no action buttons.
    if (payload.startsWith('delivery_request:')) {
      final id = int.tryParse(payload.split(':').last);
      return id != null && id > 0 ? DeliveryRequestIntent(requestId: id) : null;
    }
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic> ||
          data['type'] != 'DELIVERY_ORDER_REQUEST') {
        return null;
      }
      return _parse(data, action);
    } on FormatException {
      return null;
    }
  }

  static DeliveryRequestIntent? _parse(
    Map<String, dynamic> data,
    DeliveryRequestAction action,
  ) {
    final id = int.tryParse('${data['request_id']}');
    final orderId = int.tryParse('${data['order_id']}');
    final expiry = DateTime.tryParse('${data['expires_at']}');
    if (id == null || id <= 0) return null;
    if (action != DeliveryRequestAction.open &&
        (orderId == null || orderId <= 0 || expiry == null)) {
      return null;
    }
    return DeliveryRequestIntent(
      requestId: id,
      orderId: orderId,
      expiresAt: expiry,
      action: action,
    );
  }
}
