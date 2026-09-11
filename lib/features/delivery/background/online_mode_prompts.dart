import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/feedback_widgets.dart';
import '../providers/rider_delivery_provider.dart';

/// Shown before the rider goes Online for the first time, and before Android
/// is asked for location permission. Google Play requires an in-app
/// explanation ("prominent disclosure") before location that is used while
/// the app is in the background.
const onlineModeDisclosureTitle = 'Share location while Online';

const onlineModeDisclosureBody =
    'Mangaale uses your location while you are Online so nearby delivery '
    'requests can reach you and customers can track deliveries assigned to '
    'you.\n\n'
    'While you are Online this continues when the app is closed or the screen '
    'is off, and a "Mangaale Rider is Online" notification is always shown.\n\n'
    'Tracking stops when you go Offline or log out.';

/// Runs the checks that must happen, in order, before a rider goes Online.
///
/// Returns false if the rider declined the disclosure; the caller must then
/// not go Online. Missing notification permission is warned about but does
/// not block: requests still reach an app that is on screen.
Future<bool> prepareToGoOnline(BuildContext context, WidgetRef ref) async {
  if (!await confirmLocationDisclosure(context, ref)) {
    return false;
  }
  final background = ref.read(backgroundModeControllerProvider);
  final notificationsAllowed = await background.requestNotificationPermission();
  if (!notificationsAllowed && context.mounted) {
    showLuxurySnackBar(
      context,
      'Notifications are off, so new requests cannot ring while the app is '
      'closed. Turn them on in Settings.',
      isError: true,
    );
  }
  return true;
}

/// Shows the location disclosure once, before any location permission
/// prompt. Returns false if the rider declined.
Future<bool> confirmLocationDisclosure(
  BuildContext context,
  WidgetRef ref,
) async {
  final background = ref.read(backgroundModeControllerProvider);

  if (!background.disclosureAccepted) {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_on_rounded),
        title: const Text(onlineModeDisclosureTitle),
        content: const SingleChildScrollView(
          child: Text(onlineModeDisclosureBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      return false;
    }
    await background.acceptDisclosure();
  }
  return true;
}
