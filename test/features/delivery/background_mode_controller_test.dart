import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_controller.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_policy.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_store.dart';
import 'package:rydex_rider/features/delivery/background/rider_online_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_mode_test_fakes.dart';

void main() {
  late BackgroundModeStore store;
  late FakeServiceGateway service;
  late FakeRiderPlatform platform;
  late FakeNotifier notifier;
  late BackgroundModeController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'access_token': 'jwt'});
    store = BackgroundModeStore(await SharedPreferences.getInstance());
    service = FakeServiceGateway();
    platform = FakeRiderPlatform();
    notifier = FakeNotifier();
    controller = BackgroundModeController(
      store: store,
      service: service,
      platform: platform,
      notifier: notifier,
      supported: true,
    );
  });

  PolledOffer offer(int id) => PolledOffer(
    requestId: id,
    orderId: id,
    expiresAt: DateTime.now().add(const Duration(seconds: 25)),
    restaurantName: 'Fateh Cafe',
    distanceKm: 1,
    amount: 250,
    paymentMode: 'cash',
  );

  group('going Online', () {
    test('starts the foreground service and marks the rider Online', () async {
      await controller.startOnline(
        hasActiveDelivery: false,
        locationGranted: true,
      );

      expect(service.starts, 1);
      expect(store.online, isTrue);
    });

    test(
      'an already-running service is refreshed, not started twice',
      () async {
        service.running = true;
        await controller.startOnline(
          hasActiveDelivery: true,
          locationGranted: true,
        );

        expect(service.starts, 0);
        expect(service.sent, [onlineServiceRefreshCommand]);
        expect(store.hasActiveDelivery, isTrue);
      },
    );

    // Android 14 rejects a location foreground service without permission,
    // and the failed start would crash the app.
    test('never starts the service without location permission', () async {
      await controller.startOnline(
        hasActiveDelivery: false,
        locationGranted: false,
      );

      expect(service.starts, 0);
    });

    test('does nothing where background mode is not supported', () async {
      final ios = BackgroundModeController(
        store: store,
        service: service,
        platform: platform,
        notifier: notifier,
        supported: false,
      );
      await ios.startOnline(hasActiveDelivery: false, locationGranted: true);

      expect(service.starts, 0);
      expect(store.online, isFalse);
    });
  });

  group('going Offline or signing out', () {
    test('stops the service, the ringing alerts and the bubble', () async {
      await controller.startOnline(
        hasActiveDelivery: false,
        locationGranted: true,
      );
      platform.bubbleVisible = true;
      await notifier.showRequest(offer(1));

      await controller.stopOnline();

      expect(service.sent, contains(onlineServiceStopCommand));
      expect(notifier.showing, isEmpty);
      expect(platform.bubbleVisible, isFalse);
    });

    // The flag is the service's licence to run. Even if the stop command is
    // lost, the service stops itself on its next tick.
    test('clears the shared Online flag the service checks', () async {
      await controller.startOnline(
        hasActiveDelivery: true,
        locationGranted: true,
      );
      await store.rememberAlerted(['1@1']);

      await controller.stopOnline();

      expect(store.online, isFalse);
      expect(store.hasActiveDelivery, isFalse);
      expect(store.alertedOfferKeys, isEmpty);
    });

    test('keeps the rider’s own settings', () async {
      await store.setBubbleEnabled(true);
      await store.setDisclosureAccepted();

      await controller.stopOnline();

      expect(store.bubbleEnabled, isTrue);
      expect(store.disclosureAccepted, isTrue);
    });
  });

  group('app shown and hidden', () {
    test(
      'returning to the app stops notification rings and hides the bubble',
      () async {
        platform.bubbleVisible = true;
        await notifier.showRequest(offer(1));

        await controller.setAppInForeground(true, online: true);

        expect(store.appInForeground, isTrue);
        expect(notifier.showing, isEmpty);
        expect(platform.bubbleVisible, isFalse);
      },
    );

    test(
      'leaving the app shows the bubble only when opted in and permitted',
      () async {
        await controller.setAppInForeground(false, online: true);
        expect(platform.bubbleVisible, isFalse, reason: 'off by default');

        await store.setBubbleEnabled(true);
        await controller.setAppInForeground(false, online: true);
        expect(
          platform.bubbleVisible,
          isFalse,
          reason: 'no overlay permission',
        );

        platform.overlayGranted = true;
        await controller.setAppInForeground(false, online: true);
        expect(platform.bubbleVisible, isTrue);
      },
    );

    test('a build with the bubble switched off never shows it', () async {
      final noBubble = BackgroundModeController(
        store: store,
        service: service,
        platform: platform,
        notifier: notifier,
        supported: true,
        bubbleAvailable: false,
      );
      await store.setBubbleEnabled(true);
      platform.overlayGranted = true;

      await noBubble.setAppInForeground(false, online: true);

      expect(platform.bubbleVisible, isFalse);
    });

    test('never shows the bubble while Offline', () async {
      await store.setBubbleEnabled(true);
      platform.overlayGranted = true;

      await controller.setAppInForeground(false, online: false);

      expect(platform.bubbleVisible, isFalse);
    });

    test(
      'asks the service to poll straight away when the app is hidden',
      () async {
        await controller.setAppInForeground(false, online: true);

        expect(store.appInForeground, isFalse);
        expect(service.sent, [onlineServiceRefreshCommand]);
      },
    );
  });

  group('floating bubble setting', () {
    test(
      'turning it on without permission sends the rider to the system screen',
      () async {
        final granted = await controller.setBubbleEnabled(true);

        expect(granted, isFalse);
        expect(platform.overlaySettingsOpened, 1);
        expect(store.bubbleEnabled, isTrue);
      },
    );

    test('turning it off hides it immediately', () async {
      platform.bubbleVisible = true;

      await controller.setBubbleEnabled(false);

      expect(platform.bubbleVisible, isFalse);
      expect(store.bubbleEnabled, isFalse);
    });
  });
}
