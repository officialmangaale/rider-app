import 'dart:math' as math;

import 'delivery_polyline_decoder.dart';
import 'delivery_route.dart';

class DeliveryRoutePolicy {
  const DeliveryRoutePolicy({
    this.minRefreshInterval = const Duration(seconds: 30),
    this.maxRouteAge = const Duration(seconds: 90),
    this.refreshDistanceMeters = 150,
    this.offRouteDistanceMeters = 75,
    this.maxAccuracyForOffRouteMeters = 80,
  });

  final Duration minRefreshInterval;
  final Duration maxRouteAge;
  final double refreshDistanceMeters;
  final double offRouteDistanceMeters;
  final double maxAccuracyForOffRouteMeters;

  bool canRefresh(DateTime now, DateTime? lastRequestAt) =>
      lastRequestAt == null ||
      now.difference(lastRequestAt) >= minRefreshInterval;

  bool isStale(DeliveryRouteModel route, DateTime now) =>
      now.difference(route.generatedAt) >= maxRouteAge ||
      now.isAfter(route.expiresAt);

  bool movedEnough(DeliveryRoutePoint? previous, DeliveryRoutePoint current) =>
      previous == null ||
      distanceMeters(previous, current) >= refreshDistanceMeters;

  bool isOffRoute({
    required DeliveryRouteModel route,
    required DeliveryRoutePoint rider,
    required double accuracyMeters,
  }) {
    if (route.points.length < 2 ||
        accuracyMeters > maxAccuracyForOffRouteMeters) {
      return false;
    }
    return distanceToPolylineMeters(rider, route.points) >=
        offRouteDistanceMeters;
  }
}

double distanceMeters(DeliveryRoutePoint a, DeliveryRoutePoint b) {
  const earth = 6371000.0;
  final dLat = _radians(b.latitude - a.latitude);
  final dLng = _radians(b.longitude - a.longitude);
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final hav =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earth * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
}

double distanceToPolylineMeters(
  DeliveryRoutePoint point,
  List<DeliveryRoutePoint> route,
) {
  if (route.isEmpty) return double.infinity;
  if (route.length == 1) return distanceMeters(point, route.first);
  var best = double.infinity;
  for (var i = 0; i < route.length - 1; i++) {
    best = math.min(
      best,
      _distanceToSegmentMeters(point, route[i], route[i + 1]),
    );
  }
  return best;
}

double _distanceToSegmentMeters(
  DeliveryRoutePoint point,
  DeliveryRoutePoint start,
  DeliveryRoutePoint end,
) {
  final latScale = 111320.0;
  final lngScale = latScale * math.cos(_radians(point.latitude));
  final px = point.longitude * lngScale;
  final py = point.latitude * latScale;
  final ax = start.longitude * lngScale;
  final ay = start.latitude * latScale;
  final bx = end.longitude * lngScale;
  final by = end.latitude * latScale;
  final dx = bx - ax;
  final dy = by - ay;
  if (dx == 0 && dy == 0) return distanceMeters(point, start);
  final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
  final clamped = t.clamp(0.0, 1.0);
  final cx = ax + clamped * dx;
  final cy = ay + clamped * dy;
  final x = px - cx;
  final y = py - cy;
  return math.sqrt(x * x + y * y);
}

double _radians(double value) => value * math.pi / 180;
