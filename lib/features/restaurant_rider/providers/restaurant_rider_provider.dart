import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/core_providers.dart';

// ---------------------------------------------------------------------------
// Active orders provider
// GET /api/v1/orders/active
// ---------------------------------------------------------------------------

final activeOrdersProvider = FutureProvider.autoDispose<List<DeliveryOrder>>((
  ref,
) async {
  final api = ref.watch(riderBackendApiProvider);
  const endpoint = '/api/v1/orders/active';

  try {
    final response = await api.orders.activeOrder();
    final order = _deliveryOrderFromPayload(response.data);
    final orders = order == null ? const <DeliveryOrder>[] : [order];
    _debugLog(
      '$endpoint status=${response.statusCode ?? 'unknown'} count=${orders.length} empty=${orders.isEmpty}',
    );
    return orders;
  } on ApiException catch (error) {
    _debugLog(
      '$endpoint status=${error.statusCode ?? 'unknown'} error=${error.errorCode ?? error.message}',
    );
    if (error.statusCode == 404) {
      return const <DeliveryOrder>[];
    }
    rethrow;
  }
});

// ---------------------------------------------------------------------------
// Delivered orders provider
// GET /api/v1/orders/history?status=delivered
// ---------------------------------------------------------------------------

final deliveredOrdersProvider =
    FutureProvider.autoDispose<List<DeliveryRecord>>((ref) async {
      final api = ref.watch(riderBackendApiProvider);
      const endpoint = '/api/v1/orders/history?status=delivered';

      try {
        final response = await api.orders.orderHistory(
          queryParameters: const {'status': 'delivered'},
        );
        final items = _extractList(response.data);
        final orders = _mapList(items, _deliveryRecordFromPayload);
        _debugLog(
          '$endpoint status=${response.statusCode ?? 'unknown'} count=${orders.length} empty=${orders.isEmpty}',
        );
        return orders;
      } on ApiException catch (error) {
        _debugLog(
          '$endpoint status=${error.statusCode ?? 'unknown'} error=${error.errorCode ?? error.message}',
        );
        if (error.statusCode == 404) {
          return const <DeliveryRecord>[];
        }
        rethrow;
      }
    });

// ---------------------------------------------------------------------------
// Linked restaurants provider
// GET /api/v1/rider/profile
// TODO: Backend needs GET /api/v1/rider/me/restaurants endpoint.
// ---------------------------------------------------------------------------

final linkedRestaurantsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = ref.watch(riderBackendApiProvider);
      const endpoint = '/api/v1/rider/profile restaurants';

      try {
        final response = await api.rider.getProfile();
        final data = response.data;
        final restaurants = _extractRestaurants(data);
        _debugLog(
          '$endpoint status=${response.statusCode ?? 'unknown'} count=${restaurants.length} empty=${restaurants.isEmpty}',
        );
        return restaurants;
      } on ApiException catch (error) {
        _debugLog(
          '$endpoint status=${error.statusCode ?? 'unknown'} error=${error.errorCode ?? error.message}',
        );
        if (error.statusCode == 404) {
          return const <Map<String, dynamic>>[];
        }
        rethrow;
      }
    });

List<T> _mapList<T>(List<dynamic> items, T? Function(Object? item) mapper) {
  final mapped = <T>[];
  for (final item in items) {
    final value = mapper(item);
    if (value != null) {
      mapped.add(value);
    }
  }
  return mapped;
}

DeliveryOrder? _deliveryOrderFromPayload(Object? item) {
  final raw = _asMap(item);
  if (raw.isEmpty) {
    return null;
  }

  final order = _asMap(raw['order']);
  final restaurant = _asMap(
    _firstPresent([order['restaurant'], raw['restaurant']]),
  );
  final customer = _asMap(_firstPresent([order['customer'], raw['customer']]));
  final now = DateTime.now();
  final id = _asString(
    _firstPresent([
      order['id'],
      order['order_id'],
      raw['order_id'],
      raw['id'],
      raw['assignment_id'],
    ]),
    fallback: 'temp-${now.microsecondsSinceEpoch}',
  );

  return DeliveryOrder(
    id: id,
    assignmentId: _asNullableString(
      _firstPresent([raw['assignment_id'], order['assignment_id']]),
    ),
    restaurantName: _asString(
      _firstPresent([
        order['restaurant_name'],
        restaurant['name'],
        raw['restaurant_name'],
      ]),
      fallback: 'Restaurant',
    ),
    customerName: _asString(
      _firstPresent([
        order['customer_name'],
        customer['name'],
        raw['customer_name'],
      ]),
      fallback: 'Customer',
    ),
    pickupAddress: _asString(
      _firstPresent([
        order['pickup_address'],
        order['restaurant_address'],
        restaurant['address'],
        raw['pickup_address'],
      ]),
      fallback: 'Pickup address not available',
    ),
    dropAddress: _asString(
      _firstPresent([
        order['delivery_address'],
        order['drop_address'],
        customer['address'],
        raw['delivery_address'],
        raw['drop_address'],
      ]),
      fallback: 'Drop address not available',
    ),
    restaurantPhone: _asString(
      _firstPresent([
        order['restaurant_phone'],
        restaurant['phone'],
        raw['restaurant_phone'],
      ]),
    ),
    customerPhone: _asString(
      _firstPresent([
        order['customer_phone'],
        customer['phone'],
        raw['customer_phone'],
      ]),
    ),
    restaurantLat: _asDouble(
      _firstPresent([
        order['restaurant_lat'],
        order['pickup_latitude'],
        restaurant['latitude'],
        raw['pickup_latitude'],
      ]),
    ),
    restaurantLng: _asDouble(
      _firstPresent([
        order['restaurant_lng'],
        order['pickup_longitude'],
        restaurant['longitude'],
        raw['pickup_longitude'],
      ]),
    ),
    deliveryLat: _asDouble(
      _firstPresent([
        order['delivery_latitude'],
        order['drop_latitude'],
        customer['latitude'],
        raw['drop_latitude'],
      ]),
    ),
    deliveryLng: _asDouble(
      _firstPresent([
        order['delivery_longitude'],
        order['drop_longitude'],
        customer['longitude'],
        raw['drop_longitude'],
      ]),
    ),
    distanceKm: _asDouble(
      _firstPresent([order['distance_km'], raw['distance_km']]),
    ),
    etaMinutes: _asInt(
      _firstPresent([order['eta_minutes'], raw['eta_minutes']]),
      fallback: 15,
    ),
    payout: _payoutFromOrder(order, raw),
    tip: _asDouble(_firstPresent([order['tip_amount'], order['tip']])),
    itemsCount: _asInt(
      _firstPresent([
        order['items_count'],
        order['item_count'],
        raw['items_count'],
      ]),
      fallback: _extractList(order, keys: const ['items']).length,
    ).clamp(0, 999).toInt(),
    itemHighlights: _extractList(order, keys: const ['items'])
        .map((line) => _asString(_firstPresent([_asMap(line)['name'], line])))
        .where((line) => line.isNotEmpty)
        .toList(growable: false),
    priority: orderPriorityFromJson(
      _asString(_firstPresent([order['priority'], raw['priority']])),
    ),
    type: orderTypeFromJson(
      _asString(_firstPresent([order['type'], raw['type']])),
    ),
    status: deliveryStageFromJson(
      _asString(
        _firstPresent([
          order['delivery_status'],
          order['status'],
          raw['status'],
        ]),
        fallback: 'assigned',
      ),
    ),
    paymentMethod: _asString(
      _firstPresent([
        order['payment_method'],
        order['payment_mode'],
        raw['payment_method'],
      ]),
      fallback: 'Cash',
    ),
    orderCode: _asString(
      _firstPresent([
        order['order_number'],
        order['order_code'],
        raw['order_code'],
        id,
      ]),
      fallback: id,
    ),
    customerOtp: _asString(
      _firstPresent([order['customer_otp'], order['customerOtp']]),
    ),
    pickupOtpRequired: _asBool(order['pickup_otp_required']),
    deliveryOtpRequired: _asBool(order['delivery_otp_required']),
    notes: _asString(
      _firstPresent([order['delivery_notes'], order['notes'], raw['notes']]),
    ),
    createdAt: _asDateTime(
      _firstPresent([order['created_at'], raw['created_at']]),
      fallback: now,
    ),
    countdownSeconds: _asInt(raw['countdown_seconds']),
    isMultiOrder: _asBool(
      _firstPresent([order['is_multi_order'], raw['stacked']]),
    ),
  );
}

DeliveryRecord? _deliveryRecordFromPayload(Object? item) {
  final raw = _asMap(item);
  if (raw.isEmpty) {
    return null;
  }

  final order = _asMap(raw['order']);
  final restaurant = _asMap(
    _firstPresent([order['restaurant'], raw['restaurant']]),
  );
  final customer = _asMap(_firstPresent([order['customer'], raw['customer']]));
  final id = _asString(
    _firstPresent([order['id'], order['order_id'], raw['order_id'], raw['id']]),
    fallback: 'delivery',
  );

  return DeliveryRecord(
    id: id,
    restaurantName: _asString(
      _firstPresent([
        order['restaurant_name'],
        restaurant['name'],
        raw['restaurant_name'],
      ]),
      fallback: 'Restaurant',
    ),
    customerName: _asString(
      _firstPresent([
        order['customer_name'],
        customer['name'],
        raw['customer_name'],
      ]),
      fallback: 'Customer',
    ),
    pickupAddress: _asString(
      _firstPresent([
        order['pickup_address'],
        order['restaurant_address'],
        restaurant['address'],
      ]),
      fallback: 'Pickup address not available',
    ),
    dropAddress: _asString(
      _firstPresent([
        order['delivery_address'],
        order['drop_address'],
        customer['address'],
      ]),
      fallback: 'Drop address not available',
    ),
    distanceKm: _asDouble(_firstPresent([order['distance_km'], raw['distance_km']])),
    earnings: _asDouble(
      _firstPresent([
        order['net_earning'],
        order['base_payout'],
        order['payout'],
        order['total_amount'],
        raw['earnings'],
      ]),
    ),
    paymentMethod: _asString(
      _firstPresent([order['payment_method'], order['payment_mode']]),
      fallback: 'Cash',
    ),
    itemsCount: _asInt(
      _firstPresent([order['items_count'], order['item_count']]),
      fallback: _extractList(order, keys: const ['items']).length,
    ).clamp(1, 999).toInt(),
    outcome: DeliveryOutcome.completed,
    completedAt: _asDateTime(
      _firstPresent([
        order['actual_delivery_time'],
        order['delivered_at'],
        order['completed_at'],
        raw['delivered_at'],
      ]),
      fallback: DateTime.now(),
    ),
    notes: _asString(_firstPresent([order['notes'], raw['notes']])),
    timeline: const <String>[],
    durationMinutes: _asInt(
      _firstPresent([order['duration_minutes'], raw['duration_minutes']]),
      fallback: 30,
    ),
  );
}

List<Map<String, dynamic>> _extractRestaurants(Map<String, dynamic> data) {
  final lists = [
    _extractList(
      data,
      keys: const ['restaurants', 'linked_restaurants', 'assigned_restaurants'],
    ),
    _extractList(_asMap(data['rider'])),
    _extractList(_asMap(data['data'])),
  ];

  final restaurants = <Map<String, dynamic>>[];
  for (final list in lists) {
    for (final item in list) {
      final map = _asMap(item);
      if (map.isNotEmpty) {
        restaurants.add(map);
      }
    }
  }

  final singleRestaurant = _asMap(data['restaurant']);
  if (singleRestaurant.isNotEmpty) {
    restaurants.add(singleRestaurant);
  }

  final restaurantId = _asString(data['restaurant_id']);
  if (restaurants.isEmpty && restaurantId.isNotEmpty) {
    restaurants.add({'id': restaurantId, 'name': 'Restaurant $restaurantId'});
  }

  return restaurants;
}

List<dynamic> _extractList(
  Map<String, dynamic> data, {
  List<String> keys = const [
    'items',
    'orders',
    'data',
    'results',
    'available_orders',
    'active_orders',
    'delivered_orders',
    'assignments',
    'restaurants',
    'linked_restaurants',
  ],
}) {
  for (final key in keys) {
    final value = data[key];
    if (value is List) {
      return value;
    }
    if (value is Map) {
      final nested = _extractList(_asMap(value), keys: keys);
      if (nested.isNotEmpty) {
        return nested;
      }
    }
  }
  return const <dynamic>[];
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

Object? _firstPresent(List<Object?> values) {
  for (final value in values) {
    if (value == null) {
      continue;
    }
    if (value is String && value.trim().isEmpty) {
      continue;
    }
    return value;
  }
  return null;
}

String _asString(Object? value, {String fallback = ''}) {
  final present = _firstPresent([value]);
  return present == null ? fallback : '$present'.trim();
}

String? _asNullableString(Object? value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

double _payoutFromOrder(
  Map<String, dynamic> order,
  Map<String, dynamic> raw,
) {
  final explicitPayout = _firstPresent([
    order['net_earning'],
    raw['net_earning'],
    order['payout'],
    raw['payout'],
    order['total_payout'],
    raw['total_payout'],
  ]);
  if (explicitPayout != null) {
    return _asDouble(explicitPayout);
  }

  return _asDouble(_firstPresent([order['base_payout'], raw['base_payout']])) +
      _asDouble(
        _firstPresent([order['distance_payout'], raw['distance_payout']]),
      ) +
      _asDouble(
        _firstPresent([order['waiting_charges'], raw['waiting_charges']]),
      ) +
      _asDouble(_firstPresent([order['surge_bonus'], raw['surge_bonus']]));
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

DateTime _asDateTime(Object? value, {required DateTime fallback}) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? fallback;
  }
  return fallback;
}

void _debugLog(String message) {
  assert(() {
    debugPrint('[Rider] $message');
    return true;
  }());
}
