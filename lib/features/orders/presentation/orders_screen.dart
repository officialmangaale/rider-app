import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/delivery_helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_cards.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersControllerProvider);

    return PremiumScaffold(
      title: 'Requests',
      subtitle: 'Incoming delivery requests waiting for your response.',
      onRefresh: () =>
          ref.read(ordersControllerProvider.notifier).refresh(),
      child: ordersAsync.when(
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
            title: 'Could not load requests',
            subtitle: error is ApiException
                ? error.message
                : 'Something went wrong.',
          ),
        ),
        data: (state) {
          if (state.incoming.isEmpty) {
            return const Center(
              child: EmptyStateCard(
                icon: Icons.delivery_dining_rounded,
                title: 'No incoming requests',
                subtitle:
                    'New orders will appear here when dispatch assigns them.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            itemCount: state.incoming.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final order = state.incoming[index];
              return _IncomingOrderCard(order: order);
            },
          );
        },
      ),
    );
  }
}

// ── Incoming order card with countdown ─────────────────────────────────────

class _IncomingOrderCard extends ConsumerStatefulWidget {
  const _IncomingOrderCard({required this.order});
  final dynamic order;

  @override
  ConsumerState<_IncomingOrderCard> createState() =>
      _IncomingOrderCardState();
}

class _IncomingOrderCardState extends ConsumerState<_IncomingOrderCard> {
  late int _remaining;
  Timer? _timer;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.order.countdownSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return GlassCard(
      accent: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with countdown.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.restaurantName as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${order.customerName} · ${Formatters.distance(order.distanceKm as double)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _remaining > 15
                      ? AppColors.emerald.withValues(alpha: 0.12)
                      : AppColors.ember.withValues(alpha: 0.12),
                ),
                child: Text(
                  '${_remaining}s',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _remaining > 15 ? AppColors.emerald : AppColors.ember,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Order details.
          Row(
            children: [
              _Chip(
                label: Formatters.currency(order.payout as num),
                color: AppColors.gold,
              ),
              const SizedBox(width: AppSpacing.sm),
              _Chip(
                label: '${order.itemsCount} items',
                color: AppColors.sky,
              ),
              const SizedBox(width: AppSpacing.sm),
              _Chip(
                label: DeliveryHelpers.priorityLabel(order.priority),
                color: AppColors.ember,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Accept / Reject buttons.
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Reject',
                  icon: Icons.close_rounded,
                  onPressed: _acting
                      ? null
                      : () => _showRejectSheet(context, order),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PrimaryButton(
                  label: _acting ? 'Accepting...' : 'Accept',
                  icon: Icons.check_rounded,
                  expanded: true,
                  onPressed: _acting ? null : () => _accept(order),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _accept(dynamic order) async {
    setState(() => _acting = true);
    try {
      await ref
          .read(ordersControllerProvider.notifier)
          .acceptOrder(order.assignmentId as String);
      // Set as active delivery.
      ref.read(deliveryControllerProvider.notifier).setActiveOrder(order);
      if (mounted) context.go('/delivery');
    } on ApiException catch (e) {
      if (!mounted) return;
      showLuxurySnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _showRejectSheet(BuildContext context, dynamic order) {
    String? selectedReason;
    showPremiumBottomSheet(
      context: context,
      title: 'Reject order',
      subtitle: 'Select a reason for declining this request.',
      child: StatefulBuilder(
        builder: (sheetCtx, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final reason in DeliveryHelpers.rejectReasons)
                RadioListTile<String>(
                  value: reason,
                  groupValue: selectedReason,
                  title: Text(reason),
                  onChanged: (v) =>
                      setModalState(() => selectedReason = v),
                ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Confirm reject',
                icon: Icons.close_rounded,
                expanded: true,
                onPressed: selectedReason == null
                    ? null
                    : () async {
                        Navigator.of(sheetCtx).pop();
                        try {
                          await ref
                              .read(ordersControllerProvider.notifier)
                              .rejectOrder(
                                order.assignmentId as String,
                                reason: selectedReason,
                              );
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showLuxurySnackBar(context, e.message);
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Chip helper ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
