import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app/app.dart';
import 'presentation/providers/app_providers.dart';
import 'features/delivery/background/offer_push_handler.dart';
import 'features/delivery/background/rider_online_service.dart';

/// A push received while the app is in the background or not running. Delivery
/// offers become an actionable notification (Accept / Decline); see
/// OfferPushHandler. It does nothing for messages that are not offers.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) =>
    handleRiderBackgroundMessage(message.data);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final preferences = await SharedPreferences.getInstance();

  // Registers the Online foreground service; it starts only when a rider
  // goes Online.
  await configureRiderOnlineService();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const RydexRiderApp(),
    ),
  );
}
