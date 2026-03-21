import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/delivery_helpers.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_cards.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileControllerProvider);
    final availabilityAsync = ref.watch(availabilityControllerProvider);
    final deliveryAsync = ref.watch(deliveryControllerProvider);
    final earningsAsync = ref.watch(earningsControllerProvider);
    final ordersAsync = ref.watch(ordersControllerProvider);

    return PremiumScaffold(
      onRefresh: () async {
        await Future.wait([
          ref.read(profileControllerProvider.notifier).refresh(),
          ref.read(availabilityControllerProvider.notifier).refresh(),
          ref.read(deliveryControllerProvider.notifier).refresh(),
          ref.read(earningsControllerProvider.notifier).refresh(),
        ]);
      },
      child: profileAsync.when(
        loading: () => const _DashboardSkeleton(),
        error: (error, _) => Center(
          child: EmptyStateCard(
            icon: Icons.warning_rounded,
            title: 'Something went wrong',
            subtitle: error is ApiException
                ? error.message
                : 'Could not load dashboard.',
          ),
        ),
        data: (profile) {
          final shift = availabilityAsync.valueOrNull;
          final delivery = deliveryAsync.valueOrNull;
          final earningsState = earningsAsync.valueOrNull;
          final ordersState = ordersAsync.valueOrNull;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              // ── Hero header ──────────────────────────────────
              _HeroHeader(
                name: profile.name,
                initials: profile.avatarInitials,
                isOnline: shift?.status == AvailabilityStatus.online,
                onNotifications: () => context.push('/notifications'),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Shift toggle ─────────────────────────────────
              if (shift != null)
                GlassCard(
                  accent: shift.status == AvailabilityStatus.online
                      ? AppColors.emerald
                      : AppColors.smoke,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shift.status == AvailabilityStatus.online
                                  ? 'You are online'
                                  : 'You are offline',
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                            if (shift.statusMessage.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                shift.statusMessage,
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      PremiumStatusToggle(
                        label: 'Shift status',
                        value:
                            shift.status == AvailabilityStatus.online,
                        activeLabel: 'Online',
                        inactiveLabel: 'Offline',
                        onChanged: (active) async {
                          try {
                            await ref
                                .read(availabilityControllerProvider
                                    .notifier)
                                .setStatus(
                                  active
                                      ? AvailabilityStatus.online
                                      : AvailabilityStatus.offline,
                                );
                          } on ApiException catch (e) {
                            if (!context.mounted) return;
                            showLuxurySnackBar(context, e.message);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),

              // ── Metrics ──────────────────────────────────────
              if (earningsState?.earnings != null)
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    MetricCard(
                      label: 'Today',
                      value: Formatters.currency(
                        earningsState!.earnings!.daily,
                      ),
                      icon: Icons.account_balance_wallet_rounded,
                      accent: AppColors.gold,
                    ),
                    MetricCard(
                      label: 'Completed',
                      value: '${profile.completedDeliveries}',
                      icon: Icons.check_circle_rounded,
                      accent: AppColors.emerald,
                    ),
                    MetricCard(
                      label: 'Rating',
                      value: profile.rating.toStringAsFixed(1),
                      icon: Icons.star_rounded,
                      accent: AppColors.ember,
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),

              // ── Performance ──────────────────────────────────
              if (earningsState?.earnings != null)
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Performance',
                        subtitle:
                            'Earnings trend for your recent shifts.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SparklineMetricCard(
                        title: 'Weekly earnings',
                        value: Formatters.currency(
                          earningsState!.earnings!.weekly,
                        ),
                        trend: earningsState.earnings!.trend
                            .map((p) => p.amount)
                            .toList(),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),

              // ── Quick actions ────────────────────────────────
              _QuickActionsPanel(context: context),
              const SizedBox(height: AppSpacing.xl),

              // ── Active order preview ─────────────────────────
              if (delivery?.activeOrder != null)
                GlassCard(
                  accent: AppColors.gold,
                  onTap: () => context.go('/delivery'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Active delivery',
                        subtitle:
                            'Tap to view full delivery details.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              delivery!.activeOrder!.restaurantName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                          ),
                          StatusPill(
                            label: DeliveryHelpers.statusLabel(
                              delivery.activeOrder!.status,
                            ),
                            color: AppColors.gold,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${delivery.activeOrder!.customerName} · ${Formatters.distance(delivery.activeOrder!.distanceKm)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

              // ── Incoming orders badge ────────────────────────
              if ((ordersState?.incoming.length ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: GlassCard(
                    accent: AppColors.ember,
                    onTap: () => context.go('/requests'),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color:
                                AppColors.ember.withValues(alpha: 0.14),
                          ),
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                            color: AppColors.ember,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ordersState!.incoming.length} new request${ordersState.incoming.length > 1 ? 's' : ''}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to view and accept',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Hero header ────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.name,
    required this.initials,
    required this.isOnline,
    required this.onNotifications,
  });

  final String name;
  final String initials;
  final bool isOnline;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.riderPrimary.withValues(alpha: 0.12),
          child: Text(
            initials,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.riderPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Formatters.greeting(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(name, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
        IconButton(
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_outlined),
        ),
      ],
    );
  }
}

// ── Quick actions ──────────────────────────────────────────────────────────

class _QuickActionsPanel extends StatelessWidget {
  const _QuickActionsPanel({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Quick actions',
            subtitle: 'Jump to key rider operations.',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              PremiumQuickActionTile(
                icon: Icons.history_rounded,
                label: 'History',
                onTap: () => context.push('/history'),
              ),
              PremiumQuickActionTile(
                icon: Icons.attach_money_rounded,
                label: 'Earnings',
                onTap: () => context.go('/earnings'),
              ),
              PremiumQuickActionTile(
                icon: Icons.schedule_rounded,
                label: 'Availability',
                onTap: () => context.push('/availability'),
              ),
              PremiumQuickActionTile(
                icon: Icons.support_agent_rounded,
                label: 'Support',
                onTap: () => context.push('/support'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Skeleton ───────────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const ShimmerBlock(height: 56, radius: 22),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              const Expanded(child: ShimmerBlock(height: 80, radius: 18)),
              const SizedBox(width: AppSpacing.md),
              const Expanded(child: ShimmerBlock(height: 80, radius: 18)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const ShimmerBlock(height: 80, radius: 18),
          const SizedBox(height: AppSpacing.xl),
          const ShimmerCard(),
          const SizedBox(height: AppSpacing.xl),
          const ShimmerCard(),
        ],
      ),
    );
  }
}
