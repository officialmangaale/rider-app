import '../models/delivery_models.dart';

class DeliveryAdvanceAction {
  const DeliveryAdvanceAction({required this.label, required this.nextStatus});

  final String label;
  final String nextStatus;
}

DeliveryAdvanceAction? nextDeliveryActionFor(ActiveDeliveryOrderModel order) {
  final status = order.deliveryStatus.trim().toLowerCase();
  if (order.isRestaurantOwned) {
    switch (status) {
      case 'ready':
      case 'rider_assigned':
      case 'rider_arrived_restaurant':
        return const DeliveryAdvanceAction(
          label: 'Confirm pickup',
          nextStatus: 'picked_up',
        );
      case 'picked_up':
        return const DeliveryAdvanceAction(
          label: 'On the way',
          nextStatus: 'on_the_way',
        );
      case 'on_the_way':
      case 'out_for_delivery':
        return const DeliveryAdvanceAction(
          label: 'Mark delivered',
          nextStatus: 'delivered',
        );
      default:
        return null;
    }
  }

  switch (status) {
    case 'rider_assigned':
      return const DeliveryAdvanceAction(
        label: 'I reached restaurant',
        nextStatus: 'rider_arrived_restaurant',
      );
    case 'rider_arrived_restaurant':
      return const DeliveryAdvanceAction(
        label: 'Picked up order',
        nextStatus: 'picked_up',
      );
    case 'picked_up':
      return const DeliveryAdvanceAction(
        label: 'Start delivery',
        nextStatus: 'on_the_way',
      );
    case 'on_the_way':
      return const DeliveryAdvanceAction(
        label: 'Mark delivered',
        nextStatus: 'delivered',
      );
    case 'ready':
      return const DeliveryAdvanceAction(
        label: 'Picked up order',
        nextStatus: 'picked_up',
      );
    case 'out_for_delivery':
      return const DeliveryAdvanceAction(
        label: 'Mark delivered',
        nextStatus: 'delivered',
      );
    default:
      return null;
  }
}
