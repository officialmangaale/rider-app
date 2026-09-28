import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rydex_rider/core/network/api_exception.dart';
import 'package:rydex_rider/core/router/app_routes.dart';
import 'package:rydex_rider/features/delivery/models/delivery_models.dart';
import 'package:rydex_rider/features/delivery/models/delivery_request_intent.dart';
import 'package:rydex_rider/features/delivery/providers/request_notification_provider.dart';
import 'package:rydex_rider/features/delivery/providers/rider_delivery_provider.dart';
import 'package:rydex_rider/features/delivery/widgets/incoming_order_request_sheet.dart';
import 'package:rydex_rider/features/delivery/widgets/incoming_request_host.dart';

RiderOrderRequestModel offer(int id, {DateTime? expiry}) =>
    RiderOrderRequestModel.fromJson({
      'request_id': '$id',
      'order_id': '${100 + id}',
      'restaurant_id': 27,
      'restaurant_name': 'Kitchen $id',
      'pickup_address': 'Pickup $id',
      'amount': '250',
      'distance_km': '1.2',
      'expires_at': (expiry ?? DateTime.now().add(const Duration(minutes: 2)))
          .toUtc()
          .toIso8601String(),
    });

class TestDeliveryController extends RiderDeliveryController {
  TestDeliveryController([this.initial = const []]);
  final List<RiderOrderRequestModel> initial;
  int accepts = 0;
  int declines = 0;
  int refreshes = 0;
  int? actedOn;
  Completer<void>? acceptance;
  bool failDecline = false;

  @override
  RiderDeliveryState build() =>
      RiderDeliveryState(isOnline: true, pendingRequests: initial);
  void offers(List<RiderOrderRequestModel> requests) {
    state = state.copyWith(pendingRequests: requests);
  }

  @override
  Future<void> refreshPendingRequests() async {
    refreshes++;
  }

  @override
  Future<void> acceptRequest(int id) async {
    accepts++;
    actedOn = id;
    await acceptance?.future;
    state = state.copyWith(activeOrderId: 100 + id, pendingRequests: []);
  }

  @override
  Future<void> rejectRequest(int id) async {
    declines++;
    actedOn = id;
    if (failDecline) throw const ApiException(message: 'Connection lost');
    offers(state.pendingRequests.where((r) => r.requestId != id).toList());
  }
}

class Harness {
  Harness(this.controller) {
    container = ProviderContainer(
      overrides: [
        riderDeliveryControllerProvider.overrideWith(() => controller),
      ],
    );
    router = GoRouter(
      navigatorKey: key,
      initialLocation: '/earnings',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, _) => const Scaffold(body: Text('Home tab')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/earnings',
                  builder: (_, _) => const Scaffold(body: Text('Earnings tab')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.delivery,
          builder: (_, _) => const Scaffold(body: Text('Pickup details')),
        ),
      ],
    );
  }
  final TestDeliveryController controller;
  final key = GlobalKey<NavigatorState>();
  late final ProviderContainer container;
  late final GoRouter router;

  Widget get widget => UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      builder: (_, child) =>
          IncomingRequestHost(navigatorKey: key, enabled: true, child: child!),
    ),
  );
  void tapNotification(
    RiderOrderRequestModel offer, {
    DeliveryRequestAction action = DeliveryRequestAction.open,
  }) {
    container
        .read(deliveryRequestIntentProvider.notifier)
        .state = DeliveryRequestIntent(
      requestId: offer.requestId,
      orderId: offer.orderId,
      expiresAt: offer.expiresAt,
      action: action,
    );
  }

  void dispose() {
    router.dispose();
    container.dispose();
  }
}

void main() {
  Future<Harness> mount(
    WidgetTester tester,
    TestDeliveryController controller,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final harness = Harness(controller);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets(
    'offer opens above a non-Dashboard tab; duplicate snapshots do not stack',
    (tester) async {
      final c = TestDeliveryController();
      await mount(tester, c);
      final request = offer(1);
      c.offers([request]);
      await tester.pumpAndSettle();
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Earnings tab'), findsOneWidget);
      c.offers([request]); // socket + FCM + poll reconciling the same offer
      await tester.pumpAndSettle();
      expect(find.byType(IncomingOrderRequestSheet), findsOneWidget);
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(c.declines, 1);
      expect(find.byType(IncomingOrderRequestSheet), findsNothing);
    },
  );

  testWidgets(
    'launch/reconnect snapshot presents existing offers sequentially',
    (tester) async {
      final a = offer(1), b = offer(2);
      final c = TestDeliveryController([a, b]);
      await mount(tester, c);
      expect(find.text('Kitchen 1'), findsOneWidget);
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Kitchen 2'), findsOneWidget);
      expect(find.byType(IncomingOrderRequestSheet), findsOneWidget);
    },
  );

  testWidgets('background arrival waits for foreground, then opens the offer', (
    tester,
  ) async {
    final c = TestDeliveryController();
    await mount(tester, c);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    c.offers([offer(1)]);
    await tester.pump();
    expect(find.byType(IncomingOrderRequestSheet), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Accept'), findsOneWidget);
  });

  testWidgets(
    'notification tap replaces another sheet with the targeted request',
    (tester) async {
      final a = offer(1), b = offer(2);
      final c = TestDeliveryController([a, b]);
      final h = await mount(tester, c);
      h.tapNotification(b);
      await tester.pumpAndSettle();
      expect(c.refreshes, 1);
      expect(find.text('Kitchen 2'), findsOneWidget);
      expect(find.byType(IncomingOrderRequestSheet), findsOneWidget);
    },
  );

  testWidgets(
    'notification Accept validates then uses existing action and opens details',
    (tester) async {
      final request = offer(3);
      final c = TestDeliveryController([request]);
      final h = await mount(tester, c);
      h.tapNotification(request, action: DeliveryRequestAction.accept);
      await tester.pumpAndSettle();
      expect(c.refreshes, 1);
      expect(c.accepts, 1);
      expect(c.actedOn, 3);
      expect(find.text('Pickup details'), findsOneWidget);
    },
  );

  testWidgets(
    'old notification cannot accept a renewed offer with the same ID',
    (tester) async {
      final old = offer(
        1,
        expiry: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      final c = TestDeliveryController([offer(1)]);
      final h = await mount(tester, c);
      h.tapNotification(old, action: DeliveryRequestAction.accept);
      await tester.pumpAndSettle();
      expect(c.accepts, 0);
      expect(
        find.text(
          'This request has expired, was cancelled, or is already assigned.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('double Accept tap sends one action and waits for its result', (
    tester,
  ) async {
    final c = TestDeliveryController([offer(1)])
      ..acceptance = Completer<void>();
    await mount(tester, c);
    await tester.tap(find.text('Accept'));
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(c.accepts, 1);
    expect(find.byType(IncomingOrderRequestSheet), findsOneWidget);
    c.acceptance!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Pickup details'), findsOneWidget);
  });

  testWidgets(
    'Decline failure remains actionable and a successful retry dismisses',
    (tester) async {
      final c = TestDeliveryController([offer(1)])..failDecline = true;
      await mount(tester, c);
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Connection lost'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      c.failDecline = false;
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(c.declines, 2);
      expect(find.byType(IncomingOrderRequestSheet), findsNothing);
    },
  );

  testWidgets(
    'server cancellation/other winner removes the displayed request',
    (tester) async {
      final c = TestDeliveryController([offer(1)]);
      await mount(tester, c);
      c.offers([]);
      await tester.pumpAndSettle();
      expect(find.byType(IncomingOrderRequestSheet), findsNothing);
      expect(c.accepts, 0);
    },
  );

  testWidgets('expired requests are never presented', (tester) async {
    await mount(
      tester,
      TestDeliveryController([
        offer(1, expiry: DateTime.now().subtract(const Duration(seconds: 1))),
      ]),
    );
    expect(find.byType(IncomingOrderRequestSheet), findsNothing);
  });

  testWidgets('server deadline dismisses an unanswered sheet', (tester) async {
    final c = TestDeliveryController([
      offer(1, expiry: DateTime.now().add(const Duration(seconds: 2))),
    ]);
    await mount(tester, c);
    expect(find.text('Accept'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2100)),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(IncomingOrderRequestSheet), findsNothing);
    expect(find.text('Order request expired'), findsOneWidget);
    expect(c.accepts, 0);
  });

  testWidgets(
    'expiry while acceptance is pending cannot pop away its eventual result',
    (tester) async {
      final c = TestDeliveryController([
        offer(1, expiry: DateTime.now().add(const Duration(seconds: 2))),
      ])..acceptance = Completer<void>();
      await mount(tester, c);
      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2100)),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(IncomingOrderRequestSheet), findsOneWidget);
      c.acceptance!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Pickup details'), findsOneWidget);
    },
  );

  testWidgets(
    'notification Decline acts on its request once and leaves other offers',
    (tester) async {
      final a = offer(1), b = offer(2);
      final c = TestDeliveryController([a, b]);
      final h = await mount(tester, c);
      h.tapNotification(b, action: DeliveryRequestAction.decline);
      await tester.pumpAndSettle();
      expect(c.declines, 1);
      expect(c.actedOn, 2);
      expect(c.accepts, 0);
      expect(
        h.container
            .read(riderDeliveryControllerProvider)
            .pendingRequests
            .single
            .requestId,
        1,
      );
    },
  );
}
