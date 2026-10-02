import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/delivery/background/background_mode_policy.dart';
import '../../features/delivery/providers/rider_delivery_provider.dart';
import '../../features/delivery/providers/request_notification_provider.dart';
import '../../features/delivery/models/delivery_request_intent.dart';
import '../../presentation/providers/app_providers.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(ref);
  ref.onDispose(service.dispose);
  return service;
});

class FcmService {
  FcmService(this._ref);
  final Ref _ref;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _listening = false;
  String? _registeredToken;

  /// Waits between attempts to tell the backend about a token. Only the first
  /// failure is retried quickly: a phone with no signal at launch registers as
  /// soon as it has some, instead of waiting for the next app start.
  static const _registrationRetryDelays = [
    Duration(seconds: 3),
    Duration(seconds: 15),
    Duration(seconds: 60),
  ];

  /// Starts listening (once per process) and registers this device's push token
  /// for the signed-in rider (on every call). Called whenever a session begins,
  /// so a second rider signing in on the same phone is registered too.
  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;
    if (!_listening) {
      _listening = true;
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          // Background messages are handled by the OS or the background
          // isolate. A foreground message (an incoming order) refreshes the
          // lists; the presenter shows the offer sheet from the pending list.
          final closedOrderId = closedOfferOrderId(message.data);
          if (closedOrderId != null) {
            // Another rider took it: drop any alert this device still shows.
            unawaited(
              _ref
                  .read(requestAlertNotifierProvider)
                  .cancelOffersForOrder(closedOrderId),
            );
          }
          unawaited(_ref.read(ordersControllerProvider.notifier).refresh());
          _refreshDelivery();
        }),
      );
      _subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen(_opened));
      _subscriptions.add(messaging.onTokenRefresh.listen(_syncToken));
      try {
        final initial = await messaging.getInitialMessage();
        if (initial != null) _opened(initial);
      } catch (error) {
        debugPrint(
          '[FCM] initial message unavailable: ${error.runtimeType}',
        );
      }
    }
    await _registerCurrentToken(messaging);
  }

  Future<void> _registerCurrentToken(FirebaseMessaging messaging) async {
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await messaging.getToken();
        if (token != null) await _syncToken(token);
      }
    } catch (error) {
      debugPrint(
        '[FCM] notification initialization failed: ${error.runtimeType}',
      );
    }
  }

  void _opened(RemoteMessage message) {
    final intent = DeliveryRequestIntent.fromPush(message.data);
    if (intent != null) {
      _ref.read(deliveryRequestIntentProvider.notifier).state = intent;
    }
    _refreshDelivery();
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }

  void _refreshDelivery() {
    final delivery = _ref.read(riderDeliveryControllerProvider.notifier);
    unawaited(delivery.refreshActiveOrder());
    unawaited(delivery.refreshPendingRequests());
  }

  /// Tells the backend about [token], retrying while the network is down. Safe
  /// to repeat: the endpoint refreshes an existing registration.
  Future<void> _syncToken(String token) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final api = _ref.read(riderBackendApiProvider);
        final platform = Platform.isIOS ? 'ios' : 'android';
        await api.notifications.registerDeviceToken(
          platform: platform,
          pushToken: token,
        );
        _registeredToken = token;
        return;
      } catch (error) {
        assert(() {
          debugPrint('[FCM] device token sync failed error=$error');
          return true;
        }());
        if (attempt >= _registrationRetryDelays.length) return;
        await Future<void>.delayed(_registrationRetryDelays[attempt]);
      }
    }
  }

  /// Ends push for this session: forgets the token on the backend and asks FCM
  /// for a new one on the next start, and removes any delivery-request
  /// notification still on screen. Call it while the access token is still
  /// valid, so the phone stops receiving this rider's offers the moment they
  /// sign out. Never throws: sign-out must not be blocked by it.
  Future<void> unregister() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = _registeredToken ?? await messaging.getToken();
      if (token != null) {
        try {
          await _ref
              .read(riderBackendApiProvider)
              .notifications
              .unregisterDeviceToken(pushToken: token);
        } catch (_) {
          // The token stays on the backend until the next rider on this phone
          // registers it, which moves it (see RegisterDeviceToken).
        }
      }
      _registeredToken = null;
      await messaging.deleteToken();
    } catch (_) {}
    try {
      await _ref.read(requestAlertNotifierProvider).cancelAllRequests();
    } catch (_) {}
  }
}
