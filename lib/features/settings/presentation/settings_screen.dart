import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return PremiumScaffold(
      title: 'Settings',
      subtitle:
          'Notification preferences, theme mode, privacy, terms, and app version.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
        ),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Notification settings',
                  subtitle: 'Choose what reaches you during your shift.',
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Order alerts'),
                  value: settings.orderAlerts,
                  onChanged: (v) => ref
                      .read(settingsControllerProvider.notifier)
                      .setOrderAlerts(v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incentives and promos'),
                  value: settings.promotions,
                  onChanged: (v) => ref
                      .read(settingsControllerProvider.notifier)
                      .setPromotions(v),
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
                  value: settings.themeMode == ThemeMode.dark,
                  onChanged: (_) => ref
                      .read(settingsControllerProvider.notifier)
                      .toggleTheme(),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Privacy mode'),
                  value: settings.privacyMode,
                  onChanged: (v) => ref
                      .read(settingsControllerProvider.notifier)
                      .setPrivacyMode(v),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Terms & conditions'),
                  subtitle: Text('Placeholder link for legal pages'),
                  trailing: Icon(Icons.chevron_right_rounded),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Version info'),
                  subtitle: Text('Rydex Rider v1.0.0+1'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
