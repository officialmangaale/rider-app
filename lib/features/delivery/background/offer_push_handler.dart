import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_mode_policy.dart';
import 'background_mode_store.dart';
import 'request_alert_notifier.dart';

/// What the app did with a delivery push.
enum OfferPushResult {
  /// An actionable notification was posted.
  posted,

  /// A "taken by another rider" message removed the offer's notification.
  closed,

  /// This offer has already alerted the rider (socket, poll or an earlier push).
  duplicate,

  /// The offer ran out before the push arrived.
  expired,

  /// No rider is signed in on this device.
  signedOut,

  /// Not an offer message.
  ignored,
}

/// Turns a push from rider-service into an actionable notification.
///
/// The push is data-only on purpose: a notification message would be drawn by
/// the system without Accept and Decline, and would skip this code. So the
/// notification is built here, from the message's data, in the isolate Android
/// starts for a message that arrives while the app is in the background or not
/// running.
///
/// The push is a hint, not the offer. Nothing here accepts, declines or trusts
/// anything for the order: the buttons call the backend, which decides. What
/// this does decide is whether to alert at all: a signed-in rider, an offer that
/// has not expired, and one that has not already alerted through another path.
class OfferPushHandler {
  OfferPushHandler({
    required this.store,
    required this.notifier,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BackgroundModeStore store;
  final RequestAlertNotifier notifier;
  final DateTime Function() _clock;

  Future<OfferPushResult> handle(Map<String, dynamic> data) async {
    final closedOrderId = closedOfferOrderId(data);
    if (closedOrderId != null) {
      await notifier.cancelOffersForOrder(closedOrderId);
      return OfferPushResult.closed;
    }

    final offer = offerFromPushData(data);
    if (offer == null) return OfferPushResult.ignored;

    await store.reload();
    final token = store.accessToken?.trim();
    if (token == null || token.isEmpty) return OfferPushResult.signedOut;

    final now = _clock();
    if (!offer.isLiveAt(now)) return OfferPushResult.expired;

    // The socket, the app's poll and the Online service alert through the same
    // shared list, so one offer rings once whichever arrives first.
    if (store.alertedOfferKeys.contains(offer.offerKey)) {
      return OfferPushResult.duplicate;
    }
    await store.rememberAlerted([offer.offerKey]);
    await notifier.showRequest(offer, now: now);
    return OfferPushResult.posted;
  }
}

/// The FCM background message handler. Registered from main() with
/// `FirebaseMessaging.onBackgroundMessage`; it must stay top-level with the
/// entry-point pragma.
@pragma('vm:entry-point')
Future<void> handleRiderBackgroundMessage(Map<String, dynamic> data) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase is already initialised natively on Android; this only matters
    // for other Firebase APIs, which this handler does not use.
  }
  final notifier = RequestAlertNotifier();
  await OfferPushHandler(
    store: BackgroundModeStore(await SharedPreferences.getInstance()),
    notifier: notifier,
  ).handle(data);
}
