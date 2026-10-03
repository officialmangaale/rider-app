import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rydex_rider/core/network/api_client.dart';
import 'package:rydex_rider/core/network/api_exception.dart';
import 'package:rydex_rider/features/delivery/models/delivery_models.dart';
import 'package:rydex_rider/features/delivery/models/delivery_polyline_decoder.dart';
import 'package:rydex_rider/features/delivery/models/delivery_route.dart';
import 'package:rydex_rider/features/delivery/providers/delivery_route_provider.dart';
import 'package:rydex_rider/features/delivery/providers/rider_delivery_provider.dart';
import 'package:rydex_rider/features/delivery/services/rider_delivery_api_service.dart';

ApiEnvelope<T> envelope<T>(T data) =>
    ApiEnvelope(success: true, message: 'ok', data: data, statusCode: 200);

class RouteApi implements RiderDeliveryApiService {
  int calls = 0;
  bool fail = false;

  @override
  Future<ApiEnvelope<DeliveryRouteModel>> getDeliveryRoute({
    required ActiveDeliveryOrderModel order,
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    if (fail) {
      throw const ApiException(
        message: 'disabled',
        statusCode: 503,
        errorCode: 'ROUTE_PROVIDER_DISABLED',
      );
    }
    return envelope(
      DeliveryRouteModel(
        encodedPolyline: 'encoded',
        points: const [
          DeliveryRoutePoint(28.61, 77.20),
          DeliveryRoutePoint(28.62, 77.21),
        ],
        distanceMeters: 1200,
        durationSeconds: 240,
        staticDurationSeconds: 220,
        provider: 'google',
        destinationType: order.deliveryStatus == 'picked_up'
            ? 'drop'
            : 'pickup',
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const beforePickup = ActiveDeliveryOrderModel(
  orderId: 42,
  deliveryStatus: 'rider_assigned',
  pickupAddress: 'Pickup',
  dropAddress: 'Drop',
  pickupLatitude: 28.61,
  pickupLongitude: 77.20,
  dropLatitude: 28.62,
  dropLongitude: 77.21,
);

const afterPickup = ActiveDeliveryOrderModel(
  orderId: 42,
  deliveryStatus: 'picked_up',
  pickupAddress: 'Pickup',
  dropAddress: 'Drop',
  pickupLatitude: 28.61,
  pickupLongitude: 77.20,
  dropLatitude: 28.62,
  dropLongitude: 77.21,
);

Position fix(double latitude, double longitude, {double accuracy = 5}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  test('feature flag off clears state and does not call route API', () async {
    final api = RouteApi();
    final container = ProviderContainer(
      overrides: [riderDeliveryApiServiceProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    await container
        .read(deliveryRouteControllerProvider.notifier)
        .sync(order: beforePickup, position: fix(28.60, 77.19), enabled: false);

    expect(api.calls, 0);
    expect(container.read(deliveryRouteControllerProvider).route, isNull);
  });

  test('repeated location syncs do not spam route API', () async {
    final api = RouteApi();
    final container = ProviderContainer(
      overrides: [riderDeliveryApiServiceProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    final controller = container.read(deliveryRouteControllerProvider.notifier);

    await controller.sync(
      order: beforePickup,
      position: fix(28.60, 77.19),
      enabled: true,
    );
    for (var i = 0; i < 100; i++) {
      await controller.sync(
        order: beforePickup,
        position: fix(28.60001, 77.19001),
        enabled: true,
      );
    }

    expect(api.calls, 1);
    expect(
      container.read(deliveryRouteControllerProvider).status,
      DeliveryRouteStatus.ready,
    );
  });

  test(
    'pickup to drop transition clears old route and requests new one',
    () async {
      final api = RouteApi();
      final container = ProviderContainer(
        overrides: [riderDeliveryApiServiceProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        deliveryRouteControllerProvider.notifier,
      );

      await controller.sync(
        order: beforePickup,
        position: fix(28.60, 77.19),
        enabled: true,
      );
      await controller.sync(
        order: afterPickup,
        position: fix(28.60, 77.19),
        enabled: true,
      );

      final state = container.read(deliveryRouteControllerProvider);
      expect(api.calls, 2);
      expect(state.route?.destinationType, 'drop');
    },
  );

  test('route API failure falls back to marker-only map state', () async {
    final api = RouteApi()..fail = true;
    final container = ProviderContainer(
      overrides: [riderDeliveryApiServiceProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    await container
        .read(deliveryRouteControllerProvider.notifier)
        .sync(order: beforePickup, position: fix(28.60, 77.19), enabled: true);

    final state = container.read(deliveryRouteControllerProvider);
    expect(state.status, DeliveryRouteStatus.unavailable);
    expect(state.route, isNull);
    expect(state.errorCode, 'ROUTE_PROVIDER_DISABLED');
  });
}
