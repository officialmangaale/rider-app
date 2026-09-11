import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/core/network/api_exception.dart';
import 'package:rydex_rider/core/services/map_launcher_service.dart';
import 'package:rydex_rider/domain/entities/app_models.dart';
import 'package:rydex_rider/features/delivery/models/delivery_models.dart';
import 'package:rydex_rider/features/delivery/presentation/active_delivery_screen.dart';
import 'package:rydex_rider/features/delivery/services/delivery_action_policy.dart';
import 'package:rydex_rider/presentation/providers/app_providers.dart';

/// The shape rider-service returns from GET /api/v1/orders/active.
Map<String, dynamic> _activeJson({
  String status = 'rider_arrived_restaurant',
  Object? pickupReady = false,
  String restaurantStatus = 'preparing',
}) => {
  'id': '13356',
  'order_id': 13356,
  'delivery_order_id': 19,
  'restaurant_name': 'Test Kitchen',
  'restaurant_phone': '+910000000002',
  'customer_name': 'Customer',
  'customer_phone': '+910000000003',
  'pickup_address': 'Shop 4, Market Road',
  'drop_address': 'House 12, Lane 3',
  'pickup_latitude': 28.41,
  'pickup_longitude': 77.04,
  'drop_latitude': 28.43,
  'drop_longitude': 77.05,
  'status': status,
  'delivery_status': status,
  'next_delivery_status': 'picked_up',
  'restaurant_order_status': restaurantStatus,
  'pickup_ready': pickupReady,
  'payment_method': 'cash',
  'amount': 250,
  'assignment_type': 'platform',
  'restaurant_owned': false,
};

ActiveDeliveryOrderModel _order(String status, {bool? pickupReady}) =>
    ActiveDeliveryOrderModel(
      orderId: 1,
      deliveryStatus: status,
      pickupAddress: 'pickup',
      dropAddress: 'drop',
      pickupLatitude: 28.41,
      pickupLongitude: 77.04,
      dropLatitude: 28.43,
      dropLongitude: 77.05,
      pickupReady: pickupReady,
    );

void main() {
  group('active delivery parsing', () {
    test('reads both stops, contacts and the kitchen state', () {
      final order = ActiveDeliveryOrderModel.fromJson(_activeJson());
      expect(order.pickupAddress, 'Shop 4, Market Road');
      expect(order.dropAddress, 'House 12, Lane 3');
      expect(order.pickupLatitude, 28.41);
      expect(order.dropLongitude, 77.05);
      expect(order.restaurantPhone, '+910000000002');
      expect(order.customerName, 'Customer');
      expect(order.customerPhone, '+910000000003');
      expect(order.restaurantOrderStatus, 'preparing');
      expect(order.pickupReady, isFalse);
      expect(order.nextDeliveryStatus, 'picked_up');
      expect(order.requiresCashCollection, isTrue);
    });

    test('an older backend without the new fields never blocks pickup', () {
      final json = _activeJson()
        ..remove('pickup_ready')
        ..remove('restaurant_order_status')
        ..remove('next_delivery_status');
      final order = ActiveDeliveryOrderModel.fromJson(json);
      expect(order.pickupReady, isNull);
      expect(isWaitingForKitchen(order), isFalse);
      expect(nextDeliveryActionFor(order)?.nextStatus, 'picked_up');
    });
  });

  group('next action', () {
    test('platform sequence, one step at a time', () {
      const expected = {
        'rider_assigned': 'rider_arrived_restaurant',
        'rider_arrived_restaurant': 'picked_up',
        'picked_up': 'on_the_way',
        'on_the_way': 'delivered',
        'out_for_delivery': 'delivered',
      };
      expected.forEach((current, next) {
        expect(
          nextDeliveryActionFor(_order(current))?.nextStatus,
          next,
          reason: current,
        );
      });
      expect(nextDeliveryActionFor(_order('delivered')), isNull);
    });

    test('pickup waits while the kitchen has not released the order', () {
      expect(
        isWaitingForKitchen(
          _order('rider_arrived_restaurant', pickupReady: false),
        ),
        isTrue,
      );
      expect(
        isWaitingForKitchen(
          _order('rider_arrived_restaurant', pickupReady: true),
        ),
        isFalse,
      );
      // Only the pickup step waits; reaching the restaurant never does.
      expect(
        isWaitingForKitchen(_order('rider_assigned', pickupReady: false)),
        isFalse,
      );
    });

    test(
      'before pickup the current stop is the restaurant, after it the customer',
      () {
        expect(isHeadingToPickup(_order('rider_assigned')), isTrue);
        expect(isHeadingToPickup(_order('rider_arrived_restaurant')), isTrue);
        expect(isHeadingToPickup(_order('picked_up')), isFalse);
        expect(isHeadingToPickup(_order('on_the_way')), isFalse);
      },
    );
  });

  group('status update errors', () {
    test('each backend code gets a specific, friendly message', () {
      String msg(String code) => deliveryUpdateErrorMessage(
        ApiException(
          message: 'raw backend text',
          statusCode: 409,
          errorCode: code,
        ),
      );
      expect(msg('ORDER_NOT_READY'), contains('not marked this order ready'));
      expect(msg('RESTAURANT_SYNC_FAILED'), contains('try again'));
      expect(msg('NOT_ASSIGNED_RIDER'), contains('no longer assigned'));
      expect(msg('CASH_COLLECTION_REQUIRED'), contains('cash'));
      expect(msg('ORDER_CLOSED'), contains('closed this order'));
      for (final code in ['ORDER_NOT_READY', 'RESTAURANT_SYNC_FAILED']) {
        expect(msg(code), isNot(contains('raw backend text')));
      }
    });

    test('unknown failures keep the previous message', () {
      expect(
        deliveryUpdateErrorMessage(Exception('boom')),
        'Could not update order. Refreshing the valid next step.',
      );
    });
  });

  group('navigation links', () {
    test('Android prefers Google Maps navigation, then the website', () {
      final uris = navigationUris(
        latitude: 28.41,
        longitude: 77.04,
        android: true,
      );
      expect(uris.map((u) => u.toString()), [
        'google.navigation:q=28.41%2C77.04',
        'https://www.google.com/maps/search/?api=1&query=28.41%2C77.04',
      ]);
    });

    test('other platforms go straight to the website', () {
      final uris = navigationUris(
        latitude: 28.41,
        longitude: 77.04,
        android: false,
      );
      expect(uris, hasLength(1));
      expect(uris.single.host, 'www.google.com');
    });

    test('without coordinates the address is used, safely encoded', () {
      final uris = navigationUris(
        latitude: 0,
        longitude: 0,
        address: ' Shop 4 & 5,\n Market #2 ',
        android: true,
      );
      expect(
        uris.first.toString(),
        startsWith('google.navigation:q=Shop%204%20%26%205'),
      );
      expect(uris.last.queryParameters['query'], 'Shop 4 & 5, Market #2');
    });

    test('nothing to navigate to gives no link', () {
      expect(navigationUris(latitude: 0, longitude: 0, android: true), isEmpty);
      expect(
        navigationUris(
          latitude: 0,
          longitude: 0,
          address: 'Drop address not available',
          android: true,
        ),
        isEmpty,
      );
    });

    test(
      'falls back to the website when no Maps app handles navigation',
      () async {
        final tried = <String>[];
        final service = UrlLauncherMapLauncherService(
          android: true,
          launcher: (uri, mode) async {
            tried.add('${uri.scheme}:${mode.name}');
            return uri.scheme == 'https';
          },
        );
        final result = await service.navigateTo(
          latitude: 28.41,
          longitude: 77.04,
        );
        expect(result.opened, isTrue);
        expect(result.targetUri?.scheme, 'https');
        expect(tried, [
          'google.navigation:externalApplication',
          'https:externalApplication',
        ]);
      },
    );

    test('a launcher that throws is a failed launch, not a crash', () async {
      final service = UrlLauncherMapLauncherService(
        android: true,
        launcher: (uri, mode) async => throw Exception('no activity'),
      );
      final result = await service.navigateTo(
        latitude: 28.41,
        longitude: 77.04,
      );
      expect(result.opened, isFalse);
    });
  });

  group('stop card', () {
    Future<void> pump(
      WidgetTester tester, {
      required MapLauncherService launcher,
      double lat = 28.41,
      double lng = 77.04,
      String address = 'Shop 4, Market Road',
    }) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [mapLauncherServiceProvider.overrideWithValue(launcher)],
          child: MaterialApp(
            home: Scaffold(
              body: DeliveryStopCard(
                title: 'Pickup',
                subtitle: 'Restaurant',
                icon: Icons.storefront_rounded,
                name: 'Test Kitchen',
                address: address,
                latitude: lat,
                longitude: lng,
                phone: '+910000000002',
                navigateLabel: 'Navigate to restaurant',
                callLabel: 'Call restaurant',
                isCurrent: true,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('navigates to the stop', (tester) async {
      final launcher = _FakeLauncher(opened: true);
      await pump(tester, launcher: launcher);
      expect(find.text('Call restaurant'), findsOneWidget);
      await tester.tap(find.text('Navigate to restaurant'));
      await tester.pump();
      expect(launcher.targets, [(28.41, 77.04)]);
    });

    testWidgets('navigate is disabled with no destination', (tester) async {
      final launcher = _FakeLauncher(opened: true);
      await pump(tester, launcher: launcher, lat: 0, lng: 0, address: '');
      await tester.tap(find.text('Navigate to restaurant'));
      await tester.pump();
      expect(launcher.targets, isEmpty);
      expect(find.textContaining('No location saved'), findsOneWidget);
    });

    testWidgets('a failed launch shows a friendly message', (tester) async {
      await pump(tester, launcher: _FakeLauncher(opened: false));
      await tester.tap(find.text('Navigate to restaurant'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open maps'), findsOneWidget);
    });
  });
}

class _FakeLauncher implements MapLauncherService {
  _FakeLauncher({required this.opened});
  final bool opened;
  final targets = <(double, double)>[];

  @override
  Future<MapLaunchResult> navigateTo({
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    targets.add((latitude, longitude));
    return MapLaunchResult(opened: opened);
  }

  @override
  Future<MapLaunchResult> openPoint({
    required double latitude,
    required double longitude,
    String? address,
  }) async => MapLaunchResult(opened: opened);

  @override
  Future<bool> openExternalRoute(DeliveryOrder order) async => opened;
}
