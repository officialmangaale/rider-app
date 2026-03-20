import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_cards.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(riderHubControllerProvider);

    return PremiumScaffold(
      title: 'New order requests',
      subtitle:
          'Review premium orders quickly before the dispatch timer expires.',
      child: hub.when(
        loading: () => const _OrdersSkeleton(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: EmptyStateCard(
              icon: Icons.error_outline_rounded,
              title: 'Requests unavailable',
              message: 'We could not load the incoming rider queue right now.',
              action: PrimaryButton(
                label: 'Retry',
                onPressed: () =>
                    ref.read(riderHubControllerProvider.notifier).refreshHub(),
              ),
            ),
          ),
        ),
        data: (state) => RefreshIndicator(
          onRefresh: () =>
              ref.read(riderHubControllerProvider.notifier).refreshHub(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              120,
            ),
            children: [
              if (state.queuedOrders.isNotEmpty) ...[
                GlassCard(
                  accent: AppColors.sky,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.stacked_line_chart_rounded,
                        color: AppColors.sky,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          '${state.queuedOrders.length} accepted orders are stacked after your current delivery.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (state.incomingOrders.isEmpty)
                EmptyStateCard(
                  icon: Icons.bolt_outlined,
                  title: 'No fresh requests',
                  message:
                      'The premium dispatch lane is calm right now. Pull to refresh or stay online.',
                  action: PrimaryButton(
                    label: 'Refresh queue',
                    icon: Icons.refresh_rounded,
                    onPressed: () => ref
                        .read(riderHubControllerProvider.notifier)
                        .refreshHub(),
                  ),
                )
              else
                for (final entry in state.incomingOrders.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _OrderRequestCard(order: entry.$2)
                        .animate()
                        .fadeIn(delay: (entry.$1 * 90).ms)
                        .slideY(begin: 0.08),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderRequestCard extends ConsumerWidget {
  const _OrderRequestCard({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(riderHubControllerProvider.notifier);

    return PremiumOrderCard(
      order: order,
      subtitle: 'Customer: ${order.customerName}',
      trailing: _CountdownBadge(initialSeconds: order.countdownSeconds),
      secondaryAction: SecondaryButton(
        label: 'Reject',
        icon: Icons.close_rounded,
        expanded: true,
        onPressed: () async {
          try {
            await controller.rejectOrder(
              order.assignmentId ?? order.id,
              reason: 'Too far from restaurant',
            );
            if (!context.mounted) {
              return;
            }
            showLuxurySnackBar(
              context,
              'Request dismissed from your queue.',
            );
          } on ApiException catch (error) {
            if (!context.mounted) {
              return;
            }
            showLuxurySnackBar(context, error.message);
          }
        },
      ),
      primaryAction: PrimaryButton(
        label: 'Accept',
        icon: Icons.check_rounded,
        expanded: true,
        onPressed: () async {
          try {
            await controller.acceptOrder(order.assignmentId ?? order.id);
            if (!context.mounted) {
              return;
            }
            final activeId = ref.read(riderHubStateProvider)?.activeOrder?.id;
            showLuxurySnackBar(
              context,
              'Order accepted${activeId == order.id ? ' and moved to active delivery.' : ' and stacked after your current drop.'}',
            );
          } on ApiException catch (error) {
            if (!context.mounted) {
              return;
            }
            showLuxurySnackBar(context, error.message);
          }
        },
      ),
    );
  }
}

class _CountdownBadge extends StatefulWidget {
  const _CountdownBadge({required this.initialSeconds});

  final int initialSeconds;

  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge> {
  late int _seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _seconds <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _seconds < 15 ? AppColors.danger : AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${_seconds}s',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: const [
        ShimmerCard(height: 260),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 260),
      ],
    );
  }
}

