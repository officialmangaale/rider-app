/// When an incoming delivery request or assignment may sound an alert.
///
/// Both transports deliver at least once — the socket replays after a
/// reconnect, and a push can carry the same request the socket already
/// delivered — so "an event arrived" is not the same as "this is new to the
/// rider". Ringing on every event means a rider is alerted repeatedly for an
/// order they have already seen, accepted, or declined.
///
/// Kept as pure functions, alongside [nextDeliveryActionFor] in
/// delivery_action_policy.dart, so the rule can be tested without a device.
library;

/// Identifies one *offer* of a delivery request.
///
/// rider-service re-offers an order whose earlier offer lapsed by reopening the
/// same request row, so the request id stays the same and only the expiry
/// changes. That re-offer is new to the rider and must alert; a replay of the
/// same offer (socket reconnect, a poll that overlaps the socket) must not.
///
/// Whole seconds, UTC: the socket payload and the pending-requests endpoint
/// both format expires_at as RFC 3339 without fractions, from the same value.
String requestOfferKey({required int requestId, required DateTime expiresAt}) {
  final seconds = expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000;
  return '$requestId@$seconds';
}

/// Whether a newly received delivery request offer should alert the rider.
///
/// [seenOfferKeys] is every offer that has already reached this rider in this
/// session, including ones since expired, accepted or declined — so an offer
/// that comes back after being handled stays silent.
bool shouldAlertForRequest({
  required String offerKey,
  required Set<String> seenOfferKeys,
}) {
  return !seenOfferKeys.contains(offerKey);
}

/// Whether a batch of pending offers — from polling, or the snapshot taken
/// after the socket connects — contains one the rider has not been alerted
/// for. The batch rings at most once however many offers are new.
bool shouldAlertForSnapshot({
  required Iterable<String> offerKeys,
  required Set<String> seenOfferKeys,
}) {
  return offerKeys.any((key) => !seenOfferKeys.contains(key));
}

/// Whether an order assigned to this rider by a restaurant should alert.
///
/// A repeat of the assignment the rider already holds is a replay, not a new
/// job. The order is still refreshed; only the alert is suppressed.
bool shouldAlertForAssignment({
  required int orderId,
  required int? activeOrderId,
}) {
  if (orderId <= 0) return false;
  return activeOrderId != orderId;
}
