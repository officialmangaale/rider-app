import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/delivery_helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class ActiveDeliveryScreen extends ConsumerWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryAsync = ref.watch(deliveryControllerProvider);

    return PremiumScaffold(
      title: 'Active delivery',
      subtitle: 'Track and manage your current order.',
      onRefresh: () =>
          ref.read(deliveryControllerProvider.notifier).refresh(),
      child: deliveryAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [ShimmerCard(), SizedBox(height: AppSpacing.md), ShimmerCard()],
          ),
        ),
        error: (error, _) => Center(
          child: EmptyStateCard(
            icon: Icons.warning_rounded,
            title: 'Could not load delivery',
            subtitle: error is ApiException ? error.message : 'Something went wrong.',
          ),
        ),
        data: (state) {
          if (!state.hasActiveOrder) {
            return const Center(
              child: EmptyStateCard(
                icon: Icons.delivery_dining_rounded,
                title: 'No active delivery',
                subtitle: 'Accept an order from the Requests tab to start.',
              ),
            );
          }

          final order = state.activeOrder!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
            ),
            children: [
              // ── Order header ───────────────────────────────
              GlassCard(
                accent: AppColors.gold,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.restaurantName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${order.customerName} · ${order.orderCode}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        StatusPill(
                          label: DeliveryHelpers.statusLabel(order.status),
                          color: AppColors.gold,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Metric(
                          label: 'Payout',
                          value: Formatters.currency(order.payout),
                        ),
                        _Metric(
                          label: 'Distance',
                          value: Formatters.distance(order.distanceKm),
                        ),
                        _Metric(
                          label: 'ETA',
                          value: Formatters.minutes(order.etaMinutes),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Status timeline ─────────────────────────────
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Delivery progress',
                      subtitle: 'Each checkpoint in your order journey.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    StatusTimeline(
                      currentStage: order.status,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Action buttons ──────────────────────────────
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Actions',
                      subtitle: 'Contact, navigate, or advance stage.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Call',
                            icon: Icons.call_rounded,
                            onPressed: () => showLuxurySnackBar(
                              context,
                              'Dialer integration ready — connect url_launcher next.',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Navigate',
                            icon: Icons.navigation_rounded,
                            onPressed: () => context.push('/navigation'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _AdvanceButton(order: order),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Queued orders ───────────────────────────────
              if (state.queuedOrders.isNotEmpty)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Queued (${state.queuedOrders.length})',
                        subtitle: 'Orders waiting after current delivery.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final q in state.queuedOrders)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${q.restaurantName} → ${q.customerName}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                Formatters.currency(q.payout),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Advance button ─────────────────────────────────────────────────────────

class _AdvanceButton extends ConsumerStatefulWidget {
  const _AdvanceButton({required this.order});
  final DeliveryOrder order;

  @override
  ConsumerState<_AdvanceButton> createState() => _AdvanceButtonState();
}

class _AdvanceButtonState extends ConsumerState<_AdvanceButton> {
  bool _loading = false;

  bool get _requiresOtp {
    final s = widget.order.status;
    return (s == DeliveryStage.reachedRestaurant &&
            widget.order.pickupOtpRequired) ||
        (s == DeliveryStage.reachedCustomer &&
            widget.order.deliveryOtpRequired);
  }

  String get _label {
    if (_loading) return 'Verifying...';
    if (widget.order.status == DeliveryStage.delivered) return 'Completed ✓';
    final nextIndex = widget.order.status.index + 1;
    if (nextIndex >= DeliveryStage.values.length) return 'Completed ✓';
    return 'Advance → ${DeliveryHelpers.stageLabel(DeliveryStage.values[nextIndex])}';
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.order.status == DeliveryStage.delivered;

    return PrimaryButton(
      label: _label,
      icon: isDone ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
      expanded: true,
      onPressed: (isDone || _loading)
          ? null
          : () async {
              if (_requiresOtp) {
                _showOtpSheet();
              } else {
                await _advance(null);
              }
            },
    );
  }

  Future<void> _advance(String? otp) async {
    setState(() => _loading = true);
    try {
      await ref
          .read(deliveryControllerProvider.notifier)
          .advanceActiveOrder(otp: otp);
    } on ApiException catch (e) {
      if (!mounted) return;
      showLuxurySnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOtpSheet() {
    final controller = TextEditingController();
    showPremiumBottomSheet(
      context: context,
      title: 'Verify OTP',
      subtitle: 'Enter the OTP to proceed with this stage.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumTextField(
            label: 'OTP code',
            hint: 'Enter 4–6 digit code',
            controller: controller,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Verify & advance',
            icon: Icons.verified_rounded,
            expanded: true,
            onPressed: () {
              final otp = controller.text.trim();
              if (otp.isEmpty) {
                showLuxurySnackBar(context, 'Enter the OTP first.');
                return;
              }
              Navigator.of(context).pop();
              _advance(otp);
            },
          ),
        ],
      ),
    );
  }
}

// ── Metric display ─────────────────────────────────────────────────────────

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
