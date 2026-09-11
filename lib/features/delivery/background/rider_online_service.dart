import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import 'background_mode_flags.dart';
import 'background_mode_policy.dart';
import 'background_mode_store.dart';
import 'request_alert_notifier.dart';

/// The Android foreground service that keeps an Online rider reachable while
/// the app is minimised, behind another app, swiped away, or the screen is
/// locked.
///
/// It runs only between the rider tapping Online and tapping Offline or
/// signing out, always with the persistent "Mangaale Rider is Online"
/// notification. Its responsibilities:
///
///  * upload a location fix when the app has not uploaded one recently
///    (see [isLocationUploadDue]) — so dispatch keeps seeing the rider;
///  * while the app is not on screen, poll for delivery offers and post a
///    ringing heads-up notification for each new one, cancelling it when the
///    offer is gone.
///
/// It never refreshes the access token itself: token rotation from two
/// isolates at once would race, and a lost race signs the rider out. The app
/// refreshes tokens through its own API client; the service re-reads them.
const onlineServiceNotificationId = 888;

/// Commands the app sends the service.
const onlineServiceStopCommand = 'stopService';
const onlineServiceRefreshCommand = 'refresh';

/// Registers the service with the plugin. Called once from main(); starts
/// nothing. The service is started only by [BackgroundModeController] when the
/// rider goes Online.
Future<void> configureRiderOnlineService() async {
  if (!riderBackgroundModeEnabled ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  // Channels must exist before the service posts its first notification.
  await RequestAlertNotifier().initialize();

  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onRiderOnlineServiceStart,
      autoStart: false,
      // Never resume after a reboot: the rider chooses to be Online each shift.
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: RequestAlertNotifier.onlineChannelId,
      initialNotificationTitle: 'Mangaale Rider is Online',
      initialNotificationContent:
          'Receiving delivery requests and sharing location. '
          'Go Offline in the app to stop.',
      foregroundServiceNotificationId: onlineServiceNotificationId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

@pragma('vm:entry-point')
Future<void> onRiderOnlineServiceStart(ServiceInstance service) async {
  // The plugin's entrypoint has already initialised the binding; this
  // registers the other plugins (geolocator, notifications, preferences) in
  // this isolate.
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final runner = OnlineServiceRunner(
    service: service,
    store: BackgroundModeStore(prefs),
    notifier: RequestAlertNotifier(),
    client: http.Client(),
  );
  await runner.start();
}

/// What the persistent notification currently says. Updated only on change,
/// because Android rate-limits notification updates.
enum OnlineServiceStatus { sharing, locationOff, gpsOff, sessionExpired }

class OnlineServiceRunner {
  OnlineServiceRunner({
    required this.service,
    required this.store,
    required this.notifier,
    required this.client,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ServiceInstance service;
  final BackgroundModeStore store;
  final RequestAlertNotifier notifier;
  final http.Client client;
  final DateTime Function() _clock;

  Timer? _timer;
  bool _tickInFlight = false;
  bool _stopping = false;
  DateTime? _lastAttemptAt;
  DateTime? _lastPollAt;
  OnlineServiceStatus? _status;
  final Set<int> _postedRequestIds = <int>{};
  final List<StreamSubscription<Map<String, dynamic>?>> _subscriptions = [];

  Future<void> start() async {
    await notifier.initialize();
    _subscriptions
      ..add(
        service
            .on(onlineServiceStopCommand)
            .listen((_) => unawaited(stop(reason: 'rider_offline'))),
      )
      ..add(
        service
            .on(onlineServiceRefreshCommand)
            .listen((_) => unawaited(tick())),
      );
    _timer = Timer.periodic(serviceTickInterval, (_) => unawaited(tick()));
    _log('rider_background_service_started');
    await tick();
  }

  Future<void> tick() async {
    if (_stopping || _tickInFlight) {
      return;
    }
    _tickInFlight = true;
    try {
      await store.reload();
      final token = store.accessToken;
      if (!mayRunOnlineService(online: store.online, accessToken: token)) {
        await stop(reason: 'not_online_or_signed_out');
        return;
      }
      final now = _clock();
      if (isLocationUploadDue(
        now: now,
        lastUploadAt: store.lastUploadAt,
        lastAttemptAt: _lastAttemptAt,
        hasActiveDelivery: store.hasActiveDelivery,
      )) {
        await _uploadLocation(token!, now);
      }
      if (isRequestPollDue(
        now: now,
        lastPollAt: _lastPollAt,
        appInForeground: store.appInForeground,
      )) {
        await _pollRequests(token!, now);
      }
    } catch (error) {
      // One bad tick must not end the service; the next tick retries.
      _log('tick_failed error=${error.runtimeType}');
    } finally {
      _tickInFlight = false;
    }
  }

  Future<void> stop({required String reason}) async {
    if (_stopping) return;
    _stopping = true;
    _timer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    // Offline means no more ringing, including an offer mid-ring.
    for (final requestId in _postedRequestIds) {
      await notifier.cancelRequest(requestId);
    }
    _postedRequestIds.clear();
    client.close();
    _log('rider_background_service_stopped reason=$reason');
    await service.stopSelf();
  }

  Future<void> _uploadLocation(String token, DateTime now) async {
    _lastAttemptAt = now;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await _setStatus(OnlineServiceStatus.locationOff);
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      await _setStatus(OnlineServiceStatus.gpsOff);
      return;
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          // Balanced accuracy while idle; GPS-grade while carrying an order.
          accuracy: store.hasActiveDelivery
              ? LocationAccuracy.high
              : LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      _log('location_fix_timeout');
      return;
    }

    final body = buildLocationPayload(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      heading: position.heading,
      speed: position.speed,
      recordedAt: position.timestamp,
      appInForeground: store.appInForeground,
      sequence: await store.nextSequence(),
    );

    final response = await client
        .post(
          Uri.parse('${AppConstants.apiBaseUrl}/api/v1/location/update'),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await store.setLastUploadAt(_clock());
      await _setStatus(OnlineServiceStatus.sharing);
      _log('rider_location_background_update_sent');
    } else if (response.statusCode == 401) {
      await _setStatus(OnlineServiceStatus.sessionExpired);
    } else {
      _log('location_upload_failed status=${response.statusCode}');
    }
  }

  Future<void> _pollRequests(String token, DateTime now) async {
    _lastPollAt = now;
    final response = await client
        .get(
          Uri.parse('${AppConstants.apiBaseUrl}/api/v1/riders/order-requests'),
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 10));

    final List<PolledOffer> offers;
    if (response.statusCode == 404) {
      offers = const [];
    } else if (response.statusCode == 401) {
      await _setStatus(OnlineServiceStatus.sessionExpired);
      return;
    } else if (response.statusCode < 200 || response.statusCode >= 300) {
      _log('request_poll_failed status=${response.statusCode}');
      return;
    } else {
      offers = parsePendingOffers(jsonDecode(response.body));
    }

    // The app may have alerted for some of these just before it left the
    // screen; the shared list stops them ringing a second time.
    await store.reload();
    final plan = planOfferAlerts(
      live: offers,
      alertedOfferKeys: store.alertedOfferKeys,
      postedRequestIds: _postedRequestIds,
      now: _clock(),
    );
    for (final requestId in plan.toCancel) {
      await notifier.cancelRequest(requestId);
      _postedRequestIds.remove(requestId);
    }
    if (plan.toPost.isEmpty) {
      return;
    }
    await store.rememberAlerted(plan.toPost.map((offer) => offer.offerKey));
    for (final offer in plan.toPost) {
      await notifier.showRequest(offer, now: _clock());
      _postedRequestIds.add(offer.requestId);
    }
    _log('rider_live_request_notified count=${plan.toPost.length}');
  }

  Future<void> _setStatus(OnlineServiceStatus status) async {
    if (_status == status) return;
    _status = status;
    final instance = service;
    if (instance is! AndroidServiceInstance) return;
    final (title, content) = switch (status) {
      OnlineServiceStatus.sharing => (
        'Mangaale Rider is Online',
        'Receiving delivery requests and sharing location. Go Offline in the app to stop.',
      ),
      OnlineServiceStatus.locationOff => (
        'Mangaale Rider is Online — location is off',
        'Allow location for Mangaale Rider so delivery requests can reach you.',
      ),
      OnlineServiceStatus.gpsOff => (
        'Mangaale Rider is Online — GPS is off',
        'Turn on location services so delivery requests can reach you.',
      ),
      OnlineServiceStatus.sessionExpired => (
        'Mangaale Rider needs you to sign in',
        'Open the app to reconnect. You will not receive requests until then.',
      ),
    };
    await instance.setForegroundNotificationInfo(
      title: title,
      content: content,
    );
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // Debug builds only; never the token, coordinates or any offer content.
  void _log(String event) {
    assert(() {
      debugPrint('[RiderOnlineService] $event');
      return true;
    }());
  }
}
