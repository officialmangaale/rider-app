import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/referral_models.dart';
import '../../../presentation/providers/referral_provider.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

/// Rider referral programme — "refer a rider, earn a bonus".
///
/// Everything money-related on this screen comes from the server: the bonus
/// amount, the wording that describes it, and the share message. Nothing is
/// hardcoded, so an admin changing the bonus in the panel changes what riders
/// are promised here without an app release.
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referralAsync = ref.watch(referralControllerProvider);

    return PremiumScaffold(
      title: 'Refer a rider',
      subtitle: 'Invite riders you trust and earn a bonus when they deliver.',
      onRefresh: () => ref.read(referralControllerProvider.notifier).refresh(),
      child: referralAsync.when(
        loading: () => const _ReferralLoading(),
        error: (error, _) => _ReferralError(
          message: error is ApiException
              ? error.message
              : 'We could not load your referrals right now.',
          onRetry: () => ref.read(referralControllerProvider.notifier).refresh(),
        ),
        data: (dashboard) => _ReferralBody(dashboard: dashboard),
      ),
    );
  }
}

class _ReferralBody extends StatelessWidget {
  const _ReferralBody({required this.dashboard});

  final RiderReferralDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: [
        _CodeCard(dashboard: dashboard),
        const SizedBox(height: AppSpacing.lg),
        _EarningsCard(dashboard: dashboard),
        const SizedBox(height: AppSpacing.lg),
        _ReferralList(referrals: dashboard.referrals),
      ],
    );
  }
}

// ─── Code and sharing ────────────────────────────────────────────────────────

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.dashboard});

  final RiderReferralDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      accent: AppColors.riderPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            eyebrow: 'YOUR CODE',
            title: dashboard.code.isEmpty ? '—' : dashboard.code,
            // The offer is described by the server so this line can never
            // disagree with what the programme actually pays.
            subtitle: dashboard.rewardSummary.isEmpty
                ? 'Share your code with riders you know.'
                : 'You earn ${dashboard.rewardSummary} for every rider who '
                      'joins with your code and starts delivering.',
          ),

          // A paused programme still shows the code, because links already
          // shared keep working, but it must not promise a bonus.
          if (!dashboard.enabled) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'The referral programme is paused right now. New '
                      'referrals will not earn a bonus until it resumes.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Copy code',
                  icon: Icons.copy_rounded,
                  onPressed: dashboard.code.isEmpty
                      ? null
                      : () => _copy(context, dashboard.code, 'Code copied'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PrimaryButton(
                  label: 'Copy invite',
                  icon: Icons.ios_share_rounded,
                  onPressed: dashboard.shareMessage.isEmpty
                      ? null
                      : () => _copy(
                          context,
                          dashboard.shareMessage,
                          'Invite message copied — paste it anywhere',
                        ),
                ),
              ),
            ],
          ),

          if (dashboard.shareMessage.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              dashboard.shareMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _copy(BuildContext context, String value, String confirmation) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(confirmation),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Earnings ────────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.dashboard});

  final RiderReferralDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Your referral bonus',
            subtitle: 'Paid into your earnings once a referral qualifies.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Earned',
                  value: formatMillis(dashboard.totalEarnedMillis),
                  color: AppColors.emerald,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Joined',
                  value: '${dashboard.rewardedCount}',
                  color: AppColors.riderPrimary,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'In progress',
                  value:
                      '${dashboard.pendingCount + dashboard.qualifiedCount}',
                  color: AppColors.smoke,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: color),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ─── Referral list ───────────────────────────────────────────────────────────

class _ReferralList extends StatelessWidget {
  const _ReferralList({required this.referrals});

  final List<RiderReferralEntry> referrals;

  @override
  Widget build(BuildContext context) {
    if (referrals.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.group_add_outlined,
        title: 'No referrals yet',
        message:
            'Share your code with a rider you know. They will show up here as '
            'soon as they sign up.',
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Riders you referred',
            subtitle: '${referrals.length} in total',
          ),
          const SizedBox(height: AppSpacing.md),
          for (final entry in referrals) _ReferralRow(entry: entry),
        ],
      ),
    );
  }
}

class _ReferralRow extends StatelessWidget {
  const _ReferralRow({required this.entry});

  final RiderReferralEntry entry;

  @override
  Widget build(BuildContext context) {
    final paid = entry.isPaid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // A referred rider whose name we cannot resolve is shown as
                  // "A rider" rather than a blank line or an internal id.
                  entry.maskedName.isEmpty ? 'A rider' : entry.maskedName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  entry.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (paid && entry.rewardMillis > 0)
            StatusPill(
              label: formatMillis(entry.rewardMillis),
              color: AppColors.emerald,
              icon: Icons.check_rounded,
            ),
        ],
      ),
    );
  }
}

// ─── Loading and error ───────────────────────────────────────────────────────

class _ReferralLoading extends StatelessWidget {
  const _ReferralLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: const [
        ShimmerCard(height: 200),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 140),
      ],
    );
  }
}

class _ReferralError extends StatelessWidget {
  const _ReferralError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: [
        GlassCard(
          accent: AppColors.danger,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Referrals unavailable',
                subtitle: message,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
