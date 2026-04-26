import '../../../domain/entities/app_models.dart';

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
    return RiderAvailabilityModel(
      isOnline: json['is_online'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? false,
      currentOrderId: json['current_order_id'] as int?,
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
      requestId: json['request_id'] as int,
      orderId: json['order_id'] as int,
      restaurantId: json['restaurant_id'] as int,
      pickupAddress: json['pickup_address'] as String,
      dropAddress: json['drop_address'] as String,
      pickupLatitude: (json['pickup_latitude'] as num).toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num).toDouble(),
      dropLatitude: (json['drop_latitude'] as num).toDouble(),
      dropLongitude: (json['drop_longitude'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      expiresAt: DateTime.parse(json['expires_at'] as String),
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
      orderId: json['order_id'] as int,
      deliveryStatus: json['delivery_status'] as String,
      pickupAddress: json['pickup_address'] as String,
      dropAddress: json['drop_address'] as String,
      pickupLatitude: (json['pickup_latitude'] as num).toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num).toDouble(),
      dropLatitude: (json['drop_latitude'] as num).toDouble(),
      dropLongitude: (json['drop_longitude'] as num).toDouble(),
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      restaurantName: json['restaurant_name'] as String?,
      restaurantPhone: json['restaurant_phone'] as String?,
      paymentMode: json['payment_mode'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
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
