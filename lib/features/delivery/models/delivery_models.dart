import '../../../domain/entities/app_models.dart';

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

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final text = '$value'.trim();
  return text.isEmpty ? fallback : text;
}

DateTime _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  return DateTime.now().add(const Duration(seconds: 30));
}

/// What kind of order a delivery is for. The workflow is identical; only the
/// wording and the badge differ, so riders do not learn two apps.
const String deliveryOrderTypeFood = 'food';
const String deliveryOrderTypeGrocery = 'grocery';

/// normalizeDeliveryOrderType defaults anything unknown or absent to food,
/// which is what every backend that predates grocery delivery means.
String normalizeDeliveryOrderType(Object? value) {
  final text = _asString(value).trim().toLowerCase();
  return text == deliveryOrderTypeGrocery
      ? deliveryOrderTypeGrocery
      : deliveryOrderTypeFood;
}

class RiderAvailabilityModel {
  const RiderAvailabilityModel({
    required this.isOnline,
    required this.isAvailable,
    this.currentOrderId,
  });

  final bool isOnline;
  final bool isAvailable;
  final int? currentOrderId;

  factory RiderAvailabilityModel.fromJson(Map<String, dynamic> json) {
    final isAvailable = json['is_available'] as bool? ?? false;
    final onTrip = json['on_trip'] as bool? ?? false;
    return RiderAvailabilityModel(
      isOnline: json['is_online'] as bool? ?? isAvailable || onTrip,
      isAvailable: isAvailable,
      currentOrderId: json['current_order_id'] == null
          ? null
          : _asInt(json['current_order_id']),
    );
  }
}

class RiderOrderRequestModel {
  const RiderOrderRequestModel({
    required this.requestId,
    required this.orderId,
    required this.restaurantId,
    this.restaurantName,
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropLatitude,
    required this.dropLongitude,
    required this.distanceKm,
    required this.amount,
    required this.expiresAt,
    this.orderType = deliveryOrderTypeFood,
    this.itemsSummary,
  });

  final int requestId;
  final int orderId;
  final int restaurantId;
  final String? restaurantName;
  final String pickupAddress;
  final String dropAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final double dropLatitude;
  final double dropLongitude;
  final double distanceKm;
  final double amount;
  final DateTime expiresAt;

  /// "food" or "grocery". Absent means food: a build that predates grocery
  /// delivery is only ever offered food orders.
  final String orderType;

  /// What is in the bag, for a grocery pickup.
  final String? itemsSummary;

  bool get isGrocery => orderType == deliveryOrderTypeGrocery;

  /// The shop or restaurant to collect from. The backend sends the grocery
  /// shop in the same field, so one code path reads either.
  String? get pickupName => restaurantName;

  factory RiderOrderRequestModel.fromJson(Map<String, dynamic> json) {
    return RiderOrderRequestModel(
      requestId: _asInt(json['request_id']),
      orderId: _asInt(json['order_id']),
      restaurantId: _asInt(json['restaurant_id']),
      restaurantName: _asString(json['restaurant_name']),
      pickupAddress: _asString(
        json['pickup_address'],
        fallback: 'Pickup address not available',
      ),
      dropAddress: _asString(
        json['drop_address'],
        fallback: 'Drop address not available',
      ),
      pickupLatitude: _asDouble(json['pickup_latitude']),
      pickupLongitude: _asDouble(json['pickup_longitude']),
      dropLatitude: _asDouble(json['drop_latitude']),
      dropLongitude: _asDouble(json['drop_longitude']),
      distanceKm: _asDouble(json['distance_km']),
      amount: _asDouble(json['amount']),
      expiresAt: _asDateTime(json['expires_at']),
      orderType: normalizeDeliveryOrderType(json['order_type']),
      itemsSummary: _asString(json['items_summary']).isEmpty
          ? null
          : _asString(json['items_summary']),
    );
  }
}

class ActiveDeliveryOrderModel {
  const ActiveDeliveryOrderModel({
    required this.orderId,
    this.deliveryOrderId,
    required this.deliveryStatus,
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropLatitude,
    required this.dropLongitude,
    this.customerName,
    this.customerPhone,
    this.restaurantName,
    this.restaurantPhone,
    this.paymentMode,
    this.amount,
    this.items,
    this.itemsSummary,
    this.distanceKm = 0.0,
    this.etaMinutes = 0,
    this.assignmentType = 'platform',
    this.restaurantOwned = false,
    this.restaurantOrderStatus,
    this.pickupReady,
    this.nextDeliveryStatus,
    this.orderType = deliveryOrderTypeFood,
  });

  final int orderId;
  final int? deliveryOrderId;
  final String deliveryStatus;
  final String pickupAddress;
  final String dropAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final double dropLatitude;
  final double dropLongitude;
  final String? customerName;
  final String? customerPhone;
  final String? restaurantName;
  final String? restaurantPhone;
  final String? paymentMode;
  final double? amount;
  final List<dynamic>? items;
  final String? itemsSummary;
  final double distanceKm;
  final int etaMinutes;
  final String assignmentType;
  final bool restaurantOwned;

  /// The restaurant's order status (confirmed, preparing, ready, ...).
  final String? restaurantOrderStatus;

  /// Whether the kitchen has released the order, i.e. whether "picked up" can
  /// succeed now. Null when the backend did not say (older deployments).
  final bool? pickupReady;

  /// The single valid next step according to the backend, when it sends one.
  final String? nextDeliveryStatus;

  /// "food" or "grocery"; absent means food.
  final String orderType;

  bool get isGrocery => orderType == deliveryOrderTypeGrocery;

  /// The shop or restaurant to collect from.
  String? get pickupName => restaurantName;

  bool get isRestaurantOwned {
    return restaurantOwned || _isRestaurantOwnedAssignmentType(assignmentType);
  }

  bool get requiresCashCollection {
    final normalized = (paymentMode ?? '').trim().toLowerCase();
    return normalized == 'cash' || normalized == 'cod';
  }

  factory ActiveDeliveryOrderModel.fromJson(Map<String, dynamic> json) {
    return ActiveDeliveryOrderModel(
      orderId: _asInt(json['order_id'] ?? json['id']),
      deliveryOrderId: _asIntOrNull(json['delivery_order_id']),
      deliveryStatus: _asString(
        json['delivery_status'] ?? json['status'],
        fallback: 'rider_assigned',
      ),
      pickupAddress: _asString(
        json['pickup_address'],
        fallback: 'Pickup address not available',
      ),
      dropAddress: _asString(
        json['drop_address'] ?? json['delivery_address'],
        fallback: 'Drop address not available',
      ),
      pickupLatitude: _asDouble(json['pickup_latitude']),
      pickupLongitude: _asDouble(json['pickup_longitude']),
      dropLatitude: _asDouble(json['drop_latitude']),
      dropLongitude: _asDouble(json['drop_longitude']),
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      restaurantName: json['restaurant_name'] as String?,
      restaurantPhone: json['restaurant_phone'] as String?,
      paymentMode: _asString(json['payment_mode'] ?? json['payment_method']),
      amount: _activeOrderAmount(json),
      items: json['items'] as List<dynamic>?,
      itemsSummary: json['items_summary'] as String?,
      distanceKm: _asDouble(json['distance_km']),
      etaMinutes: _asInt(json['eta_minutes']),
      assignmentType: _asString(json['assignment_type'], fallback: 'platform'),
      restaurantOwned:
          _asBool(json['restaurant_owned']) ??
          _isRestaurantOwnedAssignmentType(_asString(json['assignment_type'])),
      restaurantOrderStatus: _asStringOrNull(json['restaurant_order_status']),
      pickupReady: _asBool(json['pickup_ready']),
      nextDeliveryStatus: _asStringOrNull(json['next_delivery_status']),
      orderType: normalizeDeliveryOrderType(json['order_type']),
    );
  }

  DeliveryStage get stage {
    switch (deliveryStatus.trim().toLowerCase()) {
      case 'rider_assigned':
        return DeliveryStage.assigned;
      case 'rider_arrived_restaurant':
        return DeliveryStage.reachedRestaurant;
      case 'picked_up':
        return DeliveryStage.pickedUp;
      case 'on_the_way':
      case 'out_for_delivery':
        return DeliveryStage.onTheWay;
      case 'delivered':
        return DeliveryStage.delivered;
      default:
        return DeliveryStage.assigned;
    }
  }
}

bool _isRestaurantOwnedAssignmentType(String value) {
  switch (value.trim().toLowerCase()) {
    case 'restaurant_owned':
    case 'restaurant_own_rider':
      return true;
    default:
      return false;
  }
}

String? _asStringOrNull(Object? value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}

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

bool? _asBool(Object? value) {
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
  return null;
}

double? _activeOrderAmount(Map<String, dynamic> json) {
  final explicit = json['amount'] ?? json['payout'] ?? json['total_payout'];
  if (explicit != null) {
    return _asDouble(explicit);
  }
  final componentTotal =
      _asDouble(json['base_payout']) +
      _asDouble(json['distance_payout']) +
      _asDouble(json['waiting_charges']) +
      _asDouble(json['surge_bonus']) +
      _asDouble(json['tip_amount']);
  return componentTotal > 0 ? componentTotal : null;
}

class DeliveryStatusHelper {
  static String getLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'rider_assigned':
        return 'Order assigned';
      case 'rider_arrived_restaurant':
        return 'Arrived at restaurant';
      case 'picked_up':
        return 'Picked up';
      case 'on_the_way':
      case 'out_for_delivery':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Delivery update';
    }
  }
}
