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

/// Whether a newly received delivery request should alert the rider.
///
/// [seenRequestIds] is every request id that has already reached this rider in
/// this session, including ones since expired, accepted or declined — so a
/// request that comes back after being handled stays silent.
bool shouldAlertForRequest({
  required int requestId,
  required Set<int> seenRequestIds,
}) {
  return !seenRequestIds.contains(requestId);
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
