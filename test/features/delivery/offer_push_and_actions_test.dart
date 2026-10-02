import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rydex_rider/core/constants/app_constants.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_policy.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_store.dart';
import 'package:rydex_rider/features/delivery/background/offer_action_runner.dart';
import 'package:rydex_rider/features/delivery/background/offer_push_handler.dart';
import 'package:rydex_rider/features/delivery/background/request_alert_notifier.dart';
import 'package:rydex_rider/features/delivery/models/delivery_request_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_mode_test_fakes.dart';

/// The data rider-service sends for an offer (internal/push buildOfferMessage).
Map<String, dynamic> pushData({
  int requestId = 41,
  int orderId = 14659,
  Duration expiresIn = const Duration(seconds: 25),
  Map<String, dynamic> overrides = const {},
}) => {
  'type': 'DELIVERY_ORDER_REQUEST',
  'request_id': '$requestId',
  'order_id': '$orderId',
  'order_ref': '#$orderId',
  'order_type': 'food',
  'restaurant_name': 'Spice Hub',
  'pickup_address': '12 MG Road, Indiranagar',
  'delivery_area': 'Approx. 4 km from pickup',
  'distance_km': '1.23',
  'delivery_distance_km': '4',
  'amount': '250.00',
  'payment_mode': 'cod',
  'expires_at': DateTime.now().add(expiresIn).toUtc().toIso8601String(),
  ...overrides,
};

DeliveryRequestIntent intent(
  DeliveryRequestAction action, {
  int requestId = 41,
  int orderId = 14659,
  Duration expiresIn = const Duration(seconds: 25),
}) => DeliveryRequestIntent(
  requestId: requestId,
  orderId: orderId,
  expiresAt: DateTime.now().add(expiresIn).toUtc(),
  action: action,
);

Future<BackgroundModeStore> signedInStore({String? token = 'jwt'}) async {
  SharedPreferences.setMockInitialValues({
    if (token != null) AppConstants.preferencesAccessTokenKey: token,
  });
  return BackgroundModeStore(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('push payload', () {
    test('becomes the offer a rider needs to decide', () {
      final offer = offerFromPushData(pushData())!;
      expect(offer.requestId, 41);
      expect(offer.orderId, 14659);
      expect(offer.orderRef, '#14659');
      expect(offer.restaurantName, 'Spice Hub');
      expect(offer.pickupAddress, '12 MG Road, Indiranagar');
      expect(offer.deliveryArea, 'Approx. 4 km from pickup');
      expect(offer.distanceKm, 1.23);
      expect(offer.amount, 250);
      expect(offer.paymentMode, 'cod');
      expect(offer.orderType, 'food');
    });

    test('anything that is not a usable offer is ignored', () {
      final now = DateTime.now().add(const Duration(seconds: 20));
      for (final data in <Map<String, dynamic>>[
        {},
        {'type': 'ORDER_STATUS_UPDATED', 'order_id': '1'},
        pushData(overrides: {'request_id': ''}),
        pushData(overrides: {'request_id': '0'}),
        pushData(overrides: {'order_id': 'abc'}),
        pushData(overrides: {'expires_at': 'soon'}),
        pushData(overrides: {'expires_at': null}),
      ]) {
        expect(offerFromPushData(data), isNull, reason: '$data (now=$now)');
      }
    });

    test('the delivery area falls back to the distance when absent', () {
      final offer = offerFromPushData(
        pushData(overrides: {'delivery_area': '', 'delivery_distance_km': '6'}),
      )!;
      expect(offer.deliveryArea, 'Approx. 6 km from pickup');
    });

    test('a closed message names its order', () {
      expect(
        closedOfferOrderId({
          'type': 'DELIVERY_ORDER_REQUEST_CLOSED',
          'order_id': '14659',
        }),
        14659,
      );
      expect(closedOfferOrderId(pushData()), isNull);
      expect(
        closedOfferOrderId({'type': 'DELIVERY_ORDER_REQUEST_CLOSED'}),
        isNull,
      );
    });

    test('notification text carries everything and no customer detail', () {
      final offer = offerFromPushData(pushData())!;
      expect(requestNotificationTitle(offer), 'New delivery request #14659');
      final body = requestNotificationBody(offer);
      for (final part in ['Spice Hub', '1.2 km to pickup', 'Approx. 4 km', '250', 'COD']) {
        expect(body, contains(part));
      }
      final details = requestNotificationDetails(offer);
      expect(details, contains('#14659 · Spice Hub'));
      expect(details, contains('Pickup: 12 MG Road, Indiranagar'));
      expect(details, contains('Delivery: Approx. 4 km from pickup'));
      expect(details, contains('Distance to pickup: 1.2 km'));
      expect(details, contains('Order value: Rs 250 (COD)'));
      // The offer type has no place for these, so they cannot be shown.
      expect('$body $details'.toLowerCase(), isNot(contains('customer')));
      expect('$body $details'.toLowerCase(), isNot(contains('phone')));
    });
  });

  group('push handler', () {
    late FakeNotifier notifier;
    final fixedNow = DateTime.now();

    OfferPushHandler handlerFor(BackgroundModeStore store) =>
        OfferPushHandler(
          store: store,
          notifier: notifier,
          clock: () => fixedNow,
        );

    setUp(() => notifier = FakeNotifier());

    test('posts an actionable notification for a live offer', () async {
      final store = await signedInStore();
      final result = await handlerFor(store).handle(pushData());

      expect(result, OfferPushResult.posted);
      expect(notifier.showing.keys, [41]);
      expect(notifier.showing[41]!.orderId, 14659);
    });

    test('the same offer from push and poll rings once', () async {
      final store = await signedInStore();
      final handler = handlerFor(store);
      final data = pushData();

      expect(await handler.handle(data), OfferPushResult.posted);
      expect(await handler.handle(data), OfferPushResult.duplicate);
      expect(notifier.posts, 1);

      // The Online service's poll alerted for it first: the push stays quiet.
      final polled = offerFromPushData(pushData(requestId: 42))!;
      await store.rememberAlerted([polled.offerKey]);
      expect(
        await handler.handle(
          pushData(
            requestId: 42,
            overrides: {
              'expires_at': polled.expiresAt.toUtc().toIso8601String(),
            },
          ),
        ),
        OfferPushResult.duplicate,
      );
      expect(notifier.posts, 1);
    });

    test('an offer that expired in flight is not shown', () async {
      final store = await signedInStore();
      final result = await handlerFor(
        store,
      ).handle(pushData(expiresIn: const Duration(seconds: -3)));
      expect(result, OfferPushResult.expired);
      expect(notifier.posts, 0);
    });

    test('a phone with nobody signed in shows nothing', () async {
      final store = await signedInStore(token: null);
      expect(
        await handlerFor(store).handle(pushData()),
        OfferPushResult.signedOut,
      );
      expect(notifier.posts, 0);
    });

    test('other pushes are ignored', () async {
      final store = await signedInStore();
      expect(
        await handlerFor(store).handle({'type': 'ORDER_STATUS_UPDATED'}),
        OfferPushResult.ignored,
      );
      expect(notifier.posts, 0);
    });

    test('a closed message removes that order\'s notification', () async {
      final store = await signedInStore();
      final handler = handlerFor(store);
      await handler.handle(pushData(requestId: 41, orderId: 14659));
      await handler.handle(pushData(requestId: 43, orderId: 20000));
      notifier.orderByRequest
        ..[41] = 14659
        ..[43] = 20000;

      final result = await handler.handle({
        'type': 'DELIVERY_ORDER_REQUEST_CLOSED',
        'order_id': '14659',
        'reason': 'assigned_to_other',
      });

      expect(result, OfferPushResult.closed);
      expect(notifier.showing.keys, [43], reason: 'only the closed order goes');
    });
  });

  group('accept and decline from the notification', () {
    late FakeNotifier notifier;
    late List<http.Request> requests;

    setUp(() {
      notifier = FakeNotifier();
      requests = [];
    });

    OfferActionRunner runner(
      BackgroundModeStore store,
      Future<http.Response> Function(http.Request) respond,
    ) => OfferActionRunner(
      store: store,
      notifier: notifier,
      client: MockClient((request) {
        requests.add(request);
        return respond(request);
      }),
      requestTimeout: const Duration(seconds: 2),
    );

    http.Response json(int status, Map<String, dynamic> body) =>
        http.Response(jsonEncode(body), status);

    test('Accept is confirmed by the backend before it says assigned', () async {
      final store = await signedInStore();
      final release = Completer<void>();
      final run = runner(store, (request) async {
        await release.future;
        return json(200, {
          'status': 'success',
          'data': {'request_id': 41, 'order_id': 14659},
        });
      });

      final outcome = run.run(intent(DeliveryRequestAction.accept));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Sent, but unanswered: the rider sees progress, not an assignment.
      expect(requests.single.url.path, '/api/v1/riders/order-requests/41/accept');
      expect(requests.single.headers['Authorization'], 'Bearer jwt');
      final pending = notifier.lastOutcomeFor(41)!;
      expect(pending.inProgress, isTrue);
      expect(pending.title, isNot(contains('accepted')));
      expect(store.hasActiveDelivery, isFalse);

      release.complete();
      expect(await outcome, OfferActionOutcome.accepted);

      final done = notifier.lastOutcomeFor(41)!;
      expect(done.title, 'Delivery accepted #14659');
      expect(done.inProgress, isFalse);
      // Tapping it opens the app on the active delivery, not an offer sheet.
      expect(DeliveryRequestIntent.fromLocal(done.payload, null), isNull);
      await store.reload();
      expect(store.hasActiveDelivery, isTrue);
    });

    test('the offer notification cannot be tapped twice while in flight', () async {
      final store = await signedInStore();
      final release = Completer<void>();
      final run = runner(store, (request) async {
        await release.future;
        return json(200, {
          'data': {'order_id': 14659},
        });
      });

      final first = run.run(intent(DeliveryRequestAction.accept));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = await run.run(intent(DeliveryRequestAction.accept));
      final decline = await run.run(intent(DeliveryRequestAction.decline));

      expect(second, OfferActionOutcome.alreadyRunning);
      expect(decline, OfferActionOutcome.alreadyRunning);
      release.complete();
      await first;
      expect(requests, hasLength(1));
      // The buttons are gone as soon as the first tap starts: the notification
      // is replaced by the progress message.
      expect(notifier.showing, isEmpty);
    });

    test('another rider accepting first is reported, not called assigned', () async {
      final store = await signedInStore();
      final outcome = await runner(
        store,
        (_) async => json(409, {
          'status': 'error',
          'message': 'This order has already been assigned.',
          'error_code': 'ORDER_ALREADY_ASSIGNED',
        }),
      ).run(intent(DeliveryRequestAction.accept));

      expect(outcome, OfferActionOutcome.takenByOther);
      expect(notifier.lastOutcomeFor(41)!.title, 'Delivery already taken');
      expect(store.hasActiveDelivery, isFalse);
    });

    test('an expired offer is reported and never assigned', () async {
      final store = await signedInStore();
      final outcome = await runner(
        store,
        (_) async => json(409, {
          'message': 'This offer has expired.',
          'error_code': 'OFFER_EXPIRED',
        }),
      ).run(intent(DeliveryRequestAction.accept));

      expect(outcome, OfferActionOutcome.expired);
      expect(notifier.lastOutcomeFor(41)!.title, 'Request expired');
      expect(store.hasActiveDelivery, isFalse);
    });

    test('an already expired offer makes no request at all', () async {
      final store = await signedInStore();
      for (final action in [
        DeliveryRequestAction.accept,
        DeliveryRequestAction.decline,
      ]) {
        final outcome = await runner(
          store,
          (_) async => json(200, {}),
        ).run(intent(action, expiresIn: const Duration(seconds: -5)));
        expect(outcome, OfferActionOutcome.expired);
      }
      expect(requests, isEmpty);
    });

    test('a cancelled order or unavailable rider shows the backend reason', () async {
      final store = await signedInStore();
      final outcome = await runner(
        store,
        (_) async => json(409, {
          'message': 'Order is no longer active.',
          'error_code': 'OFFER_UNAVAILABLE',
        }),
      ).run(intent(DeliveryRequestAction.accept));

      expect(outcome, OfferActionOutcome.unavailable);
      expect(notifier.lastOutcomeFor(41)!.body, 'Order is no longer active.');
    });

    test('a lost response is checked against the active order', () async {
      final store = await signedInStore();
      final outcome = await runner(store, (request) async {
        if (request.method == 'POST') throw const SocketException('lost');
        return json(200, {
          'data': {'order_id': 14659},
        });
      }).run(intent(DeliveryRequestAction.accept));

      // The backend had committed it: the active order proves it.
      expect(outcome, OfferActionOutcome.accepted);
      expect(requests.map((r) => r.url.path), [
        '/api/v1/riders/order-requests/41/accept',
        '/api/v1/orders/active',
      ]);
    });

    test('with no answer and no proof, acceptance is not claimed', () async {
      final store = await signedInStore();
      final outcome = await runner(store, (request) async {
        throw const SocketException('offline');
      }).run(intent(DeliveryRequestAction.accept));

      expect(outcome, OfferActionOutcome.unconfirmed);
      final shown = notifier.lastOutcomeFor(41)!;
      expect(shown.title, startsWith('Could not confirm'));
      expect(shown.title.toLowerCase(), isNot(contains('accepted')));
      expect(store.hasActiveDelivery, isFalse);
      // Tapping it reopens the app on this offer while it is still live.
      final reopen = DeliveryRequestIntent.fromLocal(shown.payload, null)!;
      expect(reopen.requestId, 41);
      expect(reopen.action, DeliveryRequestAction.open);
    });

    test('an active order that is a different order is not our acceptance', () async {
      final store = await signedInStore();
      final outcome = await runner(store, (request) async {
        if (request.method == 'POST') throw TimeoutException('slow');
        return json(200, {
          'data': {'order_id': 99999},
        });
      }).run(intent(DeliveryRequestAction.accept));
      expect(outcome, OfferActionOutcome.unconfirmed);
    });

    test('a server error is not a refusal', () async {
      final store = await signedInStore();
      final outcome = await runner(
        store,
        (_) async => json(503, {'message': 'busy'}),
      ).run(intent(DeliveryRequestAction.accept));
      expect(outcome, OfferActionOutcome.unconfirmed);
      expect(store.hasActiveDelivery, isFalse);
    });

    test('with no session the rider is sent to sign in and nothing is sent', () async {
      final store = await signedInStore(token: null);
      final outcome = await runner(
        store,
        (_) async => json(200, {}),
      ).run(intent(DeliveryRequestAction.accept));
      expect(outcome, OfferActionOutcome.unauthorized);
      expect(requests, isEmpty);
      expect(notifier.lastOutcomeFor(41)!.title, contains('Sign in'));
    });

    test('an expired token is reported, not retried', () async {
      final store = await signedInStore();
      final outcome = await runner(
        store,
        (_) async => json(401, {'message': 'expired'}),
      ).run(intent(DeliveryRequestAction.accept));
      expect(outcome, OfferActionOutcome.unauthorized);
      expect(requests, hasLength(1));
    });

    test('Decline touches only this rider\'s offer and clears the notification', () async {
      final store = await signedInStore();
      notifier.showing[41] = offerFromPushData(pushData())!;
      final outcome = await runner(
        store,
        (_) async => json(200, {'message': 'Request rejected'}),
      ).run(intent(DeliveryRequestAction.decline));

      expect(outcome, OfferActionOutcome.declined);
      expect(requests.single.url.path, '/api/v1/riders/order-requests/41/reject');
      // Nothing that cancels the customer's order or other riders' offers.
      expect(requests.every((r) => !r.url.path.contains('cancel')), isTrue);
      expect(requests.every((r) => !r.url.path.contains('/orders/14659')), isTrue);
      expect(notifier.showing, isEmpty);
      expect(notifier.lastOutcomeFor(41)?.inProgress ?? false, isFalse);
      expect(store.hasActiveDelivery, isFalse);
    });

    test('Declining an offer that is already gone clears it quietly', () async {
      final store = await signedInStore();
      final outcome = await runner(
        store,
        (_) async => json(409, {'message': 'request already responded to'}),
      ).run(intent(DeliveryRequestAction.decline));
      expect(outcome, OfferActionOutcome.expired);
      expect(notifier.showing, isEmpty);
    });

    test('a decline that cannot reach the server says so', () async {
      final store = await signedInStore();
      final outcome = await runner(store, (request) async {
        throw http.ClientException('no route');
      }).run(intent(DeliveryRequestAction.decline));

      expect(outcome, OfferActionOutcome.unconfirmed);
      expect(notifier.lastOutcomeFor(41)!.title, startsWith('Could not decline'));
    });

    test('tapping the body is not an action', () async {
      final store = await signedInStore();
      final outcome = await runner(
        store,
        (_) async => json(200, {}),
      ).run(intent(DeliveryRequestAction.open));
      expect(outcome, isNull);
      expect(requests, isEmpty);
    });
  });

  group('accept response classification', () {
    test('only a 2xx assigns', () {
      expect(
        classifyAcceptResponse(200, '{"data":{"order_id":7}}').outcome,
        OfferActionOutcome.accepted,
      );
      expect(classifyAcceptResponse(200, '{"data":{"order_id":7}}').orderId, 7);
      for (final status in [400, 403, 404, 409, 422, 500, 502, 503]) {
        expect(
          classifyAcceptResponse(status, '{}').outcome,
          isNot(OfferActionOutcome.accepted),
          reason: 'HTTP $status',
        );
      }
      expect(
        classifyAcceptResponse(200, 'not json').outcome,
        OfferActionOutcome.accepted,
        reason: 'the status alone decides success',
      );
    });

    test('backend codes map to specific outcomes', () {
      expect(
        classifyAcceptResponse(409, '{"error_code":"ORDER_ALREADY_ASSIGNED"}').outcome,
        OfferActionOutcome.takenByOther,
      );
      expect(
        classifyAcceptResponse(409, '{"error_code":"OFFER_EXPIRED"}').outcome,
        OfferActionOutcome.expired,
      );
      expect(
        classifyAcceptResponse(409, '{"error_code":"RIDER_UNAVAILABLE","message":"offline"}').outcome,
        OfferActionOutcome.unavailable,
      );
      expect(classifyAcceptResponse(401, '{}').outcome, OfferActionOutcome.unauthorized);
      expect(classifyAcceptResponse(500, '{}').outcome, OfferActionOutcome.unconfirmed);
    });
  });

  group('notification', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    List<Map<String, dynamic>> channels = [];

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      SharedPreferences.setMockInitialValues({});
      calls.clear();
      channels = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            switch (call.method) {
              case 'initialize':
                return true;
              case 'areNotificationsEnabled':
                return true;
              case 'getNotificationChannels':
                return channels;
            }
            return null;
          });
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Map<String, dynamic> shown(String channelId) {
      final post = calls.lastWhere(
        (c) =>
            c.method == 'show' &&
            (c.arguments as Map)['platformSpecifics']['channelId'] == channelId,
      );
      return Map<String, dynamic>.from(post.arguments as Map);
    }

    test('heads-up offer: max importance, private on the lock screen, full text', () async {
      final offer = offerFromPushData(pushData())!;
      await RequestAlertNotifier().showRequest(offer);

      final data = shown(RequestAlertNotifier.requestChannelId);
      final android = data['platformSpecifics'] as Map;
      expect(data['title'], 'New delivery request #14659');
      expect(android['importance'], Importance.max.value);
      expect(android['priority'], Priority.max.value);
      // Private, never public: the rider's own lock-screen setting decides
      // whether the content shows.
      expect(android['visibility'], NotificationVisibility.private.index);
      expect(android['fullScreenIntent'], isFalse);
      final style = android['styleInformation'] as Map;
      expect(style['bigText'], contains('Pickup: 12 MG Road, Indiranagar'));
      expect(style['bigText'], contains('Delivery: Approx. 4 km from pickup'));
      // The channel that carries the ringing exists before it is used.
      expect(
        calls.where((c) => c.method == 'createNotificationChannel').map((c) => (c.arguments as Map)['id']),
        containsAll([
          RequestAlertNotifier.requestChannelId,
          RequestAlertNotifier.updatesChannelId,
        ]),
      );
      // Offer actions run in a background isolate, so the plugin must know the
      // top-level callback.
      final init = calls.firstWhere((c) => c.method == 'initialize').arguments as Map;
      expect(init['callback_handle'], isNotNull);
    });

    test('an outcome replaces the offer under the same id, quietly', () async {
      final notifier = RequestAlertNotifier();
      await notifier.showOutcome(
        requestId: 41,
        title: 'Delivery accepted #14659',
        body: 'assigned',
        visibleFor: const Duration(seconds: 45),
      );
      final data = shown(RequestAlertNotifier.updatesChannelId);
      final android = data['platformSpecifics'] as Map;
      expect(data['id'], requestNotificationId(41));
      expect(android['importance'], Importance.low.value);
      expect(android['timeoutAfter'], 45000);
      expect(android['visibility'], NotificationVisibility.private.index);
      // No insistent flag: replacing the ringing notification stops the ring.
      expect(android['additionalFlags'], isNull);
    });

    test('a closed offer removes the notifications posted for that order', () async {
      final notifier = RequestAlertNotifier();
      await notifier.showRequest(offerFromPushData(pushData(requestId: 41, orderId: 14659))!);
      await notifier.showRequest(offerFromPushData(pushData(requestId: 43, orderId: 20000))!);
      calls.clear();

      await notifier.cancelOffersForOrder(14659);

      final cancelled = calls
          .where((c) => c.method == 'cancel')
          .map((c) => (c.arguments as Map)['id'])
          .toList();
      expect(cancelled, [requestNotificationId(41)]);
    });

    test('health reports a channel the rider has turned down', () async {
      final notifier = RequestAlertNotifier();
      channels = [
        {
          'id': RequestAlertNotifier.requestChannelId,
          'name': 'Delivery requests',
          'description': 'Rings when a new delivery request arrives.',
          'groupId': null,
          'showBadge': true,
          'importance': Importance.low.value,
          'bypassDnd': false,
          'playSound': true,
          'enableLights': false,
          'enableVibration': true,
          'vibrationPattern': null,
          'ledColor': 0,
          'audioAttributesUsage': 6,
        },
      ];
      final lowered = await notifier.health();
      expect(lowered.notificationsEnabled, isTrue);
      expect(lowered.channelImportance, Importance.low);
      expect(lowered.canHeadsUp, isFalse);

      channels = [
        {
          'id': RequestAlertNotifier.requestChannelId,
          'name': 'Delivery requests',
          'description': 'Rings when a new delivery request arrives.',
          'groupId': null,
          'showBadge': true,
          'importance': Importance.max.value,
          'bypassDnd': false,
          'playSound': true,
          'enableLights': false,
          'enableVibration': true,
          'vibrationPattern': null,
          'ledColor': 0,
          'audioAttributesUsage': 6,
        },
      ];
      expect((await notifier.health()).canHeadsUp, isTrue);
    });
  });
}
