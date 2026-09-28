import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../background/request_alert_notifier.dart';
import '../models/delivery_request_intent.dart';

final deliveryRequestIntentProvider = StateProvider<DeliveryRequestIntent?>(
  (ref) => null,
);

// One plugin owner in the UI isolate, so posting/cancelling an alert cannot
// replace the tap callback with a second initialization without a handler.
final requestAlertNotifierProvider = Provider<RequestAlertNotifier>((ref) {
  return RequestAlertNotifier(
    onResponse: (response) {
      final intent = DeliveryRequestIntent.fromLocal(
        response.payload,
        response.actionId,
      );
      if (intent != null) {
        ref.read(deliveryRequestIntentProvider.notifier).state = intent;
      }
    },
  );
});
