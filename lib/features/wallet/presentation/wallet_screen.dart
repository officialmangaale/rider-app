import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsControllerProvider);
    final summary = earningsAsync.valueOrNull?.payoutSummary;
    if (summary == null) {
      return const PremiumScaffold(child: SizedBox.shrink());
    }

    return PremiumScaffold(
      title: 'Wallet & payouts',
      subtitle:
          'Track wallet balance, pending settlements, and bank payout readiness.',
      child: ListView(
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
                label: 'Wallet balance',
                value: Formatters.currency(summary.walletBalance),
                icon: Icons.account_balance_wallet_rounded,
                accent: AppColors.gold,
              ),
              MetricCard(
                label: 'Pending payout',
                value: Formatters.currency(summary.pendingPayout),
                icon: Icons.schedule_rounded,
                accent: AppColors.ember,
              ),
              MetricCard(
                label: 'Settled payout',
                value: Formatters.currency(summary.settledPayout),
                icon: Icons.verified_rounded,
                accent: AppColors.emerald,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            accent: AppColors.sky,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Bank account',
                  subtitle:
                      'Connected payout destination and withdrawal controls.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  summary.bankAccountMasked,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Request withdrawal',
                  icon: Icons.file_upload_outlined,
                  expanded: true,
                  onPressed: () => _showPayoutSheet(
                    context: context,
                    ref: ref,
                    maxAmount: summary.walletBalance,
                  ),
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
                  title: 'Transactions',
                  subtitle: 'Recent credits, holds, and settlement activity.',
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final tx in summary.transactions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppColors.gold.withValues(alpha: 0.12),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Formatters.dayTime(tx.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Formatters.currency(tx.amount),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tx.status,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPayoutSheet({
    required BuildContext context,
    required WidgetRef ref,
    required double maxAmount,
  }) async {
    final controller = TextEditingController();
    var submitting = false;

    await showPremiumBottomSheet(
      context: context,
      title: 'Request payout',
      subtitle:
          'Submit a withdrawal request against your current wallet balance.',
      child: StatefulBuilder(
        builder: (sheetContext, setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumTextField(
                label: 'Amount',
                hint: 'Enter amount in INR',
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icons.currency_rupee_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Available balance: ${Formatters.currency(maxAmount)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: submitting ? 'Submitting request...' : 'Request payout',
                icon: Icons.account_balance_wallet_outlined,
                expanded: true,
                onPressed: submitting
                    ? null
                    : () async {
                        final amount = double.tryParse(controller.text.trim());
                        if (amount == null || amount <= 0) {
                          showLuxurySnackBar(
                            context,
                            'Enter a valid payout amount.',
                          );
                          return;
                        }
                        if (amount > maxAmount) {
                          showLuxurySnackBar(
                            context,
                            'Requested amount exceeds your wallet balance.',
                          );
                          return;
                        }
                        setModalState(() => submitting = true);
                        try {
                          await ref
                              .read(earningsControllerProvider.notifier)
                              .requestPayout(amount: amount);
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                          showLuxurySnackBar(
                            context,
                            'Payout request submitted successfully.',
                          );
                        } on ApiException catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          showLuxurySnackBar(context, error.message);
                        } finally {
                          if (sheetContext.mounted) {
                            setModalState(() => submitting = false);
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
  }
}
