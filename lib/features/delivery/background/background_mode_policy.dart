/// Rules for the rider's Online background mode.
///
/// Background mode runs only while a signed-in rider has chosen to be Online.
/// It keeps the rider's location fresh for dispatch (which ignores riders
/// whose last fix is older than 5 minutes) and surfaces delivery requests
/// while the app is not on screen.
///
/// Everything here is a pure function so the rules can be tested without a
/// device, a foreground service, or a second isolate. The service
/// (rider_online_service.dart) and the in-app controller
/// (background_mode_controller.dart) only carry them out.
library;

import '../services/incoming_alert_policy.dart';

/// Upload cadence while Online with no delivery. Six fixes inside the
/// 5-minute dispatch window, so one lost upload never makes a rider stale.
const idleUploadInterval = Duration(seconds: 45);

/// Upload cadence while carrying an order, so the customer map moves.
const activeDeliveryUploadInterval = Duration(seconds: 15);

/// After a failed upload, wait this long before trying again rather than
/// taking a GPS fix on every tick.
const uploadRetryInterval = Duration(seconds: 15);

/// How often the service checks for offers while the app is not on screen.
/// Offers last 30 seconds, so a rider always has at least 20 to respond.
const backgroundRequestPollInterval = Duration(seconds: 10);

/// The service's wake-up period. Each tick is cheap: it re-reads shared
/// preferences and does work only when one of the intervals above is due.
const serviceTickInterval = Duration(seconds: 5);

/// Offer keys remembered across the app and the service so one offer rings
/// once. Offers expire in seconds, so a short list is plenty.
const maxAlertedOfferKeys = 100;

/// Notification ids for delivery requests are offset so they can never
/// collide with the foreground-service notification or other app ids.
const requestNotificationIdBase = 1000000;

/// Whether the Online service may keep running.
///
/// Checked on every tick, not only at start: the service can be restarted by
/// Android's watchdog after a crash or low-memory kill, and must then stop
/// itself if the rider has since gone Offline or signed out. There is no path
/// that tracks a rider who is not Online.
bool mayRunOnlineService({required bool online, required String? accessToken}) {
  return online && (accessToken?.trim().isNotEmpty ?? false);
}

/// Whether the service should take a fix and upload it now.
///
/// [lastUploadAt] is the last successful upload by either the app or the
/// service, so the service stays quiet while the app is on screen and
/// already uploading, and takes over within one interval once it is not.
bool isLocationUploadDue({
  required DateTime now,
  required DateTime? lastUploadAt,
  required DateTime? lastAttemptAt,
  required bool hasActiveDelivery,
}) {
  if (lastAttemptAt != null) {
    final sinceAttempt = now.difference(lastAttemptAt);
    if (!sinceAttempt.isNegative && sinceAttempt < uploadRetryInterval) {
      return false;
    }
  }
  if (lastUploadAt == null) {
    return true;
  }
  final elapsed = now.difference(lastUploadAt);
  // A clock that moved backwards must not freeze uploads.
  if (elapsed.isNegative) {
    return true;
  }
  final interval = hasActiveDelivery
      ? activeDeliveryUploadInterval
      : idleUploadInterval;
  return elapsed >= interval;
}

/// Whether the service should poll for offers now. While the app is on
/// screen it has its own socket and polling, and alerts in-app.
bool isRequestPollDue({
  required DateTime now,
  required DateTime? lastPollAt,
  required bool appInForeground,
}) {
  if (appInForeground) {
    return false;
  }
  if (lastPollAt == null) {
    return true;
  }
  final elapsed = now.difference(lastPollAt);
  return elapsed.isNegative || elapsed >= backgroundRequestPollInterval;
}

/// Whether the floating rider bubble should be on screen. It is an optional
/// shortcut back into the app: never shown unless the rider opted in and
/// granted the overlay permission, never while the app itself is visible,
/// and never while Offline.
bool shouldShowBubble({
  required bool online,
  required bool appInForeground,
  required bool bubbleEnabled,
  required bool canDrawOverlays,
}) {
  return online && !appInForeground && bubbleEnabled && canDrawOverlays;
}

int requestNotificationId(int requestId) {
  return requestNotificationIdBase + (requestId % 1000000000);
}

/// The subset of an offer the service needs to alert. It deliberately has no
/// drop address, customer name or phone: the notification can appear on the
/// lock screen before the rider has accepted anything.
class PolledOffer {
  const PolledOffer({
    required this.requestId,
    required this.orderId,
    required this.expiresAt,
    required this.restaurantName,
    required this.distanceKm,
    required this.amount,
    required this.paymentMode,
  });

  final int requestId;
  final int orderId;
  final DateTime expiresAt;
  final String restaurantName;
  final double? distanceKm;
  final double? amount;
  final String paymentMode;

  String get offerKey =>
      requestOfferKey(requestId: requestId, expiresAt: expiresAt);

  bool isLiveAt(DateTime now) => expiresAt.toUtc().isAfter(now.toUtc());
}

/// Parses GET /api/v1/riders/order-requests. Tolerates the envelope shapes
/// the app's API client already accepts, and skips malformed items rather
/// than failing the whole poll.
List<PolledOffer> parsePendingOffers(Object? body) {
  final items = _extractList(body);
  final offers = <PolledOffer>[];
  for (final item in items) {
    if (item is! Map) continue;
    final requestId = _asInt(item['request_id']);
    final expiresAt = DateTime.tryParse('${item['expires_at'] ?? ''}');
    if (requestId == null || requestId <= 0 || expiresAt == null) {
      continue;
    }
    offers.add(
      PolledOffer(
        requestId: requestId,
        orderId: _asInt(item['order_id']) ?? 0,
        expiresAt: expiresAt,
        restaurantName: '${item['restaurant_name'] ?? ''}'.trim(),
        distanceKm: _asDouble(item['distance_km']),
        amount: _asDouble(item['amount']),
        paymentMode: '${item['payment_mode'] ?? ''}'.trim(),
      ),
    );
  }
  return offers;
}

/// What the service should do with the notifications it owns after a poll.
class OfferAlertPlan {
  const OfferAlertPlan({required this.toPost, required this.toCancel});

  /// Live offers nobody has alerted for yet.
  final List<PolledOffer> toPost;

  /// Request ids whose notification is up but whose offer is gone — accepted
  /// by someone, declined, expired or withdrawn. Cancelling stops the ring.
  final Set<int> toCancel;
}

OfferAlertPlan planOfferAlerts({
  required List<PolledOffer> live,
  required Set<String> alertedOfferKeys,
  required Set<int> postedRequestIds,
  required DateTime now,
}) {
  final liveNow = live.where((offer) => offer.isLiveAt(now)).toList();
  final liveIds = liveNow.map((offer) => offer.requestId).toSet();
  return OfferAlertPlan(
    toPost: liveNow
        .where((offer) => !alertedOfferKeys.contains(offer.offerKey))
        .toList(),
    toCancel: postedRequestIds.difference(liveIds),
  );
}

/// Adds [keys] to the shared alerted list, keeping the newest
/// [maxAlertedOfferKeys] so the list cannot grow without bound.
List<String> rememberAlertedOfferKeys(
  List<String> existing,
  Iterable<String> keys,
) {
  final merged = <String>[
    ...existing.where((key) => !keys.contains(key)),
    ...keys,
  ];
  if (merged.length <= maxAlertedOfferKeys) {
    return merged;
  }
  return merged.sublist(merged.length - maxAlertedOfferKeys);
}

/// Lock-screen-safe text for an offer: restaurant, distance, amount.
String requestNotificationBody(PolledOffer offer) {
  final parts = <String>[
    if (offer.restaurantName.isNotEmpty) offer.restaurantName,
    if (offer.distanceKm != null) '${offer.distanceKm!.toStringAsFixed(1)} km',
    if (offer.amount != null) 'Rs ${offer.amount!.toStringAsFixed(0)}',
    if (offer.paymentMode.isNotEmpty) offer.paymentMode.toUpperCase(),
  ];
  final summary = parts.isEmpty ? 'New delivery nearby' : parts.join(' · ');
  return '$summary. Tap to open and respond.';
}

/// Body for POST /api/v1/location/update from the service. Values that the
/// platform reports as unknown (NaN, negative) are dropped rather than sent.
Map<String, Object?> buildLocationPayload({
  required double latitude,
  required double longitude,
  required double accuracyMeters,
  required double heading,
  required double speed,
  required DateTime recordedAt,
  required bool appInForeground,
  required int sequence,
}) {
  return <String, Object?>{
    'latitude': latitude,
    'longitude': longitude,
    if (accuracyMeters.isFinite && accuracyMeters >= 0)
      'accuracy_meters': accuracyMeters,
    if (heading.isFinite && heading >= 0 && heading <= 360) 'heading': heading,
    if (speed.isFinite && speed >= 0) 'speed': speed,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'source': 'foreground_service',
    'app_state': appInForeground ? 'foreground' : 'background',
    'sequence': sequence,
  };
}

List<dynamic> _extractList(Object? data) {
  if (data is List) {
    return data;
  }
  if (data is Map) {
    for (final key in const ['items', 'requests', 'order_requests', 'data']) {
      final value = data[key];
      if (value is List) {
        return value;
      }
      if (value is Map) {
        final nested = _extractList(value);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }
  }
  return const <dynamic>[];
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}
