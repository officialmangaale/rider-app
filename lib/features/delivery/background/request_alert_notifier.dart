import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_mode_policy.dart';
import 'background_mode_store.dart';
import 'offer_notification_entry.dart';

/// What the system currently allows the delivery-request alerts to do.
class DeliveryAlertHealth {
  const DeliveryAlertHealth({
    required this.notificationsEnabled,
    required this.channelImportance,
  });

  /// The app's notifications are switched on (and, on Android 13+, granted).
  final bool notificationsEnabled;

  /// The importance the rider has left the request channel at, or null when it
  /// cannot be read (older Android, or the channel does not exist yet).
  final Importance? channelImportance;

  /// A heads-up popup and the ringtone need the channel at high importance or
  /// above. A rider can lower it in system settings, which silently turns the
  /// alert into an entry in the shade.
  bool get canHeadsUp =>
      notificationsEnabled &&
      (channelImportance == null ||
          channelImportance!.value >= Importance.high.value);
}

/// Android notifications for the Online mode: the persistent "you are Online"
/// channel used by the foreground service, and heads-up delivery requests.
///
/// Used from the app isolate, the service isolate and the push (background
/// message) isolate. Every one of them posts a request under the same id
/// ([requestNotificationId]) with onlyAlertOnce, so if two of them post the
/// same offer Android shows and sounds it once.
class RequestAlertNotifier {
  RequestAlertNotifier({
    FlutterLocalNotificationsPlugin? plugin,
    void Function(NotificationResponse)? onResponse,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _onResponse = onResponse;

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(NotificationResponse)? _onResponse;
  bool _initialized = false;
  Future<void>? _initializing;

  static const onlineChannelId = 'rider_online_status';
  static const requestChannelId = 'rider_delivery_requests_v1';

  /// Outcomes of an answered offer ("assigned to you", "already taken"). Quiet:
  /// the rider has just acted and does not need to be rung again.
  static const updatesChannelId = 'rider_delivery_updates';

  /// Channel created by an older build for active-delivery tracking only.
  static const _legacyChannelId = 'rider_location_channel';

  /// Android's FLAG_INSISTENT: the sound repeats until the notification is
  /// cancelled or answered. Bounded by [AndroidNotificationDetails.timeoutAfter],
  /// which is set to the offer's expiry, so it can never ring indefinitely.
  static const _flagInsistent = 4;

  static const _onlineChannel = AndroidNotificationChannel(
    onlineChannelId,
    'Online status',
    description:
        'Shown while you are Online: Mangaale Rider is receiving delivery '
        'requests and sharing your location. Go Offline to remove it.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  static const _requestChannel = AndroidNotificationChannel(
    requestChannelId,
    'Delivery requests',
    description:
        'Rings when a new delivery request arrives while you are Online.',
    importance: Importance.max,
    playSound: true,
    // The phone's ringtone, at ring volume: a delivery request should be as
    // noticeable as a call, and the rider controls it like one.
    sound: UriAndroidNotificationSound('content://settings/system/ringtone'),
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    enableVibration: true,
  );

  static const _updatesChannel = AndroidNotificationChannel(
    updatesChannelId,
    'Delivery request updates',
    description:
        'Confirms what happened to a delivery request you answered from a '
        'notification.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  Future<void> initialize() async {
    if (_initialized || !_isAndroid) {
      return;
    }
    await (_initializing ??= _initialize());
  }

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onResponse,
      // Accept and Decline do not open the app: Android runs this in a
      // background isolate, whether or not the app process is alive.
      onDidReceiveBackgroundNotificationResponse:
          offerNotificationBackgroundHandler,
    );
    final android = _android;
    if (android != null) {
      await android.createNotificationChannel(_onlineChannel);
      await android.createNotificationChannel(_requestChannel);
      await android.createNotificationChannel(_updatesChannel);
      await android.deleteNotificationChannel(channelId: _legacyChannelId);
    }
    _initialized = true;
    if (_onResponse != null) {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        _onResponse(response);
      }
    }
  }

  /// Asks for POST_NOTIFICATIONS on Android 13+. Returns true when
  /// notifications may be shown (always true below Android 13).
  Future<bool> requestPermission() async {
    if (!_isAndroid) return true;
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<bool> areEnabled() async {
    if (!_isAndroid) return true;
    return await _android?.areNotificationsEnabled() ?? true;
  }

  /// Whether alerts can actually reach the rider right now: permission granted
  /// and the request channel still at a heads-up importance.
  Future<DeliveryAlertHealth> health() async {
    if (!_isAndroid) {
      return const DeliveryAlertHealth(
        notificationsEnabled: true,
        channelImportance: null,
      );
    }
    await initialize();
    Importance? importance;
    try {
      final channels = await _android?.getNotificationChannels();
      for (final channel in channels ?? const <AndroidNotificationChannel>[]) {
        if (channel.id == requestChannelId) importance = channel.importance;
      }
    } catch (_) {
      // Unreadable on this device: report unknown rather than guess.
    }
    return DeliveryAlertHealth(
      notificationsEnabled: await areEnabled(),
      channelImportance: importance,
    );
  }

  /// Posts the heads-up offer: the order reference, restaurant, pickup, area,
  /// distance and order value, with Accept and Decline.
  ///
  /// The lock screen follows the rider's own privacy setting: the visibility is
  /// private, so a device set to hide sensitive notification content shows only
  /// that a delivery request arrived. Never public, which would override it.
  Future<void> showRequest(PolledOffer offer, {DateTime? now}) async {
    if (!_isAndroid) return;
    await initialize();
    final remaining = offer.expiresAt.toUtc().difference(
      (now ?? DateTime.now()).toUtc(),
    );
    if (remaining <= Duration.zero) {
      return;
    }
    final title = requestNotificationTitle(offer);
    await _plugin.show(
      id: requestNotificationId(offer.requestId),
      title: title,
      body: requestNotificationBody(offer),
      payload: jsonEncode({
        'type': 'DELIVERY_ORDER_REQUEST',
        'request_id': offer.requestId,
        'order_id': offer.orderId,
        'order_type': offer.orderType,
        'expires_at': offer.expiresAt.toUtc().toIso8601String(),
      }),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          requestChannelId,
          _requestChannel.name,
          channelDescription: _requestChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.private,
          autoCancel: true,
          onlyAlertOnce: true,
          timeoutAfter: remaining.inMilliseconds,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          additionalFlags: Int32List.fromList(const [_flagInsistent]),
          ticker: title,
          styleInformation: BigTextStyleInformation(
            requestNotificationDetails(offer),
            contentTitle: title,
            summaryText: 'Mangaale Rider',
          ),
          // Answered from the shade: the app is not opened. The result is
          // reported by updating this notification (see OfferActionRunner).
          // The notification is kept while the request is in flight, so a
          // failed attempt can still be retried before the offer expires.
          actions: const [
            AndroidNotificationAction(
              offerActionAccept,
              'Accept',
              cancelNotification: false,
            ),
            AndroidNotificationAction(
              offerActionDecline,
              'Decline',
              cancelNotification: false,
            ),
          ],
        ),
      ),
    );
    try {
      await BackgroundModeStore(
        await SharedPreferences.getInstance(),
      ).rememberOfferOrder(offer.requestId, offer.orderId);
    } catch (_) {
      // Only needed to withdraw this alert when another rider takes the order.
    }
  }

  /// Replaces the offer's notification with a quiet message about what became
  /// of it. Disappears by itself after [visibleFor].
  Future<void> showOutcome({
    required int requestId,
    required String title,
    required String body,
    String? payload,
    Duration visibleFor = const Duration(seconds: 20),
    bool inProgress = false,
  }) async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.show(
      id: requestNotificationId(requestId),
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          updatesChannelId,
          _updatesChannel.name,
          channelDescription: _updatesChannel.description,
          importance: Importance.low,
          priority: Priority.low,
          visibility: NotificationVisibility.private,
          autoCancel: true,
          onlyAlertOnce: true,
          showProgress: inProgress,
          indeterminate: inProgress,
          ongoing: inProgress,
          timeoutAfter: visibleFor.inMilliseconds,
        ),
      ),
    );
  }

  Future<void> cancelRequest(int requestId) async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.cancel(id: requestNotificationId(requestId));
  }

  /// Withdraws every offer notification for [orderId]: the offer was taken by
  /// another rider, or the order was cancelled.
  Future<void> cancelOffersForOrder(int orderId) async {
    if (!_isAndroid) return;
    await initialize();
    final store = BackgroundModeStore(await SharedPreferences.getInstance());
    await store.reload();
    for (final requestId in store.requestIdsForOrder(orderId)) {
      await _plugin.cancel(id: requestNotificationId(requestId));
    }
  }

  /// Removes every delivery-request notification, whichever isolate posted
  /// it. The foreground-service notification is on another channel and is
  /// left alone.
  Future<void> cancelAllRequests() async {
    if (!_isAndroid) return;
    await initialize();
    final active = await _plugin.getActiveNotifications();
    for (final notification in active) {
      final id = notification.id;
      if (id != null && notification.channelId == requestChannelId) {
        await _plugin.cancel(id: id);
      }
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
