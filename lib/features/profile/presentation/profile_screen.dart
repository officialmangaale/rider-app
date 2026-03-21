import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileControllerProvider);

    return PremiumScaffold(
      title: 'Profile',
      subtitle: 'Your rider identity, vehicle, and account controls.',
      onRefresh: () =>
          ref.read(profileControllerProvider.notifier).refresh(),
      child: profileAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(children: [ShimmerCard(), SizedBox(height: AppSpacing.md), ShimmerCard()]),
        ),
        error: (error, _) => Center(
          child: EmptyStateCard(
            icon: Icons.warning_rounded,
            title: 'Could not load profile',
            subtitle: error is ApiException ? error.message : 'Something went wrong.',
          ),
        ),
        data: (profile) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
          ),
          children: [
            // ── Avatar + name ────────────────────────────────
            GlassCard(
              accent: AppColors.riderPrimary,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor:
                        AppColors.riderPrimary.withValues(alpha: 0.12),
                    child: Text(
                      profile.avatarInitials,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: AppColors.riderPrimary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${profile.phone} · ${profile.city}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Vehicle ──────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Vehicle details',
                    subtitle: 'Your registered vehicle information.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _InfoRow(label: 'Type', value: profile.vehicleType),
                  _InfoRow(label: 'Number', value: profile.vehicleNumber),
                  _InfoRow(label: 'License', value: profile.licenseStatus),
                  _InfoRow(label: 'Shift', value: profile.shiftPreference),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Account controls ─────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Account',
                    subtitle: 'Manage wallet, ratings, settings.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ActionTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet & payouts',
                    onTap: () => context.push('/wallet'),
                  ),
                  _ActionTile(
                    icon: Icons.star_outline_rounded,
                    label: 'Ratings & reviews',
                    onTap: () => context.push('/ratings'),
                  ),
                  _ActionTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Logout ───────────────────────────────────────
            SecondaryButton(
              label: 'Log out',
              icon: Icons.logout_rounded,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text(
                      'You will need to sign in again to access your account.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                await ref.read(sessionControllerProvider.notifier).logout();
                if (!context.mounted) return;
                context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
