import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _orderAlerts = true;
  bool _promotions = true;
  bool _privacyMode = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeControllerProvider);

    return PremiumScaffold(
      title: 'Settings',
      subtitle:
          'Notification preferences, theme mode, privacy, terms, and app version.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Notification settings',
                  subtitle: 'Choose what reaches you during the shift.',
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Order alerts'),
                  value: _orderAlerts,
                  onChanged: (value) => setState(() => _orderAlerts = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incentives and promos'),
                  value: _promotions,
                  onChanged: (value) => setState(() => _promotions = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'App preferences',
                  subtitle: 'Theme, privacy, and rider comfort controls.',
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use dark theme'),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (_) =>
                      ref.read(themeModeControllerProvider.notifier).toggle(),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Privacy mode'),
                  value: _privacyMode,
                  onChanged: (value) => setState(() => _privacyMode = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Terms & conditions'),
                  subtitle: const Text('Placeholder link for legal pages'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Version info'),
                  subtitle: const Text('Rydex Rider v1.0.0+1'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

