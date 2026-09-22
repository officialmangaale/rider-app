import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/domain/entities/app_models.dart';
import 'package:rydex_rider/features/delivery/models/delivery_models.dart';

/// One rider app, two kinds of delivery. The workflow is identical; the order
/// type only changes what the rider reads on screen — and it must default to
/// food so a build talking to an older backend behaves exactly as before.
void main() {
  Map<String, dynamic> offer({String? orderType}) => {
    'request_id': 9,
    'order_id': 42,
    'restaurant_id': 77,
    'restaurant_name': 'Anita Daily Needs',
    'pickup_address': '12 Market Road',
    'drop_address': '44 Lake View Road',
    'pickup_latitude': 12.9,
    'pickup_longitude': 77.5,
    'drop_latitude': 12.91,
    'drop_longitude': 77.51,
    'distance_km': 1.2,
    'amount': 310.0,
    'payment_mode': 'cod',
    'expires_at': '2026-09-18T10:00:30Z',
    if (orderType != null) 'order_type': orderType,
    'items_summary': 'Toor Dal x2',
  };

  Map<String, dynamic> active({String? orderType}) => {
    'order_id': 42,
    'delivery_status': 'rider_assigned',
    'pickup_address': '12 Market Road',
    'drop_address': '44 Lake View Road',
    'pickup_latitude': 12.9,
    'pickup_longitude': 77.5,
    'drop_latitude': 12.91,
    'drop_longitude': 77.51,
    'restaurant_name': 'Anita Daily Needs',
    'payment_mode': 'cod',
    if (orderType != null) 'order_type': orderType,
  };

  test('a grocery offer is recognisable as one', () {
    final request = RiderOrderRequestModel.fromJson(
      offer(orderType: 'grocery'),
    );
    expect(request.isGrocery, isTrue);
    expect(request.orderType, deliveryOrderTypeGrocery);
    expect(request.pickupName, 'Anita Daily Needs');
    expect(request.itemsSummary, 'Toor Dal x2');
    // The money and the route are read exactly as for food.
    expect(request.amount, 310.0);
    expect(request.distanceKm, 1.2);
  });

  test('an offer without an order type is food, as it always was', () {
    final request = RiderOrderRequestModel.fromJson(offer());
    expect(request.isGrocery, isFalse);
    expect(request.orderType, deliveryOrderTypeFood);
    expect(request.pickupName, 'Anita Daily Needs');

    final food = RiderOrderRequestModel.fromJson(offer(orderType: 'food'));
    expect(food.isGrocery, isFalse);
  });

  test('an unknown order type is treated as food rather than breaking', () {
    expect(normalizeDeliveryOrderType(null), deliveryOrderTypeFood);
    expect(normalizeDeliveryOrderType(''), deliveryOrderTypeFood);
    expect(normalizeDeliveryOrderType('  GROCERY '), deliveryOrderTypeGrocery);
    expect(normalizeDeliveryOrderType('parcel'), deliveryOrderTypeFood);
    expect(
      RiderOrderRequestModel.fromJson(offer(orderType: 'parcel')).isGrocery,
      isFalse,
    );
  });

  test('an active grocery delivery keeps its type through the workflow', () {
    final order = ActiveDeliveryOrderModel.fromJson(
      active(orderType: 'grocery'),
    );
    expect(order.isGrocery, isTrue);
    expect(order.pickupName, 'Anita Daily Needs');
    // Cash on delivery still drives the same confirmation step.
    expect(order.requiresCashCollection, isTrue);
    // And the stage machine is untouched.
    expect(order.stage, DeliveryStage.assigned);

    final food = ActiveDeliveryOrderModel.fromJson(active());
    expect(food.isGrocery, isFalse);
    expect(food.stage, DeliveryStage.assigned);
  });
}
