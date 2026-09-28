import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_policy.dart';
import 'package:rydex_rider/features/delivery/background/request_alert_notifier.dart';
import 'package:rydex_rider/features/delivery/models/delivery_models.dart';
import 'package:rydex_rider/features/delivery/models/delivery_request_intent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  Map<String, dynamic>? launch;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    launch = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getNotificationAppLaunchDetails') return launch;
          if (call.method == 'initialize') return true;
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  PolledOffer offer(DateTime expiresAt) => PolledOffer(
    requestId: 17,
    orderId: 100,
    expiresAt: expiresAt,
    restaurantName: 'Kitchen',
    distanceKm: 1.2,
    amount: 250,
    paymentMode: 'cash',
  );

  test(
    'Android offers keep channel, expiry, stable ID and both background actions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now().toUtc();
      final request = offer(now.add(const Duration(seconds: 23)));
      final notifier = RequestAlertNotifier();
      await notifier.showRequest(request, now: now);
      await notifier.showRequest(request, now: now);
      final posts = calls.where((call) => call.method == 'show').toList();
      expect(posts.length, 2);
      final data = Map<String, dynamic>.from(posts.first.arguments as Map);
      expect(data['id'], requestNotificationId(17));
      expect((posts.last.arguments as Map)['id'], data['id']);
      final android = data['platformSpecifics'] as Map;
      expect(android['channelId'], RequestAlertNotifier.requestChannelId);
      expect(android['timeoutAfter'], 23000);
      expect(android['onlyAlertOnce'], true);
      final actions = android['actions'] as List;
      expect(actions.map((a) => a['id']), ['accept', 'decline']);
      // Answered from the shade: the app is not opened, and the notification is
      // kept until the outcome replaces it, so a failed attempt can be seen.
      expect(actions.every((a) => a['showsUserInterface'] == false), isTrue);
      expect(actions.every((a) => a['cancelNotification'] == false), isTrue);
      final intent = DeliveryRequestIntent.fromLocal(
        data['payload'] as String,
        'accept',
      )!;
      expect(intent.requestId, 17);
      expect(intent.orderId, 100);
      expect(intent.expiresAt, request.expiresAt);
      expect(intent.action, DeliveryRequestAction.accept);
      expect(calls.where((call) => call.method == 'initialize').length, 1);
    },
  );

  test(
    'cold-launch action is delivered once and warm tap reaches the same callback',
    () async {
      final payload = jsonEncode({
        'type': 'DELIVERY_ORDER_REQUEST',
        'request_id': 17,
        'order_id': 100,
        'expires_at': DateTime.now()
            .add(const Duration(seconds: 25))
            .toUtc()
            .toIso8601String(),
      });
      final response = {
        'notificationId': requestNotificationId(17),
        'actionId': 'decline',
        'notificationResponseType': 1,
        'payload': payload,
      };
      launch = {
        'notificationLaunchedApp': true,
        'notificationResponse': response,
      };
      final received = <DeliveryRequestIntent?>[];
      final notifier = RequestAlertNotifier(
        onResponse: (r) {
          received.add(DeliveryRequestIntent.fromLocal(r.payload, r.actionId));
        },
      );
      await notifier.initialize();
      await notifier.initialize();
      expect(received.length, 1);
      expect(received.single!.action, DeliveryRequestAction.decline);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('didReceiveNotificationResponse', {
                ...response,
                'actionId': 'accept',
              }),
            ),
            (_) {},
          );
      expect(received.length, 2);
      expect(received.last!.action, DeliveryRequestAction.accept);
    },
  );

  test('expired notification is not posted', () async {
    final now = DateTime.now();
    await RequestAlertNotifier().showRequest(
      offer(now.subtract(const Duration(seconds: 1))),
      now: now,
    );
    expect(calls.where((call) => call.method == 'show'), isEmpty);
  });

  test(
    'status notifications are not actionable offers; string FCM IDs are supported',
    () {
      expect(
        DeliveryRequestIntent.fromPush({
          'type': 'ORDER_STATUS_UPDATED',
          'order_id': '100',
        }),
        isNull,
      );
      expect(
        DeliveryRequestIntent.fromPush({
          'type': 'ORDER_ASSIGNED',
          'request_id': '17',
        }),
        isNull,
      );
      expect(
        DeliveryRequestIntent.fromPush({
          'type': 'DELIVERY_ORDER_REQUEST',
          'order_id': '100',
        }),
        isNull,
      );
      final intent = DeliveryRequestIntent.fromPush({
        'type': 'DELIVERY_ORDER_REQUEST',
        'request_id': '17',
        'order_id': '100',
      });
      expect(intent!.requestId, 17);
      expect(intent.orderId, 100);
      expect(intent.action, DeliveryRequestAction.open);
    },
  );

  test('invalid backend expiry never fabricates a fresh offer', () {
    for (final expiry in [null, '', 'bad-date']) {
      final request = RiderOrderRequestModel.fromJson({
        'request_id': 17,
        'order_id': 100,
        'expires_at': expiry,
      });
      expect(request.expiresAt.isBefore(DateTime.now()), isTrue);
    }
  });
}
