import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 11, 6, 30);

  PolledOffer offer(
    int id, {
    Duration expiresIn = const Duration(seconds: 25),
  }) {
    return PolledOffer(
      requestId: id,
      orderId: 13000 + id,
      expiresAt: now.add(expiresIn),
      restaurantName: 'Fateh Cafe',
      distanceKm: 1.24,
      amount: 250,
      paymentMode: 'cash',
    );
  }

  group('mayRunOnlineService', () {
    test('runs only for a signed-in rider who is Online', () {
      expect(mayRunOnlineService(online: true, accessToken: 'jwt'), isTrue);
    });

    // The product rule: being logged in is not consent to be tracked.
    test('never runs for a rider who is Offline, even when signed in', () {
      expect(mayRunOnlineService(online: false, accessToken: 'jwt'), isFalse);
    });

    test('never runs after sign-out, even if Online was left set', () {
      expect(mayRunOnlineService(online: true, accessToken: null), isFalse);
      expect(mayRunOnlineService(online: true, accessToken: '  '), isFalse);
    });
  });

  group('isLocationUploadDue', () {
    test('uploads at once when nothing has been uploaded', () {
      expect(
        isLocationUploadDue(
          now: now,
          lastUploadAt: null,
          lastAttemptAt: null,
          hasActiveDelivery: false,
        ),
        isTrue,
      );
    });

    // The app uploads while it is on screen; the service must not duplicate.
    test('stays quiet while the app has uploaded recently', () {
      expect(
        isLocationUploadDue(
          now: now,
          lastUploadAt: now.subtract(const Duration(seconds: 20)),
          lastAttemptAt: null,
          hasActiveDelivery: false,
        ),
        isFalse,
      );
    });

    test('idle: uploads every 45 seconds, well inside the 5-minute window', () {
      expect(
        idleUploadInterval,
        lessThanOrEqualTo(const Duration(seconds: 60)),
      );
      expect(
        isLocationUploadDue(
          now: now,
          lastUploadAt: now.subtract(idleUploadInterval),
          lastAttemptAt: null,
          hasActiveDelivery: false,
        ),
        isTrue,
      );
    });

    test('carrying an order: uploads every 15 seconds', () {
      expect(
        isLocationUploadDue(
          now: now,
          lastUploadAt: now.subtract(const Duration(seconds: 16)),
          lastAttemptAt: null,
          hasActiveDelivery: true,
        ),
        isTrue,
      );
      expect(
        isLocationUploadDue(
          now: now,
          lastUploadAt: now.subtract(const Duration(seconds: 16)),
          lastAttemptAt: null,
          hasActiveDelivery: false,
        ),
        isFalse,
      );
    });

    // No queue: a failed upload is retried with a fresh fix, but not on
    // every 5-second tick.
    test('backs off after a failed attempt', () {
      expect(
        isLocationUploadDue(
          now: now,
          lastUploadAt: null,
          lastAttemptAt: now.subtract(const Duration(seconds: 5)),
          hasActiveDelivery: false,
        ),
        isFalse,
      );
      expect(
        isLocationUploadDue(
          now: now,
          lastUploadAt: null,
          lastAttemptAt: now.subtract(uploadRetryInterval),
          hasActiveDelivery: false,
        ),
        isTrue,
      );
    });

    test('a clock that moved backwards does not freeze uploads', () {
      expect(
        isLocationUploadDue(
          now: now,
          lastUploadAt: now.add(const Duration(hours: 1)),
          lastAttemptAt: null,
          hasActiveDelivery: false,
        ),
        isTrue,
      );
    });
  });

  group('isRequestPollDue', () {
    test('never polls while the app is on screen and alerting itself', () {
      expect(
        isRequestPollDue(now: now, lastPollAt: null, appInForeground: true),
        isFalse,
      );
    });

    test('polls every 10 seconds while the app is not on screen', () {
      expect(
        isRequestPollDue(now: now, lastPollAt: null, appInForeground: false),
        isTrue,
      );
      expect(
        isRequestPollDue(
          now: now,
          lastPollAt: now.subtract(const Duration(seconds: 4)),
          appInForeground: false,
        ),
        isFalse,
      );
      expect(
        isRequestPollDue(
          now: now,
          lastPollAt: now.subtract(backgroundRequestPollInterval),
          appInForeground: false,
        ),
        isTrue,
      );
    });
  });

  group('shouldShowBubble', () {
    test(
      'shows only when Online, opted in, permitted, and the app is hidden',
      () {
        expect(
          shouldShowBubble(
            online: true,
            appInForeground: false,
            bubbleEnabled: true,
            canDrawOverlays: true,
          ),
          isTrue,
        );
      },
    );

    test('each condition alone hides it', () {
      const base = (true, false, true, true);
      final cases = <String, (bool, bool, bool, bool)>{
        'offline': (false, base.$2, base.$3, base.$4),
        'app on screen': (base.$1, true, base.$3, base.$4),
        'not opted in (the default)': (base.$1, base.$2, false, base.$4),
        'permission missing or revoked': (base.$1, base.$2, base.$3, false),
      };
      cases.forEach((reason, c) {
        expect(
          shouldShowBubble(
            online: c.$1,
            appInForeground: c.$2,
            bubbleEnabled: c.$3,
            canDrawOverlays: c.$4,
          ),
          isFalse,
          reason: reason,
        );
      });
    });
  });

  group('planOfferAlerts', () {
    test('posts a live offer nobody has alerted for', () {
      final plan = planOfferAlerts(
        live: [offer(1)],
        alertedOfferKeys: const {},
        postedRequestIds: const {},
        now: now,
      );
      expect(plan.toPost.map((o) => o.requestId), [1]);
      expect(plan.toCancel, isEmpty);
    });

    // The app rang for it just before leaving the screen: one offer, one ring.
    test('does not re-post an offer already alerted by the app', () {
      final plan = planOfferAlerts(
        live: [offer(1)],
        alertedOfferKeys: {offer(1).offerKey},
        postedRequestIds: const {},
        now: now,
      );
      expect(plan.toPost, isEmpty);
    });

    // Accepted, declined, taken by another rider, or expired: stop ringing.
    test('cancels a posted offer that is no longer live', () {
      final plan = planOfferAlerts(
        live: [offer(2)],
        alertedOfferKeys: {offer(1).offerKey},
        postedRequestIds: {1},
        now: now,
      );
      expect(plan.toCancel, {1});
      expect(plan.toPost.map((o) => o.requestId), [2]);
    });

    test('never posts an offer that has already expired', () {
      final plan = planOfferAlerts(
        live: [offer(3, expiresIn: const Duration(seconds: -1))],
        alertedOfferKeys: const {},
        postedRequestIds: {3},
        now: now,
      );
      expect(plan.toPost, isEmpty);
      expect(plan.toCancel, {3}, reason: 'its notification must stop');
    });
  });

  test('the shared alerted list is bounded and keeps the newest keys', () {
    final existing = List.generate(maxAlertedOfferKeys, (i) => 'old-$i');
    final merged = rememberAlertedOfferKeys(existing, ['new-1', 'new-2']);
    expect(merged.length, maxAlertedOfferKeys);
    expect(merged.last, 'new-2');
    expect(merged, isNot(contains('old-0')));
  });

  test(
    'request notification ids never collide with the service notification',
    () {
      expect(requestNotificationId(888), isNot(888));
      expect(
        requestNotificationId(1),
        greaterThanOrEqualTo(requestNotificationIdBase),
      );
      expect(requestNotificationId(2147000000), lessThan(2147483647));
    },
  );

  group('parsePendingOffers', () {
    test('reads the rider-service envelope', () {
      final offers = parsePendingOffers({
        'success': true,
        'data': [
          {
            'request_id': 901,
            'order_id': 13286,
            'restaurant_name': 'Fateh Cafe',
            'distance_km': 0.4,
            'amount': 250,
            'payment_mode': 'cash',
            'expires_at': '2026-09-11T06:30:25Z',
            'drop_address': 'must not be carried',
          },
        ],
      });
      expect(offers.single.requestId, 901);
      expect(offers.single.expiresAt, DateTime.utc(2026, 9, 11, 6, 30, 25));
    });

    test('skips malformed items instead of failing the poll', () {
      final offers = parsePendingOffers([
        {'request_id': 'x', 'expires_at': '2026-09-11T06:30:25Z'},
        {'request_id': 5},
        'garbage',
        {'request_id': 6, 'expires_at': '2026-09-11T06:30:25Z'},
      ]);
      expect(offers.map((o) => o.requestId), [6]);
    });
  });

  // The notification can show on the lock screen before the rider has
  // accepted, so it carries no customer details.
  test('notification text is restaurant, distance and amount only', () {
    final body = requestNotificationBody(offer(1));
    expect(body, contains('Fateh Cafe'));
    expect(body, contains('1.2 km'));
    expect(body, contains('Rs 250'));
  });

  group('buildLocationPayload', () {
    test('matches the backend contract', () {
      final payload = buildLocationPayload(
        latitude: 28.4595,
        longitude: 77.0266,
        accuracyMeters: 20,
        heading: 120,
        speed: 4.3,
        recordedAt: DateTime.utc(2026, 9, 11, 6, 30),
        appInForeground: false,
        sequence: 1042,
      );
      expect(payload, {
        'latitude': 28.4595,
        'longitude': 77.0266,
        'accuracy_meters': 20.0,
        'heading': 120.0,
        'speed': 4.3,
        'recorded_at': '2026-09-11T06:30:00.000Z',
        'source': 'foreground_service',
        'app_state': 'background',
        'sequence': 1042,
      });
    });

    test('drops values the platform reports as unknown', () {
      final payload = buildLocationPayload(
        latitude: 1,
        longitude: 2,
        accuracyMeters: double.nan,
        heading: -1,
        speed: -1,
        recordedAt: now,
        appInForeground: true,
        sequence: 1,
      );
      expect(payload.containsKey('accuracy_meters'), isFalse);
      expect(payload.containsKey('heading'), isFalse);
      expect(payload.containsKey('speed'), isFalse);
      expect(payload['app_state'], 'foreground');
    });
  });
}
