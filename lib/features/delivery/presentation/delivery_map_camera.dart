import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/delivery_map_data.dart';

class DeliveryCameraBounds {
  const DeliveryCameraBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  LatLng get center => LatLng((south + north) / 2, (west + east) / 2);

  LatLngBounds toLatLngBounds() => LatLngBounds(
    southwest: LatLng(
      south.clamp(-90, 90).toDouble(),
      west.clamp(-180, 180).toDouble(),
    ),
    northeast: LatLng(
      north.clamp(-90, 90).toDouble(),
      east.clamp(-180, 180).toDouble(),
    ),
  );
}

DeliveryCameraBounds? deliveryCameraBoundsFor(List<DeliveryMapMarker> markers) {
  final valid = markers
      .where((m) => validMapCoordinate(m.latitude, m.longitude))
      .toList(growable: false);
  if (valid.isEmpty) return null;

  var south = valid.first.latitude;
  var north = south;
  var west = valid.first.longitude;
  var east = west;
  for (final marker in valid.skip(1)) {
    if (marker.latitude < south) south = marker.latitude;
    if (marker.latitude > north) north = marker.latitude;
    if (marker.longitude < west) west = marker.longitude;
    if (marker.longitude > east) east = marker.longitude;
  }

  final latPad = ((0.004 - (north - south)) / 2).clamp(0.002, 0.05);
  final lngPad = ((0.004 - (east - west)) / 2).clamp(0.002, 0.05);
  return DeliveryCameraBounds(
    south: (south - latPad).clamp(-90, 90).toDouble(),
    west: (west - lngPad).clamp(-180, 180).toDouble(),
    north: (north + latPad).clamp(-90, 90).toDouble(),
    east: (east + lngPad).clamp(-180, 180).toDouble(),
  );
}
