import 'package:geolocator/geolocator.dart';

import 'delivery_models.dart';

enum DeliveryMapStop { rider, pickup, drop }

enum DeliveryMapPhase { pickup, drop, complete }

/// A render-only projection of the existing order and GPS fix, not a second
/// source of delivery or location state.
class DeliveryMapMarker {
  const DeliveryMapMarker(
    this.stop,
    this.latitude,
    this.longitude,
    this.label, {
    this.heading,
    this.primary = false,
  });

  final DeliveryMapStop stop;
  final double latitude;
  final double longitude;
  final String label;
  final double? heading;
  final bool primary;

  DeliveryMapMarker copyWith({
    double? latitude,
    double? longitude,
    double? heading,
    bool? primary,
  }) {
    return DeliveryMapMarker(
      stop,
      latitude ?? this.latitude,
      longitude ?? this.longitude,
      label,
      heading: heading ?? this.heading,
      primary: primary ?? this.primary,
    );
  }
}

bool validMapCoordinate(double lat, double lng) =>
    lat.isFinite &&
    lng.isFinite &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180 &&
    !(lat == 0 && lng == 0);

DeliveryMapPhase deliveryMapPhaseFor(ActiveDeliveryOrderModel order) {
  switch (order.deliveryStatus.trim().toLowerCase()) {
    case 'picked_up':
    case 'on_the_way':
    case 'out_for_delivery':
      return DeliveryMapPhase.drop;
    case 'delivered':
      return DeliveryMapPhase.complete;
    default:
      return DeliveryMapPhase.pickup;
  }
}

bool isTerminalDeliveryMapPhase(ActiveDeliveryOrderModel order) =>
    deliveryMapPhaseFor(order) == DeliveryMapPhase.complete;

List<DeliveryMapMarker> deliveryMapMarkers(
  ActiveDeliveryOrderModel order,
  Position? rider,
) {
  if (isTerminalDeliveryMapPhase(order)) return const [];
  final phase = deliveryMapPhaseFor(order);
  final riderHeading = _safeHeading(rider?.heading);
  return [
    if (rider != null && validMapCoordinate(rider.latitude, rider.longitude))
      DeliveryMapMarker(
        DeliveryMapStop.rider,
        rider.latitude,
        rider.longitude,
        'You',
        heading: riderHeading,
        primary: true,
      ),
    if (validMapCoordinate(order.pickupLatitude, order.pickupLongitude))
      DeliveryMapMarker(
        DeliveryMapStop.pickup,
        order.pickupLatitude,
        order.pickupLongitude,
        order.pickupName ?? 'Pickup',
        primary: phase == DeliveryMapPhase.pickup,
      ),
    if (validMapCoordinate(order.dropLatitude, order.dropLongitude))
      DeliveryMapMarker(
        DeliveryMapStop.drop,
        order.dropLatitude,
        order.dropLongitude,
        'Customer',
        primary: phase == DeliveryMapPhase.drop,
      ),
  ];
}

List<DeliveryMapMarker> deliveryMapFocusMarkers(
  List<DeliveryMapMarker> markers,
  DeliveryMapPhase phase,
) {
  if (phase == DeliveryMapPhase.complete) return const [];
  final rider = markers.where((m) => m.stop == DeliveryMapStop.rider);
  final destinationStop = phase == DeliveryMapPhase.pickup
      ? DeliveryMapStop.pickup
      : DeliveryMapStop.drop;
  final destination = markers.where((m) => m.stop == destinationStop);
  final focus = [...rider, ...destination];
  return focus.isEmpty ? markers : focus;
}

String deliveryMapPhaseLabel(ActiveDeliveryOrderModel order) {
  return switch (deliveryMapPhaseFor(order)) {
    DeliveryMapPhase.pickup =>
      order.isGrocery ? 'Heading to grocery pickup' : 'Heading to restaurant',
    DeliveryMapPhase.drop => 'Heading to customer',
    DeliveryMapPhase.complete => 'Delivery completed',
  };
}

double? _safeHeading(double? value) {
  if (value == null || !value.isFinite || value < 0) return null;
  return value % 360;
}
