import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_cards.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(riderHubStateProvider);
    final profile = hub?.profile;
    if (profile == null) {
      return const PremiumScaffold(child: SizedBox.shrink());
    }

    return PremiumScaffold(
      title: 'Rider profile',
      subtitle: 'Identity, vehicle, preferences, and rider account controls.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          120,
        ),
        children: [
          PremiumProfileCard(
            initials: profile.avatarInitials,
            title: profile.name,
            subtitle: '${profile.phone}\n${profile.vehicleType} - ${profile.vehicleNumber}',
            accent: AppColors.gold,
            supportingText: '${profile.city} rider account',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Profile controls',
                  subtitle: 'Important rider tools and preferences.',
                ),
                const SizedBox(height: AppSpacing.lg),
                _ProfileTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit profile',
                  value: 'Basic info and vehicle details',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Wallet and payouts',
                  value: 'View balance and settlement flow',
                  onTap: () => context.push('/wallet'),
                ),
                _ProfileTile(
                  icon: Icons.star_outline_rounded,
                  label: 'Ratings and reviews',
                  value: 'Customer feedback and performance score',
                  onTap: () => context.push('/ratings'),
                ),
                _ProfileTile(
                  icon: Icons.schedule_rounded,
                  label: 'Availability',
                  value: 'Shift start, end, break, and busy mode',
                  onTap: () => context.push('/availability'),
                ),
                _ProfileTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  value: 'Theme, notifications, privacy, and version info',
                  onTap: () => context.push('/settings'),
                ),
                _ProfileTile(
                  icon: Icons.support_agent_rounded,
                  label: 'Help center',
                  value: 'FAQ, emergency support, and report issue',
                  onTap: () => context.push('/support'),
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
                  title: 'Rider credentials',
                  subtitle:
                      'Quick visibility into documents and preference status.',
                ),
                const SizedBox(height: AppSpacing.lg),
                _SimpleRow(label: 'Vehicle type', value: profile.vehicleType),
                _SimpleRow(
                  label: 'Vehicle number',
                  value: profile.vehicleNumber,
                ),
                _SimpleRow(
                  label: 'License or ID status',
                  value: profile.licenseStatus,
                ),
                _SimpleRow(
                  label: 'Shift preference',
                  value: profile.shiftPreference,
                ),
                _SimpleRow(
                  label: 'Theme',
                  value: ref.watch(themeModeControllerProvider).name,
                ),
                const _SimpleRow(
                  label: 'Language',
                  value: 'English (placeholder)',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Logout',
            expanded: true,
            icon: Icons.logout_rounded,
            onPressed: () async {
              await ref.read(sessionControllerProvider.notifier).logout();
              if (!context.mounted) {
                return;
              }
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.gold.withValues(alpha: 0.12),
        ),
        child: Icon(icon, color: AppColors.gold),
      ),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}


