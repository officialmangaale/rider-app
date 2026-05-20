import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/delivery/providers/rider_delivery_provider.dart';
import '../../presentation/providers/app_providers.dart';

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(ref);
});

class FcmService {
  FcmService(this._ref);
  final Ref _ref;

  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    final token = await messaging.getToken();
    if (token != null) {
      await _syncToken(token);
    }

    messaging.onTokenRefresh.listen(_syncToken);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Background notifications will be handled by the OS.
      // When a foreground message is received (like an incoming order), immediately refresh the active orders!
      unawaited(_ref.read(ordersControllerProvider.notifier).refresh());
      unawaited(
        _ref
            .read(riderDeliveryControllerProvider.notifier)
            .refreshPendingRequests(),
      );
      unawaited(
        _ref.read(riderDeliveryControllerProvider.notifier).refreshActiveOrder(),
      );
    });
  }

  Future<void> _syncToken(String token) async {
    try {
      final api = _ref.read(riderBackendApiProvider);
      final platform = Platform.isIOS ? 'ios' : 'android';
      await api.notifications.registerDeviceToken(
        platform: platform,
        pushToken: token,
      );
    } catch (error) {
      assert(() {
        debugPrint('[FCM] device token sync failed error=$error');
        return true;
      }());
    }
  }
}
