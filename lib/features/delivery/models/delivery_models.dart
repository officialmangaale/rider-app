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
    required this.pickupAddress,
    required this.dropAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropLatitude,
    required this.dropLongitude,
    required this.distanceKm,
    required this.amount,
    required this.expiresAt,
  });

  final int requestId;
  final int orderId;
  final int restaurantId;
  final String pickupAddress;
  final String dropAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final double dropLatitude;
  final double dropLongitude;
  final double distanceKm;
  final double amount;
  final DateTime expiresAt;

  factory RiderOrderRequestModel.fromJson(Map<String, dynamic> json) {
    return RiderOrderRequestModel(
      requestId: _asInt(json['request_id']),
      orderId: _asInt(json['order_id']),
      restaurantId: _asInt(json['restaurant_id']),
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
    );
  }
}

class ActiveDeliveryOrderModel {
  const ActiveDeliveryOrderModel({
    required this.orderId,
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
  });

  final int orderId;
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

  factory ActiveDeliveryOrderModel.fromJson(Map<String, dynamic> json) {
    return ActiveDeliveryOrderModel(
      orderId: _asInt(json['order_id']),
      deliveryStatus: _asString(
        json['delivery_status'],
        fallback: 'rider_assigned',
      ),
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
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      restaurantName: json['restaurant_name'] as String?,
      restaurantPhone: json['restaurant_phone'] as String?,
      paymentMode: json['payment_mode'] as String?,
      amount: json['amount'] == null ? null : _asDouble(json['amount']),
      items: json['items'] as List<dynamic>?,
    );
  }

  DeliveryStage get stage {
    switch (deliveryStatus) {
      case 'rider_assigned':
        return DeliveryStage.assigned;
      case 'rider_arrived_restaurant':
        return DeliveryStage.reachedRestaurant;
      case 'picked_up':
        return DeliveryStage.pickedUp;
      case 'on_the_way':
        return DeliveryStage.onTheWay;
      case 'delivered':
        return DeliveryStage.delivered;
      default:
        return DeliveryStage.assigned;
    }
  }
}

class DeliveryStatusHelper {
  static String getLabel(String status) {
    switch (status) {
      case 'rider_assigned':
        return 'Order assigned';
      case 'rider_arrived_restaurant':
        return 'Arrived at restaurant';
      case 'picked_up':
        return 'Picked up';
      case 'on_the_way':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Delivery update';
    }
  }
}
