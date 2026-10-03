import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rydex_rider/features/delivery/models/delivery_map_data.dart';
import 'package:rydex_rider/features/delivery/models/delivery_models.dart';
import 'package:rydex_rider/features/delivery/models/delivery_polyline_decoder.dart';
import 'package:rydex_rider/features/delivery/models/delivery_route.dart';
import 'package:rydex_rider/features/delivery/presentation/delivery_map_camera.dart';
import 'package:rydex_rider/features/delivery/presentation/embedded_delivery_map.dart';

const order = ActiveDeliveryOrderModel(
  orderId: 42,
  deliveryStatus: 'rider_assigned',
  pickupAddress: 'Pickup',
  dropAddress: 'Drop',
  pickupLatitude: 28.61,
  pickupLongitude: 77.2,
  dropLatitude: 28.62,
  dropLongitude: 77.21,
);
Position position(double latitude, double longitude) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: DateTime(2026),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  test(
    'existing order and GPS fix map to rider, pickup and customer markers',
    () {
      final data = deliveryMapMarkers(order, position(28.615, 77.205));
      final markers = googleDeliveryMarkers(data);
      expect(markers.map((m) => m.markerId.value).toSet(), {
        'rider',
        'pickup',
        'drop',
      });
      expect(
        markers
            .singleWhere((m) => m.markerId.value == 'pickup')
            .position
            .latitude,
        order.pickupLatitude,
      );
      expect(
        markers
            .singleWhere((m) => m.markerId.value == 'drop')
            .position
            .longitude,
        order.dropLongitude,
      );
      expect(
        markers.singleWhere((m) => m.markerId.value == 'rider').rotation,
        0,
      );
    },
  );
  test('delivery phase chooses the correct focus without dropping markers', () {
    final beforePickup = deliveryMapMarkers(order, position(28.615, 77.205));
    expect(deliveryMapPhaseFor(order), DeliveryMapPhase.pickup);
    expect(
      deliveryMapFocusMarkers(
        beforePickup,
        deliveryMapPhaseFor(order),
      ).map((m) => m.stop),
      [DeliveryMapStop.rider, DeliveryMapStop.pickup],
    );

    const afterPickup = ActiveDeliveryOrderModel(
      orderId: 42,
      deliveryStatus: 'picked_up',
      pickupAddress: 'Pickup',
      dropAddress: 'Drop',
      pickupLatitude: 28.61,
      pickupLongitude: 77.2,
      dropLatitude: 28.62,
      dropLongitude: 77.21,
    );
    final afterPickupMarkers = deliveryMapMarkers(
      afterPickup,
      position(28.615, 77.205),
    );
    expect(deliveryMapPhaseFor(afterPickup), DeliveryMapPhase.drop);
    expect(afterPickupMarkers.map((m) => m.stop).toSet(), {
      DeliveryMapStop.rider,
      DeliveryMapStop.pickup,
      DeliveryMapStop.drop,
    });
    expect(
      deliveryMapFocusMarkers(
        afterPickupMarkers,
        deliveryMapPhaseFor(afterPickup),
      ).map((m) => m.stop),
      [DeliveryMapStop.rider, DeliveryMapStop.drop],
    );
  });
  test('terminal delivery clears active map markers', () {
    const delivered = ActiveDeliveryOrderModel(
      orderId: 42,
      deliveryStatus: 'delivered',
      pickupAddress: 'Pickup',
      dropAddress: 'Drop',
      pickupLatitude: 28.61,
      pickupLongitude: 77.2,
      dropLatitude: 28.62,
      dropLongitude: 77.21,
    );
    expect(deliveryMapPhaseFor(delivered), DeliveryMapPhase.complete);
    expect(deliveryMapMarkers(delivered, position(28.615, 77.205)), isEmpty);
  });
  test('camera bounds handles same, single and invalid coordinates', () {
    final single = deliveryCameraBoundsFor([
      const DeliveryMapMarker(DeliveryMapStop.pickup, 28.61, 77.2, 'Pickup'),
    ]);
    expect(single, isNotNull);
    expect(single!.north, greaterThan(single.south));
    expect(single.east, greaterThan(single.west));

    final same = deliveryCameraBoundsFor([
      const DeliveryMapMarker(DeliveryMapStop.pickup, 28.61, 77.2, 'Pickup'),
      const DeliveryMapMarker(DeliveryMapStop.drop, 28.61, 77.2, 'Customer'),
    ]);
    expect(same, isNotNull);
    expect(same!.north - same.south, greaterThan(0));

    expect(
      deliveryCameraBoundsFor([
        const DeliveryMapMarker(DeliveryMapStop.rider, 0, 0, 'You'),
      ]),
      isNull,
    );
  });
  test('invalid points are omitted without losing valid stops', () {
    for (final point in [
      position(0, 0),
      position(double.nan, 1),
      position(91, 1),
      position(1, double.infinity),
    ]) {
      expect(deliveryMapMarkers(order, point).length, 2);
    }
    expect(validMapCoordinate(0, 77), isTrue);
    expect(deliveryMapMarkers(order, null).length, 2);
  });
  test('rider heading is carried only when valid', () {
    final headed = deliveryMapMarkers(
      order,
      Position(
        latitude: 28.615,
        longitude: 77.205,
        timestamp: DateTime(2026),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 725,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    expect(
      headed.singleWhere((m) => m.stop == DeliveryMapStop.rider).heading,
      5,
    );
  });
  test('route model renders as a single Google polyline', () {
    final route = DeliveryRouteModel(
      encodedPolyline: 'encoded',
      points: const [
        DeliveryRoutePoint(28.61, 77.20),
        DeliveryRoutePoint(28.62, 77.21),
      ],
      distanceMeters: 1200,
      durationSeconds: 240,
      staticDurationSeconds: 220,
      provider: 'google',
      destinationType: 'pickup',
      generatedAt: DateTime(2026),
      expiresAt: DateTime(2026).add(const Duration(seconds: 60)),
    );
    final polylines = googleDeliveryPolylines(route);
    expect(polylines, hasLength(1));
    expect(polylines.single.points.first.latitude, 28.61);
  });
  testWidgets('configured renderer receives points and finishes loading', (
    tester,
  ) async {
    VoidCallback? ready;
    List<DeliveryMapMarker>? rendered;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmbeddedDeliveryMap(
            markers: deliveryMapMarkers(order, position(28.615, 77.205)),
            mapBuilder: (markers, onReady) {
              rendered = markers;
              ready = onReady;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    expect(rendered!.length, 3);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    ready!();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byTooltip('Follow rider'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'rider marker interpolates visually without changing input data',
    (tester) async {
      VoidCallback? ready;
      final rendered = <List<DeliveryMapMarker>>[];
      Widget harness(Position rider) {
        return MaterialApp(
          home: Scaffold(
            body: EmbeddedDeliveryMap(
              markers: deliveryMapMarkers(order, rider),
              focusMarkers: deliveryMapFocusMarkers(
                deliveryMapMarkers(order, rider),
                DeliveryMapPhase.pickup,
              ),
              mapBuilder: (markers, onReady) {
                ready = onReady;
                rendered.add(markers);
                return const SizedBox.expand();
              },
            ),
          ),
        );
      }

      final start = position(28.615, 77.205);
      final end = position(28.616, 77.206);
      await tester.pumpWidget(harness(start));
      ready!();
      await tester.pump();
      await tester.pumpWidget(harness(end));
      await tester.pump(const Duration(milliseconds: 325));

      final rider = rendered.last.singleWhere(
        (m) => m.stop == DeliveryMapStop.rider,
      );
      expect(rider.latitude, greaterThan(start.latitude));
      expect(rider.latitude, lessThanOrEqualTo(end.latitude));
      expect(end.latitude, 28.616);

      await tester.pump(const Duration(milliseconds: 400));
      expect(
        rendered.last
            .singleWhere((m) => m.stop == DeliveryMapStop.rider)
            .latitude,
        end.latitude,
      );
    },
  );
  testWidgets('large rider jump snaps instead of long interpolation', (
    tester,
  ) async {
    VoidCallback? ready;
    List<DeliveryMapMarker> rendered = const [];
    Widget harness(Position rider) {
      return MaterialApp(
        home: Scaffold(
          body: EmbeddedDeliveryMap(
            markers: deliveryMapMarkers(order, rider),
            mapBuilder: (markers, onReady) {
              ready = onReady;
              rendered = markers;
              return const SizedBox.expand();
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(harness(position(28.615, 77.205)));
    ready!();
    await tester.pump();
    await tester.pumpWidget(harness(position(29.2, 78.0)));
    await tester.pump();
    expect(
      rendered.singleWhere((m) => m.stop == DeliveryMapStop.rider).latitude,
      29.2,
    );
  });
  testWidgets(
    'map initialization deadline gives an error and disposes cleanly',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmbeddedDeliveryMap(
              markers: deliveryMapMarkers(order, null),
              mapBuilder: (_, _) => const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 11));
      expect(find.text('Map could not load'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  for (final message in [
    'GPS is disabled.',
    'Location permission is blocked.',
  ]) {
    testWidgets('location readiness state: $message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmbeddedDeliveryMap(
              markers: const [],
              locationMessage: message,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 11));
      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('Open Google Maps'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }
}
