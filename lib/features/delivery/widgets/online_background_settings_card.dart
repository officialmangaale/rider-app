import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/premium_surfaces.dart';
import '../background/online_mode_prompts.dart';
import '../providers/rider_delivery_provider.dart';

/// Settings for Online background mode: what runs and when, and the controls
/// that affect reliability — notifications, battery optimisation, and the
/// optional floating bubble.
///
/// System settings screens change these outside the app, so the card
/// re-reads them whenever the app comes back to the foreground.
class OnlineBackgroundSettingsCard extends ConsumerStatefulWidget {
  const OnlineBackgroundSettingsCard({super.key});

  @override
  ConsumerState<OnlineBackgroundSettingsCard> createState() =>
      _OnlineBackgroundSettingsCardState();
}

class _OnlineBackgroundSettingsCardState
    extends ConsumerState<OnlineBackgroundSettingsCard>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _notificationsEnabled = true;
  bool _batteryUnrestricted = true;
  bool _bubbleEnabled = false;
  bool _overlayGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final background = ref.read(backgroundModeControllerProvider);
    final notifications = await background.notificationsEnabled();
    final battery = await background.isIgnoringBatteryOptimizations();
    final overlay = await background.canDrawOverlays();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _notificationsEnabled = notifications;
      _batteryUnrestricted = battery;
      _overlayGranted = overlay;
      _bubbleEnabled = background.bubbleEnabled;
    });
  }

  Future<void> _setBubble(bool enabled) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Show floating rider bubble?'),
          content: const Text(
            'Show a Mangaale Rider bubble over other apps while you are Online '
            'so you can quickly reopen the app when a delivery request '
            'arrives.\n\n'
            'Android will ask you to allow "Display over other apps". The '
            'bubble is optional: requests still ring without it. You can turn '
            'it off here at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final background = ref.read(backgroundModeControllerProvider);
    final granted = await background.setBubbleEnabled(enabled);
    if (!mounted) return;
    setState(() {
      _bubbleEnabled = enabled;
      _overlayGranted = granted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final background = ref.watch(backgroundModeControllerProvider);
    if (!background.supported) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Online in the background',
            subtitle:
                'Location is shared only while you are Online, including when '
                'the app is closed. A "Mangaale Rider is Online" notification '
                'is shown the whole time. Go Offline or log out to stop.',
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _notificationsEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
              ),
              title: const Text('Request alerts'),
              subtitle: Text(
                _notificationsEnabled
                    ? 'On. New requests ring even when the app is closed.'
                    : 'Off. Requests cannot ring while the app is closed.',
              ),
              trailing: _notificationsEnabled
                  ? null
                  : TextButton(
                      onPressed: () async {
                        await background.requestNotificationPermission();
                        await _refresh();
                      },
                      child: const Text('Allow'),
                    ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _batteryUnrestricted
                    ? Icons.battery_full_rounded
                    : Icons.battery_alert_rounded,
              ),
              title: const Text('Battery optimisation'),
              subtitle: Text(
                _batteryUnrestricted
                    ? 'Unrestricted. Android will not pause Mangaale Rider.'
                    : 'Restricted. Some phones pause apps to save battery, '
                          'which can delay requests. Set Mangaale Rider to '
                          '"Unrestricted" or "Don\'t optimise".',
              ),
              trailing: _batteryUnrestricted
                  ? null
                  : TextButton(
                      onPressed: background.openBatteryOptimizationSettings,
                      child: const Text('Open'),
                    ),
            ),
            if (background.bubbleAvailable)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.bubble_chart_rounded),
                title: const Text('Floating rider bubble'),
                subtitle: Text(
                  !_bubbleEnabled
                      ? 'Off. Optional shortcut back to the app while Online.'
                      : _overlayGranted
                      ? 'On. Shown over other apps while you are Online.'
                      : 'Waiting for "Display over other apps" permission.',
                ),
                value: _bubbleEnabled,
                onChanged: _setBubble,
              ),
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: Text(
                'Why Mangaale uses your location',
                style: theme.textTheme.bodySmall,
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text(onlineModeDisclosureTitle),
                  content: const SingleChildScrollView(
                    child: Text(onlineModeDisclosureBody),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
