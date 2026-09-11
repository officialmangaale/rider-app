import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../models/delivery_models.dart';
import 'background_mode_flags.dart';
import 'background_mode_policy.dart';
import 'background_mode_store.dart';
import 'request_alert_notifier.dart';
import 'rider_online_service.dart';
import 'rider_platform.dart';

/// Starts and stops the Online foreground service.
abstract class OnlineServiceGateway {
  Future<bool> isRunning();
  Future<void> start();
  void send(String command);
}

class PluginOnlineServiceGateway implements OnlineServiceGateway {
  final FlutterBackgroundService _service = FlutterBackgroundService();

  @override
  Future<bool> isRunning() => _service.isRunning();

  @override
  Future<void> start() async {
    await _service.startService();
  }

  @override
  void send(String command) => _service.invoke(command);
}

/// The app-side owner of Online background mode: the single place that
/// decides when the foreground service, request notifications and floating
/// bubble exist.
///
///   Online (tapped, or restored at launch) -> [startOnline]
///   Offline, sign-out, session expiry      -> [stopOnline]
///   app shown / hidden                     -> [setAppInForeground]
///
/// [stopOnline] writes the shared "not Online" flag before anything else, so
/// even if the stop command is lost the service stops itself on its next tick.
class BackgroundModeController {
  BackgroundModeController({
    required this.store,
    required this.service,
    required this.platform,
    required this.notifier,
    bool? supported,
    bool? bubbleAvailable,
  }) : supported =
           supported ??
           (riderBackgroundModeEnabled &&
               !kIsWeb &&
               defaultTargetPlatform == TargetPlatform.android),
       bubbleAvailable = bubbleAvailable ?? riderOverlayBubbleAvailable;

  final BackgroundModeStore store;
  final OnlineServiceGateway service;
  final RiderPlatform platform;
  final RequestAlertNotifier notifier;

  /// Android only for now, and only when [riderBackgroundModeEnabled]. iOS
  /// keeps the existing foreground-only behaviour.
  final bool supported;

  /// Whether the optional floating bubble is offered in this build.
  final bool bubbleAvailable;

  /// Marks the rider Online and makes sure the service is running.
  ///
  /// [locationGranted] must be true: Android 14 refuses to start a
  /// location-type foreground service without location permission, and the
  /// failed start would crash the app. Without it the rider stays Online with
  /// foreground-only tracking, exactly as before this mode existed.
  Future<void> startOnline({
    required bool hasActiveDelivery,
    required bool locationGranted,
  }) async {
    if (!supported) return;
    await store.setOnline(true);
    await store.setActiveDelivery(hasActiveDelivery);
    if (!locationGranted) {
      _debug('online without location permission; service not started');
      return;
    }
    if (await service.isRunning()) {
      service.send(onlineServiceRefreshCommand);
    } else {
      await service.start();
      _debug('rider_online_started');
    }
  }

  /// Ends background mode: service, request alerts and bubble.
  Future<void> stopOnline() async {
    if (!supported) return;
    await store.clearSessionState();
    service.send(onlineServiceStopCommand);
    await notifier.cancelAllRequests();
    await platform.hideBubble();
    _debug('rider_online_stopped');
  }

  /// Tells the service who alerts: the app while it is on screen, the
  /// service's notifications while it is not. Shows or hides the bubble.
  Future<void> setAppInForeground(
    bool inForeground, {
    required bool online,
  }) async {
    if (!supported) return;
    await store.setAppInForeground(inForeground);
    if (inForeground) {
      // The in-app card takes over; stop any notification still ringing.
      await notifier.cancelAllRequests();
      await platform.hideBubble();
    } else {
      final show = shouldShowBubble(
        online: online,
        appInForeground: false,
        bubbleEnabled: bubbleEnabled,
        canDrawOverlays: await platform.canDrawOverlays(),
      );
      if (show) {
        await platform.showBubble();
      }
    }
    if (online) {
      // Poll straight away rather than on the service's next interval.
      service.send(onlineServiceRefreshCommand);
    }
  }

  Future<void> setActiveDelivery(bool hasActiveDelivery) async {
    if (!supported) return;
    await store.setActiveDelivery(hasActiveDelivery);
  }

  /// Records an upload made by the app so the service does not repeat it.
  Future<void> recordUpload(DateTime at) async {
    if (!supported) return;
    await store.setLastUploadAt(at);
  }

  /// Offers already alerted by either the app or the service.
  Future<Set<String>> alertedOfferKeys() async {
    if (!supported) return const <String>{};
    await store.reload();
    return store.alertedOfferKeys;
  }

  Future<void> rememberAlerted(Iterable<String> offerKeys) async {
    if (!supported) return;
    await store.rememberAlerted(offerKeys);
  }

  /// Posts ringing notifications for offers that reached the app while it is
  /// not on screen, e.g. over the socket, which is faster than the service's
  /// poll.
  Future<void> notifyInBackground(List<RiderOrderRequestModel> offers) async {
    if (!supported) return;
    for (final offer in offers) {
      await notifier.showRequest(
        PolledOffer(
          requestId: offer.requestId,
          orderId: offer.orderId,
          expiresAt: offer.expiresAt,
          restaurantName: offer.restaurantName ?? '',
          distanceKm: offer.distanceKm,
          amount: offer.amount,
          // Not carried by the in-app model; the service's own poll has it.
          paymentMode: '',
        ),
      );
    }
  }

  // --- Rider-facing settings -------------------------------------------

  /// Whether the rider has accepted the background location explanation.
  /// Always true where background mode does not run.
  bool get disclosureAccepted => !supported || store.disclosureAccepted;

  Future<void> acceptDisclosure() => store.setDisclosureAccepted();

  /// Asks for notification permission (Android 13+). Without it the service
  /// still runs, but its notification and request alerts are not shown.
  Future<bool> requestNotificationPermission() async {
    if (!supported) return true;
    return notifier.requestPermission();
  }

  Future<bool> notificationsEnabled() async {
    if (!supported) return true;
    return notifier.areEnabled();
  }

  bool get bubbleEnabled => supported && bubbleAvailable && store.bubbleEnabled;

  /// Turns the optional floating bubble on or off. Turning it on never grants
  /// the overlay permission by itself: if it is missing the rider is sent to
  /// the system screen to decide, and the bubble stays hidden until granted.
  /// Returns whether the permission is currently granted.
  Future<bool> setBubbleEnabled(bool enabled) async {
    if (!supported) return false;
    await store.setBubbleEnabled(enabled);
    if (!enabled) {
      await platform.hideBubble();
      return await platform.canDrawOverlays();
    }
    final granted = await platform.canDrawOverlays();
    if (!granted) {
      await platform.openOverlaySettings();
    }
    return granted;
  }

  Future<bool> canDrawOverlays() async {
    if (!supported) return false;
    return platform.canDrawOverlays();
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!supported) return true;
    return platform.isIgnoringBatteryOptimizations();
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!supported) return;
    await platform.openBatteryOptimizationSettings();
  }

  Future<void> cancelRequestAlert(int requestId) async {
    if (!supported) return;
    await notifier.cancelRequest(requestId);
  }

  void _debug(String message) {
    assert(() {
      debugPrint('[BackgroundMode] $message');
      return true;
    }());
  }
}
