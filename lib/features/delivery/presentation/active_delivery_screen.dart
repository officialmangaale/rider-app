import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_cards.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class ActiveDeliveryScreen extends ConsumerWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(riderHubControllerProvider);

    return PremiumScaffold(
      title: 'Active delivery',
      subtitle:
          'Move smoothly from pickup confirmation to OTP verified handoff.',
      child: hub.when(
        loading: () => const _DeliverySkeleton(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: EmptyStateCard(
              icon: Icons.error_outline_rounded,
              title: 'Delivery lane unavailable',
              message: 'We could not load your current delivery right now.',
              action: PrimaryButton(
                label: 'Retry',
                onPressed: () =>
                    ref.read(riderHubControllerProvider.notifier).refreshHub(),
              ),
            ),
          ),
        ),
        data: (state) {
          final order = state.activeOrder;
          if (order == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: EmptyStateCard(
                  icon: Icons.route_outlined,
                  title: 'No active delivery yet',
                  message:
                      'Accept a request to unlock route actions, pickup status, and OTP verification.',
                  action: PrimaryButton(
                    label: 'Open Requests',
                    icon: Icons.bolt_rounded,
                    onPressed: () => context.go('/requests'),
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              120,
            ),
            children: [
              Hero(
                tag: 'order-${order.id}',
                child: PremiumOrderCard(
                  order: order,
                  accent: AppColors.ember,
                  subtitle: 'Order ${order.orderCode} for ${order.customerName}',
                  showNotes: false,
                  trailing: StatusPill(
                    label: _stageLabel(order.status),
                    color: AppColors.ember,
                    icon: Icons.delivery_dining_rounded,
                  ),
                  footer: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      StatusPill(
                        label: order.paymentMethod,
                        color: AppColors.sky,
                        icon: Icons.payments_outlined,
                      ),
                      if (order.pickupOtpRequired)
                        const StatusPill(
                          label: 'Pickup OTP',
                          color: AppColors.gold,
                          icon: Icons.storefront_outlined,
                        ),
                      if (order.deliveryOtpRequired)
                        const StatusPill(
                          label: 'Delivery OTP',
                          color: AppColors.emerald,
                          icon: Icons.verified_user_rounded,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Action deck',
                      subtitle:
                          'Essential rider actions without leaving the delivery view.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        IconActionChip(
                          label: 'Call customer',
                          icon: Icons.call_outlined,
                          onTap: () => showLuxurySnackBar(
                            context,
                            'Calling ${order.customerName} is ready for API integration.',
                          ),
                        ),
                        IconActionChip(
                          label: 'Call restaurant',
                          icon: Icons.storefront_outlined,
                          onTap: () => showLuxurySnackBar(
                            context,
                            'Restaurant dial action is ready for API integration.',
                          ),
                        ),
                        IconActionChip(
                          label: 'Navigate',
                          icon: Icons.navigation_outlined,
                          onTap: () => context.push('/navigation'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (order.notes.trim().isNotEmpty) ...[
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        order.notes,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(
                      '${order.itemsCount} items - ${order.paymentMethod}',
                      style: Theme.of(context).textTheme.bodySmall,
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
                      title: 'Status timeline',
                      subtitle:
                          'Advance the delivery confidently with clear progress checkpoints.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    StatusTimeline(currentStage: order.status),
                  ],
                ),
              ),
              if (state.queuedOrders.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                GlassCard(
                  accent: AppColors.sky,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Queued after this drop',
                        subtitle:
                            'Accepted stacked orders ready to become active next.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final queued in state.queuedOrders)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _QueuedOrderTile(order: queued),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'View map',
                      icon: Icons.map_outlined,
                      onPressed: () => context.push('/navigation'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      label: _actionLabelForStage(order),
                      icon: _actionIconForStage(order.status),
                      expanded: true,
                      onPressed: () => _handlePrimaryAction(
                        context: context,
                        ref: ref,
                        order: order,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handlePrimaryAction({
    required BuildContext context,
    required WidgetRef ref,
    required DeliveryOrder order,
  }) async {
    final controller = ref.read(riderHubControllerProvider.notifier);

    try {
      if (order.status == DeliveryStage.reachedRestaurant &&
          order.pickupOtpRequired) {
        await _showOtpSheet(
          context: context,
          title: 'Verify pickup OTP',
          subtitle:
              'Confirm the restaurant handoff before the order moves into pickup.',
          onSubmit: (otp) => controller.advanceActiveOrder(otp: otp),
          successMessage: 'Pickup OTP verified and order marked picked up.',
        );
        return;
      }

      if (order.status == DeliveryStage.reachedCustomer &&
          order.deliveryOtpRequired) {
        await _showOtpSheet(
          context: context,
          title: 'Verify delivery OTP',
          subtitle:
              'Confirm the final handoff before the delivery is completed.',
          onSubmit: (otp) => controller.advanceActiveOrder(otp: otp),
          successMessage: 'Delivery OTP verified and trip completed.',
        );
        return;
      }

      await controller.advanceActiveOrder();
      if (!context.mounted) {
        return;
      }
      showLuxurySnackBar(context, _successMessageForStage(order.status));
    } on ApiException catch (error) {
      if (!context.mounted) {
        return;
      }
      showLuxurySnackBar(context, error.message);
    }
  }

  Future<void> _showOtpSheet({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Future<void> Function(String otp) onSubmit,
    required String successMessage,
  }) async {
    final controller = TextEditingController();
    var submitting = false;

    await showPremiumBottomSheet(
      context: context,
      title: title,
      subtitle: subtitle,
      child: StatefulBuilder(
        builder: (sheetContext, setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumTextField(
                label: 'OTP code',
                hint: 'Enter OTP',
                controller: controller,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.password_rounded,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: submitting ? 'Verifying...' : 'Verify and continue',
                icon: Icons.check_circle_rounded,
                expanded: true,
                onPressed: submitting
                    ? null
                    : () async {
                        final otp = controller.text.trim();
                        if (otp.length < 4) {
                          showLuxurySnackBar(
                            context,
                            'Enter the OTP to continue.',
                          );
                          return;
                        }
                        setModalState(() => submitting = true);
                        try {
                          await onSubmit(otp);
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                          showLuxurySnackBar(context, successMessage);
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

String _actionLabelForStage(DeliveryOrder order) => switch (order.status) {
  DeliveryStage.assigned => 'Accept order',
  DeliveryStage.accepted => 'Mark reached restaurant',
  DeliveryStage.reachedRestaurant => order.pickupOtpRequired
      ? 'Verify pickup OTP'
      : 'Confirm pickup',
  DeliveryStage.pickedUp => 'Start route',
  DeliveryStage.onTheWay => 'Mark arrived',
  DeliveryStage.reachedCustomer => order.deliveryOtpRequired
      ? 'Verify delivery OTP'
      : 'Complete delivery',
  DeliveryStage.delivered => 'Delivered',
};

IconData _actionIconForStage(DeliveryStage stage) => switch (stage) {
  DeliveryStage.assigned => Icons.check_circle_outline_rounded,
  DeliveryStage.accepted => Icons.storefront_outlined,
  DeliveryStage.reachedRestaurant => Icons.inventory_2_outlined,
  DeliveryStage.pickedUp => Icons.route_outlined,
  DeliveryStage.onTheWay => Icons.flag_outlined,
  DeliveryStage.reachedCustomer => Icons.verified_user_rounded,
  DeliveryStage.delivered => Icons.check_circle_rounded,
};

String _successMessageForStage(DeliveryStage stage) => switch (stage) {
  DeliveryStage.assigned => 'Order accepted and moved into your lane.',
  DeliveryStage.accepted => 'Restaurant arrival confirmed.',
  DeliveryStage.reachedRestaurant => 'Pickup confirmed and route unlocked.',
  DeliveryStage.pickedUp => 'Delivery is now on the way.',
  DeliveryStage.onTheWay => 'Customer arrival checkpoint confirmed.',
  DeliveryStage.reachedCustomer => 'Delivery completed successfully.',
  DeliveryStage.delivered => 'Delivery already completed.',
};

String _stageLabel(DeliveryStage stage) => switch (stage) {
  DeliveryStage.assigned => 'Assigned',
  DeliveryStage.accepted => 'Accepted',
  DeliveryStage.reachedRestaurant => 'At pickup',
  DeliveryStage.pickedUp => 'Picked up',
  DeliveryStage.onTheWay => 'On route',
  DeliveryStage.reachedCustomer => 'At customer',
  DeliveryStage.delivered => 'Delivered',
};

class _QueuedOrderTile extends StatelessWidget {
  const _QueuedOrderTile({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.call_split_rounded, color: AppColors.sky),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.restaurantName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  order.customerName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(Formatters.currency(order.payout + order.tip)),
        ],
      ),
    );
  }
}

class _DeliverySkeleton extends StatelessWidget {
  const _DeliverySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: const [
        ShimmerCard(height: 260),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 320),
      ],
    );
  }
}



