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
    this.orderType = 'food',
    this.pickupAddress = '',
    this.deliveryArea = '',
  });

  final int requestId;
  final int orderId;
  final DateTime expiresAt;
  final String restaurantName;

  /// From the rider to the pickup.
  final double? distanceKm;

  /// The order value carried by the offer. It is not the rider's payout, which
  /// is credited on delivery and is not part of an offer.
  final double? amount;
  final String paymentMode;

  /// "food" or "grocery".
  final String orderType;

  /// The restaurant's address. Never the customer's: that is withheld until
  /// the rider accepts.
  final String pickupAddress;

  /// A coarse description of where the order goes (see [deliveryAreaFor]).
  final String deliveryArea;

  /// What the rider sees as the order's reference.
  String get orderRef => '#$orderId';

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
        orderType: _orderType(item['order_type']),
        pickupAddress: '${item['pickup_address'] ?? ''}'.trim(),
        deliveryArea: deliveryAreaFor(_asDouble(item['delivery_distance_km'])),
      ),
    );
  }
  return offers;
}

/// Message types of the offer push (see rider-service internal/push).
const offerPushType = 'DELIVERY_ORDER_REQUEST';
const offerClosedPushType = 'DELIVERY_ORDER_REQUEST_CLOSED';

/// Builds an offer from an FCM data payload, or null when it is not a usable
/// offer: wrong type, no request id, no order id, or no expiry. A push is a
/// hint and can arrive late, so the expiry is what decides whether to alert.
PolledOffer? offerFromPushData(Map<String, dynamic> data) {
  if ('${data['type'] ?? ''}'.trim().toUpperCase() != offerPushType) {
    return null;
  }
  final requestId = _asInt(data['request_id']);
  final orderId = _asInt(data['order_id']);
  final expiresAt = DateTime.tryParse('${data['expires_at'] ?? ''}');
  if (requestId == null ||
      requestId <= 0 ||
      orderId == null ||
      orderId <= 0 ||
      expiresAt == null) {
    return null;
  }
  final area = '${data['delivery_area'] ?? ''}'.trim();
  return PolledOffer(
    requestId: requestId,
    orderId: orderId,
    expiresAt: expiresAt,
    restaurantName: '${data['restaurant_name'] ?? ''}'.trim(),
    distanceKm: _asDouble(data['distance_km']),
    amount: _asDouble(data['amount']),
    paymentMode: '${data['payment_mode'] ?? ''}'.trim(),
    orderType: _orderType(data['order_type']),
    pickupAddress: '${data['pickup_address'] ?? ''}'.trim(),
    deliveryArea: area.isNotEmpty
        ? area
        : deliveryAreaFor(_asDouble(data['delivery_distance_km'])),
  );
}

/// The order an "offer closed" push is about, or null when it is not one.
int? closedOfferOrderId(Map<String, dynamic> data) {
  if ('${data['type'] ?? ''}'.trim().toUpperCase() != offerClosedPushType) {
    return null;
  }
  final orderId = _asInt(data['order_id']);
  return orderId != null && orderId > 0 ? orderId : null;
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

/// The delivery area shown for an offer: the rounded straight-line distance
/// from the pickup. The data model has no structured locality for a delivery
/// and the customer's address is withheld until acceptance, so this is all
/// that can be said without guessing. Matches the backend's label.
String deliveryAreaFor(double? deliveryDistanceKm) {
  if (deliveryDistanceKm == null || deliveryDistanceKm <= 0) return '';
  return 'Approx. ${deliveryDistanceKm.toStringAsFixed(0)} km from pickup';
}

/// Title of an offer notification: what it is, and which order.
String requestNotificationTitle(PolledOffer offer) => offer.orderId > 0
    ? 'New delivery request ${offer.orderRef}'
    : 'New delivery request';

/// The collapsed one-line text: restaurant, distance to pickup, order value.
/// Nothing that identifies the customer.
String requestNotificationBody(PolledOffer offer) {
  final parts = <String>[
    if (offer.restaurantName.isNotEmpty) offer.restaurantName,
    if (offer.distanceKm != null)
      '${offer.distanceKm!.toStringAsFixed(1)} km to pickup',
    if (offer.deliveryArea.isNotEmpty) offer.deliveryArea,
    if (offer.amount != null) 'Order Rs ${offer.amount!.toStringAsFixed(0)}',
    if (offer.paymentMode.isNotEmpty) offer.paymentMode.toUpperCase(),
  ];
  final summary = parts.isEmpty ? 'New delivery nearby' : parts.join(' · ');
  return '$summary. Tap to open and respond.';
}

/// The expanded text: one fact per line, so the rider can decide from the
/// notification alone.
String requestNotificationDetails(PolledOffer offer) {
  final lines = <String>[
    [
      if (offer.orderId > 0) offer.orderRef,
      if (offer.restaurantName.isNotEmpty) offer.restaurantName,
    ].join(' · '),
    if (offer.pickupAddress.isNotEmpty) 'Pickup: ${offer.pickupAddress}',
    if (offer.deliveryArea.isNotEmpty) 'Delivery: ${offer.deliveryArea}',
    if (offer.distanceKm != null)
      'Distance to pickup: ${offer.distanceKm!.toStringAsFixed(1)} km',
    if (offer.amount != null)
      'Order value: Rs ${offer.amount!.toStringAsFixed(0)}'
          '${offer.paymentMode.isEmpty ? '' : ' (${offer.paymentMode.toUpperCase()})'}',
  ].where((line) => line.trim().isNotEmpty).toList();
  return lines.isEmpty ? 'New delivery nearby' : lines.join('\n');
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

String _orderType(Object? value) =>
    '$value'.trim().toLowerCase() == 'grocery' ? 'grocery' : 'food';

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
