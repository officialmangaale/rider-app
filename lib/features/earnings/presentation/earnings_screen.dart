import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_cards.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsControllerProvider);

    return PremiumScaffold(
      title: 'Earnings',
      subtitle: 'Revenue breakdown, trend, and payout overview.',
      onRefresh: () => ref.read(earningsControllerProvider.notifier).refresh(),
      child: earningsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              ShimmerCard(),
              SizedBox(height: AppSpacing.md),
              ShimmerCard(),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: EmptyStateCard(
            icon: Icons.warning_rounded,
            title: 'Could not load earnings',
            subtitle: error is ApiException
                ? error.message
                : 'Something went wrong. Please try again.',
            action: FilledButton.icon(
              onPressed: () =>
                  ref.read(earningsControllerProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ),
        data: (state) {
          final earnings = state.earnings;
          if (earnings == null || !state.hasAnyEarnings) {
            return Center(
              child: EmptyStateCard(
                icon: Icons.attach_money_rounded,
                emoji: '💸',
                animateVisual: true,
                title: 'No earnings yet',
                subtitle:
                    'No earnings yet - once you complete deliveries, your earnings will appear here.',
                action: OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(earningsControllerProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ),
            );
          }

          final payout = state.payoutSummary;
          final hasBreakdown =
              earnings.deliveryFees > 0 ||
              earnings.incentives > 0 ||
              earnings.tips > 0 ||
              earnings.bonus > 0;
          final hasPayoutSummary =
              payout != null &&
              (payout.walletBalance > 0 ||
                  payout.pendingPayout > 0 ||
                  payout.settledPayout > 0 ||
                  payout.bankAccountMasked.isNotEmpty);
          final hasTrend =
              earnings.trend.isNotEmpty &&
              earnings.trend.any((point) => point.amount > 0);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  MetricCard(
                    label: 'Today',
                    value: Formatters.currency(earnings.daily),
                    icon: Icons.today_rounded,
                    accent: AppColors.gold,
                  ),
                  MetricCard(
                    label: 'This week',
                    value: Formatters.currency(earnings.weekly),
                    icon: Icons.calendar_view_week_rounded,
                    accent: AppColors.sky,
                  ),
                  MetricCard(
                    label: 'This month',
                    value: Formatters.currency(earnings.monthly),
                    icon: Icons.calendar_month_rounded,
                    accent: AppColors.emerald,
                  ),
                  MetricCard(
                    label: 'Total',
                    value: Formatters.currency(state.totalEarnings),
                    icon: Icons.payments_rounded,
                    accent: AppColors.cherry,
                  ),
                ],
              ),
              if (hasTrend) ...[
                const SizedBox(height: AppSpacing.xl),
                SparklineMetricCard(
                  title: 'Earnings trend',
                  value: Formatters.currency(earnings.weekly),
                  trend: earnings.trend.map((p) => p.amount).toList(),
                ),
              ],
              if (hasPayoutSummary) ...[
                const SizedBox(height: AppSpacing.xl),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Payout overview',
                        subtitle: 'Wallet and settlement status.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _EarningsRow(
                        label: 'Wallet balance',
                        value: Formatters.currency(payout.walletBalance),
                      ),
                      _EarningsRow(
                        label: 'Pending',
                        value: Formatters.currency(payout.pendingPayout),
                      ),
                      _EarningsRow(
                        label: 'Settled',
                        value: Formatters.currency(payout.settledPayout),
                      ),
                      if (payout.bankAccountMasked.isNotEmpty)
                        _EarningsRow(
                          label: 'Bank',
                          value: payout.bankAccountMasked,
                        ),
                    ],
                  ),
                ),
              ],
              if (hasBreakdown) ...[
                const SizedBox(height: AppSpacing.xl),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Breakdown',
                        subtitle: 'Where your earnings come from.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (earnings.deliveryFees > 0)
                        _EarningsRow(
                          label: 'Delivery fees',
                          value: Formatters.currency(earnings.deliveryFees),
                        ),
                      if (earnings.incentives > 0)
                        _EarningsRow(
                          label: 'Incentives',
                          value: Formatters.currency(earnings.incentives),
                        ),
                      if (earnings.tips > 0)
                        _EarningsRow(
                          label: 'Tips',
                          value: Formatters.currency(earnings.tips),
                        ),
                      if (earnings.bonus > 0)
                        _EarningsRow(
                          label: 'Bonus',
                          value: Formatters.currency(earnings.bonus),
                        ),
                    ],
                  ),
                ),
              ],
              if (earnings.payoutHistory.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Payout history',
                        subtitle: 'Recent settlement activity.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final entry in earnings.payoutHistory)
                        _EarningsRow(
                          label: entry.label,
                          value: Formatters.currency(entry.amount),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EarningsRow extends StatelessWidget {
  const _EarningsRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
