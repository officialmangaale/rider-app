import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_store.dart';
import 'package:rydex_rider/features/delivery/background/rider_online_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_mode_test_fakes.dart';

/// The foreground service's own rules, with the network and platform faked.
/// Location upload is kept not-due in these tests (a recent upload is
/// recorded) so they exercise the stop and request-alert paths.
void main() {
  late DateTime now;
  late BackgroundModeStore store;
  late FakeServiceInstance instance;
  late FakeNotifier notifier;
  late List<http.Request> requests;
  late List<Map<String, Object?>> pending;

  Map<String, Object?> offerJson(int id, {int expiresInSeconds = 25}) => {
    'request_id': id,
    'order_id': 13000 + id,
    'restaurant_name': 'Fateh Cafe',
    'distance_km': 0.4,
    'amount': 250,
    'payment_mode': 'cash',
    'expires_at': now
        .add(Duration(seconds: expiresInSeconds))
        .toUtc()
        .toIso8601String(),
  };

  Future<OnlineServiceRunner> runner({bool online = true}) async {
    await store.setOnline(online);
    await store.setAppInForeground(false);
    await store.setLastUploadAt(now);
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode({'success': true, 'data': pending}), 200);
    });
    return OnlineServiceRunner(
      service: instance,
      store: store,
      notifier: notifier,
      client: client,
      clock: () => now,
    );
  }

  setUp(() async {
    now = DateTime.now();
    SharedPreferences.setMockInitialValues({'access_token': 'jwt'});
    store = BackgroundModeStore(await SharedPreferences.getInstance());
    instance = FakeServiceInstance();
    notifier = FakeNotifier();
    requests = [];
    pending = [];
  });

  group('the service respects the rider’s choice', () {
    test('stops itself when the rider is not Online', () async {
      final service = await runner(online: false);

      await service.tick();

      expect(instance.stopSelfCalls, 1);
      expect(requests, isEmpty, reason: 'no network use once Offline');
    });

    // A watchdog restart after sign-out must not resume tracking.
    test('stops itself when there is no session', () async {
      final service = await runner();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');

      await service.tick();

      expect(instance.stopSelfCalls, 1);
    });

    test('stops on the app’s stop command and silences every alert', () async {
      pending = [offerJson(1)];
      final service = await runner();
      await service.start();
      expect(notifier.showing.keys, [1]);

      instance.emit(onlineServiceStopCommand);
      await pumpEventQueue();

      expect(instance.stopSelfCalls, 1);
      expect(notifier.showing, isEmpty);
      await service.tick();
      expect(
        instance.stopSelfCalls,
        1,
        reason: 'a stopped service stays stopped',
      );
    });
  });

  group('delivery requests while the app is not on screen', () {
    test('posts one ringing notification per new offer', () async {
      pending = [offerJson(1), offerJson(2)];
      final service = await runner();

      await service.tick();

      expect(notifier.showing.keys, unorderedEquals([1, 2]));
      expect(requests.single.url.path, '/api/v1/riders/order-requests');
      expect(requests.single.headers['Authorization'], 'Bearer jwt');
    });

    test('does not ring again for an offer it already posted', () async {
      pending = [offerJson(1)];
      final service = await runner();

      await service.tick();
      now = now.add(const Duration(seconds: 11));
      await service.tick();

      expect(notifier.posts, 1);
    });

    // Rang in the app just before it left the screen: one offer, one ring.
    test('does not ring for an offer the app already alerted for', () async {
      final json = offerJson(1);
      pending = [json];
      await store.rememberAlerted([
        '1@${DateTime.parse('${json['expires_at']}').millisecondsSinceEpoch ~/ 1000}',
      ]);
      final service = await runner();

      await service.tick();

      expect(notifier.posts, 0);
    });

    test('stops ringing when the offer disappears', () async {
      pending = [offerJson(1)];
      final service = await runner();
      await service.tick();

      pending = [];
      now = now.add(const Duration(seconds: 11));
      await service.tick();

      expect(notifier.showing, isEmpty);
    });

    test('leaves alerting to the app while it is on screen', () async {
      pending = [offerJson(1)];
      final service = await runner();
      await store.setAppInForeground(true);

      await service.tick();

      expect(requests, isEmpty);
      expect(notifier.posts, 0);
    });
  });
}
