import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/features/delivery/models/delivery_polyline_decoder.dart';
import 'package:rydex_rider/features/delivery/models/delivery_route.dart';
import 'package:rydex_rider/features/delivery/models/delivery_route_policy.dart';

void main() {
  test('decodes Google encoded polyline coordinates', () {
    final points = decodeGooglePolyline(r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 0.00001));
    expect(points[0].longitude, closeTo(-120.2, 0.00001));
    expect(points[1].latitude, closeTo(40.7, 0.00001));
    expect(points[1].longitude, closeTo(-120.95, 0.00001));
    expect(points[2].latitude, closeTo(43.252, 0.00001));
    expect(points[2].longitude, closeTo(-126.453, 0.00001));
  });

  test(
    'route policy limits refreshes and ignores inaccurate off-route fixes',
    () {
      const policy = DeliveryRoutePolicy();
      final now = DateTime(2026, 10, 3);
      expect(policy.canRefresh(now, null), isTrue);
      expect(
        policy.canRefresh(now, now.subtract(const Duration(seconds: 10))),
        isFalse,
      );
      expect(
        policy.canRefresh(now, now.subtract(const Duration(seconds: 31))),
        isTrue,
      );

      final route = DeliveryRouteModel(
        encodedPolyline: 'encoded',
        points: const [
          DeliveryRoutePoint(28.6100, 77.2000),
          DeliveryRoutePoint(28.6200, 77.2100),
        ],
        distanceMeters: 1500,
        durationSeconds: 300,
        staticDurationSeconds: 280,
        provider: 'google',
        destinationType: 'pickup',
        generatedAt: now.subtract(const Duration(seconds: 91)),
        expiresAt: now.add(const Duration(seconds: 30)),
      );
      expect(policy.isStale(route, now), isTrue);
      expect(
        policy.isOffRoute(
          route: route,
          rider: const DeliveryRoutePoint(28.6101, 77.2001),
          accuracyMeters: 5,
        ),
        isFalse,
      );
      expect(
        policy.isOffRoute(
          route: route,
          rider: const DeliveryRoutePoint(28.6400, 77.2500),
          accuracyMeters: 120,
        ),
        isFalse,
      );
      expect(
        policy.isOffRoute(
          route: route,
          rider: const DeliveryRoutePoint(28.6400, 77.2500),
          accuracyMeters: 5,
        ),
        isTrue,
      );
    },
  );
}
