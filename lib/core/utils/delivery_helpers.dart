import '../../domain/entities/app_models.dart';

/// Shared helpers for delivery stage labels and descriptions.
/// Eliminates duplication between active_delivery_screen and navigation_widgets.
class DeliveryHelpers {
  const DeliveryHelpers._();

  static String stageLabel(DeliveryStage stage) => switch (stage) {
    DeliveryStage.assigned => 'Assigned',
    DeliveryStage.accepted => 'Accepted',
    DeliveryStage.reachedRestaurant => 'Reached restaurant',
    DeliveryStage.pickedUp => 'Picked up',
    DeliveryStage.onTheWay => 'On the way',
    DeliveryStage.reachedCustomer => 'Arrived at customer',
    DeliveryStage.delivered => 'Delivered',
  };

  static String stageDescription(DeliveryStage stage) => switch (stage) {
    DeliveryStage.assigned => 'Dispatch has reserved this order for you.',
    DeliveryStage.accepted => 'Customer and restaurant have been notified.',
    DeliveryStage.reachedRestaurant => 'Confirm arrival and prep handoff.',
    DeliveryStage.pickedUp => 'Items are sealed and ready for drop.',
    DeliveryStage.onTheWay => 'Route is optimized for the next milestone.',
    DeliveryStage.reachedCustomer =>
      'Final handoff checkpoint before completion.',
    DeliveryStage.delivered => 'OTP matched and earnings are secured.',
  };

  static String priorityLabel(OrderPriority priority) => switch (priority) {
    OrderPriority.vip => 'VIP',
    OrderPriority.rush => 'Rush',
    OrderPriority.standard => 'Standard',
  };

  static String typeLabel(OrderType type) => switch (type) {
    OrderType.solo => 'Solo',
    OrderType.stacked => 'Stacked',
    OrderType.scheduled => 'Scheduled',
  };

  static String statusLabel(DeliveryStage stage) => switch (stage) {
    DeliveryStage.assigned => 'Assigned',
    DeliveryStage.accepted => 'Accepted',
    DeliveryStage.reachedRestaurant => 'At pickup',
    DeliveryStage.pickedUp => 'Picked up',
    DeliveryStage.onTheWay => 'On route',
    DeliveryStage.reachedCustomer => 'At customer',
    DeliveryStage.delivered => 'Delivered',
  };

  /// Standard reject reasons a rider can choose from.
  static const List<String> rejectReasons = [
    'Too far from restaurant',
    'Order too heavy',
    'Vehicle issue',
    'Personal emergency',
    'Area unsafe',
    'Already on another delivery',
    'Other',
  ];
}
