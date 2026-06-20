import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/features/delivery/models/delivery_models.dart';
import 'package:rydex_rider/features/delivery/services/delivery_action_policy.dart';

void main() {
  test('restaurant-owned assignment skips reached-restaurant action', () {
    final action = nextDeliveryActionFor(
      _order(
        status: 'rider_assigned',
        assignmentType: 'restaurant_owned',
        restaurantOwned: true,
      ),
    );

    expect(action?.label, 'Confirm pickup');
    expect(action?.nextStatus, 'picked_up');
  });

  test('platform assignment keeps reached-restaurant action', () {
    final action = nextDeliveryActionFor(
      _order(status: 'rider_assigned', assignmentType: 'platform'),
    );

    expect(action?.label, 'I reached restaurant');
    expect(action?.nextStatus, 'rider_arrived_restaurant');
  });

  test('restaurant-owned picked-up order can only be delivered', () {
    final action = nextDeliveryActionFor(
      _order(
        status: 'picked_up',
        assignmentType: 'restaurant_owned',
        restaurantOwned: true,
      ),
    );

    expect(action?.label, 'Mark delivered');
    expect(action?.nextStatus, 'delivered');
  });
}

ActiveDeliveryOrderModel _order({
  required String status,
  required String assignmentType,
  bool restaurantOwned = false,
}) {
  return ActiveDeliveryOrderModel(
    orderId: 42,
    deliveryStatus: status,
    pickupAddress: 'Restaurant',
    dropAddress: 'Customer',
    pickupLatitude: 12.9,
    pickupLongitude: 77.5,
    dropLatitude: 12.8,
    dropLongitude: 77.6,
    assignmentType: assignmentType,
    restaurantOwned: restaurantOwned,
  );
}
