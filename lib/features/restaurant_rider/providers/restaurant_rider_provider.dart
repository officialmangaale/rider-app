import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/core_providers.dart';

// ---------------------------------------------------------------------------
// Active orders provider — fetches orders with status=active
// Uses existing rider-service: GET /api/v1/orders/available?status=active
// ---------------------------------------------------------------------------

final activeOrdersProvider = FutureProvider.autoDispose<List<DeliveryOrder>>((ref) async {
  final api = ref.watch(riderBackendApiProvider);
  try {
    final response = await api.orders.availableOrders(queryParameters: {'status': 'active'});
    final data = response.data;
    final items = data['items'] as List<dynamic>? ??
        data['data'] as List<dynamic>? ??
        (data['orders'] as List<dynamic>?) ??
        [];

    final now = DateTime.now();
    return items.map((item) {
      final raw = item is Map<String, dynamic> ? item : <String, dynamic>{};
      final order = raw['order'] is Map<String, dynamic>
          ? raw['order'] as Map<String, dynamic>
          : raw;

      return DeliveryOrder(
        id: (order['id'] ?? raw['id'] ?? 'temp-${now.microsecondsSinceEpoch}').toString(),
        assignmentId: (order['assignment_id'] ?? raw['assignment_id'])?.toString(),
        restaurantName: order['restaurant_name'] as String? ?? 'Restaurant',
        customerName: order['customer_name'] as String? ?? 'Customer',
        pickupAddress: order['pickup_address'] as String? ??
            order['restaurant_address'] as String? ??
            'Pickup address',
        dropAddress: order['delivery_address'] as String? ??
            order['drop_address'] as String? ??
            'Drop address',
        restaurantPhone: order['restaurant_phone'] as String? ?? '',
        customerPhone: order['customer_phone'] as String? ?? '',
        restaurantLat: (order['restaurant_lat'] as num?)?.toDouble() ?? 0.0,
        restaurantLng: (order['restaurant_lng'] as num?)?.toDouble() ?? 0.0,
        deliveryLat: (order['delivery_latitude'] as num?)?.toDouble() ?? 0.0,
        deliveryLng: (order['delivery_longitude'] as num?)?.toDouble() ?? 0.0,
        distanceKm: (order['distance_km'] as num?)?.toDouble() ?? 0.0,
        etaMinutes: (order['eta_minutes'] as num?)?.toInt() ?? 15,
        payout: (order['base_payout'] as num?)?.toDouble() ??
            (order['total_amount'] as num?)?.toDouble() ??
            0.0,
        tip: (order['tip_amount'] as num?)?.toDouble() ?? 0.0,
        itemsCount: (order['items_count'] as num?)?.toInt() ??
            (order['item_count'] as num?)?.toInt() ??
            1,
        itemHighlights: const [],
        priority: OrderPriority.standard,
        type: OrderType.solo,
        status: deliveryStageFromJson(order['status'] as String? ?? 'assigned'),
        paymentMethod: order['payment_method'] as String? ??
            order['payment_mode'] as String? ??
            'Cash',
        orderCode: order['order_number'] as String? ??
            order['order_code'] as String? ??
            (order['id'] ?? '').toString(),
        customerOtp: '',
        pickupOtpRequired: false,
        deliveryOtpRequired: false,
        notes: order['delivery_notes'] as String? ?? order['notes'] as String? ?? '',
        createdAt: DateTime.tryParse(order['created_at']?.toString() ?? '') ?? now,
        countdownSeconds: 0,
        isMultiOrder: false,
      );
    }).toList();
  } on ApiException catch (e) {
    if (e.statusCode == 404) return [];
    rethrow;
  }
});

// ---------------------------------------------------------------------------
// Delivered orders provider — fetches order history filtered to delivered
// Uses existing rider-service: GET /api/v1/orders/history?status=delivered
// ---------------------------------------------------------------------------

final deliveredOrdersProvider = FutureProvider.autoDispose<List<DeliveryRecord>>((ref) async {
  final api = ref.watch(riderBackendApiProvider);
  try {
    final response = await api.orders.orderHistory(queryParameters: {'status': 'delivered'});
    final data = response.data;
    final items = data['items'] as List<dynamic>? ??
        data['data'] as List<dynamic>? ??
        (data['orders'] as List<dynamic>?) ??
        [];

    return items.map((item) {
      final raw = item is Map<String, dynamic> ? item : <String, dynamic>{};
      final order = raw['order'] is Map<String, dynamic>
          ? raw['order'] as Map<String, dynamic>
          : raw;

      return DeliveryRecord(
        id: (order['id'] ?? raw['id'] ?? 'temp').toString(),
        restaurantName: order['restaurant_name'] as String? ?? 'Restaurant',
        customerName: order['customer_name'] as String? ?? 'Customer',
        pickupAddress: order['pickup_address'] as String? ?? 'Pickup address',
        dropAddress: order['delivery_address'] as String? ??
            order['drop_address'] as String? ??
            'Drop address',
        distanceKm: (order['distance_km'] as num?)?.toDouble() ?? 0.0,
        earnings: (order['net_earning'] as num?)?.toDouble() ??
            (order['base_payout'] as num?)?.toDouble() ??
            (order['total_amount'] as num?)?.toDouble() ??
            0.0,
        paymentMethod: order['payment_method'] as String? ?? 'Cash',
        itemsCount: (order['items_count'] as num?)?.toInt() ?? 1,
        outcome: DeliveryOutcome.completed,
        completedAt: DateTime.tryParse(
              order['actual_delivery_time']?.toString() ??
                  order['delivered_at']?.toString() ??
                  order['completed_at']?.toString() ??
                  '',
            ) ??
            DateTime.now(),
        notes: '',
        timeline: const [],
        durationMinutes: (order['duration_minutes'] as num?)?.toInt() ?? 30,
      );
    }).toList();
  } on ApiException catch (e) {
    if (e.statusCode == 404) return [];
    rethrow;
  }
});

// ---------------------------------------------------------------------------
// Linked restaurants provider — rider profile enrichment
// Uses existing rider-service: GET /api/v1/rider/profile
// TODO: Backend needs GET /api/v1/rider/me/restaurants endpoint
// ---------------------------------------------------------------------------

final linkedRestaurantsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(riderBackendApiProvider);
  try {
    final response = await api.rider.getProfile();
    final data = response.data;
    // Try to extract linked restaurants from profile response
    final restaurants = data['restaurants'] as List<dynamic>? ??
        data['linked_restaurants'] as List<dynamic>? ??
        [];
    return restaurants
        .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
        .where((e) => e.isNotEmpty)
        .toList();
  } on ApiException catch (e) {
    if (e.statusCode == 404) return [];
    rethrow;
  }
});
