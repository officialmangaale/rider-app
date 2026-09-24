import '../../../core/network/api_exception.dart';
import '../models/delivery_models.dart';

/// Whether the next step is a pickup the kitchen has not released yet.
///
/// restaurant-service lets a rider move an order to "out for delivery" only
/// once the restaurant has marked it ready, so pressing "Picked up" earlier
/// can only fail. The screen shows a waiting state instead and keeps
/// refreshing. Unknown (older backend) never blocks.
bool isWaitingForKitchen(ActiveDeliveryOrderModel order) {
  return order.pickupReady == false &&
      nextDeliveryActionFor(order)?.nextStatus == 'picked_up';
}

/// A rider-facing message for a failed status update. The backend's reason
/// goes to debug logs only.
String deliveryUpdateErrorMessage(Object error) {
  if (error is ApiException) {
    switch (error.errorCode) {
      case 'ORDER_NOT_READY':
        return 'The restaurant has not marked this order ready yet. '
            'You can pick it up as soon as they do.';
      case 'CASH_COLLECTION_REQUIRED':
        return 'Confirm the cash you collected to complete this delivery.';
      case 'RESTAURANT_SYNC_FAILED':
        return 'Could not reach the restaurant system. Please try again.';
      case 'NOT_ASSIGNED_RIDER':
        return 'This order is no longer assigned to you.';
      case 'ORDER_CLOSED':
        return 'The restaurant closed this order. You are free for new orders.';
      case 'INVALID_TRANSITION':
        return 'This step was already updated. Showing the current step.';
      case 'NETWORK_ERROR':
      case 'REQUEST_TIMEOUT':
        return 'No connection. Check your internet and try again.';
    }
  }
  return 'Could not update order. Refreshing the valid next step.';
}

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
