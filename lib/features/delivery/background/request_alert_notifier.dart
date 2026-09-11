import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'background_mode_policy.dart';

/// Android notifications for the Online mode: the persistent "you are Online"
/// channel used by the foreground service, and heads-up delivery requests.
///
/// Used from both the app isolate and the service isolate. Both post a
/// request under the same id ([requestNotificationId]) with onlyAlertOnce, so
/// if both happen to post the same offer Android shows and sounds it once.
class RequestAlertNotifier {
  RequestAlertNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const onlineChannelId = 'rider_online_status';
  static const requestChannelId = 'rider_delivery_requests_v1';

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

  Future<void> initialize() async {
    if (_initialized || !_isAndroid) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _android;
    if (android != null) {
      await android.createNotificationChannel(_onlineChannel);
      await android.createNotificationChannel(_requestChannel);
      await android.deleteNotificationChannel(channelId: _legacyChannelId);
    }
    _initialized = true;
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

  Future<void> showRequest(PolledOffer offer, {DateTime? now}) async {
    if (!_isAndroid) return;
    await initialize();
    final remaining = offer.expiresAt.toUtc().difference(
      (now ?? DateTime.now()).toUtc(),
    );
    if (remaining <= Duration.zero) {
      return;
    }
    await _plugin.show(
      id: requestNotificationId(offer.requestId),
      title: 'New delivery request',
      body: requestNotificationBody(offer),
      payload: 'delivery_request:${offer.requestId}',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          requestChannelId,
          _requestChannel.name,
          channelDescription: _requestChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          autoCancel: true,
          onlyAlertOnce: true,
          timeoutAfter: remaining.inMilliseconds,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          additionalFlags: Int32List.fromList(const [_flagInsistent]),
          ticker: 'New delivery request',
        ),
      ),
    );
  }

  Future<void> cancelRequest(int requestId) async {
    if (!_isAndroid) return;
    await initialize();
    await _plugin.cancel(id: requestNotificationId(requestId));
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
