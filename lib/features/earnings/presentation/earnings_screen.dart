import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_cards.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(riderHubStateProvider);
    final earnings = hub?.earnings;

    if (earnings == null) {
      return const PremiumScaffold(child: SizedBox.shrink());
    }

    return PremiumScaffold(
      title: 'Earnings',
      subtitle: 'Daily, weekly, and monthly income signals for premium riders.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          120,
        ),
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              MetricCard(
                label: 'Daily',
                value: Formatters.currency(earnings.daily),
                icon: Icons.today_rounded,
                accent: AppColors.gold,
              ),
              MetricCard(
                label: 'Weekly',
                value: Formatters.currency(earnings.weekly),
                icon: Icons.view_week_rounded,
                accent: AppColors.ember,
              ),
              MetricCard(
                label: 'Monthly',
                value: Formatters.currency(earnings.monthly),
                icon: Icons.calendar_month_rounded,
                accent: AppColors.emerald,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          InsightChart(points: earnings.trend),
          const SizedBox(height: AppSpacing.xl),
          PremiumAnalyticsCard(
            title: 'Incentives and tips',
            subtitle: 'Extra upside that keeps the shift premium.',
            icon: Icons.workspace_premium_rounded,
            accent: AppColors.gold,
            child: Column(
              children: [
                _Row(
                  label: 'Delivery incentives',
                  value: Formatters.currency(earnings.incentives),
                ),
                const SizedBox(height: AppSpacing.md),
                _Row(label: 'Tips', value: Formatters.currency(earnings.tips)),
                const SizedBox(height: AppSpacing.md),
                _Row(
                  label: 'Bonus',
                  value: Formatters.currency(earnings.bonus),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PremiumAnalyticsCard(
            title: 'Payout history',
            subtitle: 'Recent settlement trend heading into the wallet.',
            icon: Icons.account_balance_wallet_rounded,
            accent: AppColors.sky,
            trailing: TextButton(
              onPressed: () => context.push('/wallet'),
              child: const Text('Wallet'),
            ),
            child: Column(
              children: [
                for (int index = 0; index < earnings.payoutHistory.length; index++) ...[
                  _Row(
                    label: earnings.payoutHistory[index].label,
                    value: Formatters.currency(earnings.payoutHistory[index].amount),
                  ),
                  if (index != earnings.payoutHistory.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
