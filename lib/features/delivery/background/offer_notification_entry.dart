import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/delivery_request_intent.dart';
import 'background_mode_store.dart';
import 'offer_action_runner.dart';
import 'request_alert_notifier.dart';

/// Ids of the actions on an offer notification. They travel back through
/// [NotificationResponse.actionId] and are parsed by
/// [DeliveryRequestIntent.fromLocal].
const offerActionAccept = 'accept';
const offerActionDecline = 'decline';

/// Entry point Android calls for an Accept or Decline tapped on an offer
/// notification when the app is not in the foreground: the app may be in the
/// background or not running at all. There is no screen, no Riverpod scope and
/// no plugin registration yet, so it builds exactly what it needs.
///
/// It must be a top-level function with the entry-point pragma, or release
/// builds tree-shake it away and the buttons silently do nothing.
@pragma('vm:entry-point')
Future<void> offerNotificationBackgroundHandler(
  NotificationResponse response,
) async {
  DartPluginRegistrant.ensureInitialized();
  final intent = DeliveryRequestIntent.fromLocal(
    response.payload,
    response.actionId,
  );
  if (intent == null || intent.action == DeliveryRequestAction.open) {
    return;
  }
  final client = http.Client();
  try {
    await OfferActionRunner(
      store: BackgroundModeStore(await SharedPreferences.getInstance()),
      notifier: RequestAlertNotifier(),
      client: client,
    ).run(intent);
  } finally {
    client.close();
  }
}
