import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/responsive.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_cards.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(riderHubControllerProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return PremiumScaffold(
      child: hub.when(
        loading: () => const _DashboardSkeleton(),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: EmptyStateCard(
              icon: Icons.error_outline_rounded,
              title: 'Dashboard unavailable',
              message: 'The live rider hub could not load right now. Pull to retry.',
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = Responsive.isDesktop(constraints.maxWidth);
              final wideCard = isDesktop
                  ? (constraints.maxWidth - 80) / 2
                  : constraints.maxWidth;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  120,
                ),
                children: [
                  _HeroHeader(
                    profile: state.profile,
                    shiftSummary: state.shiftSummary,
                    unreadCount: unreadCount,
                    onNotificationTap: () => context.push('/notifications'),
                    onToggleOnline: (value) async {
                      try {
                        await ref
                            .read(riderHubControllerProvider.notifier)
                            .setAvailabilityStatus(
                              value
                                  ? AvailabilityStatus.online
                                  : AvailabilityStatus.offline,
                            );
                      } on ApiException catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        showLuxurySnackBar(context, error.message);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      SizedBox(
                        width: wideCard > 400 ? 220 : wideCard,
                        child: MetricCard(
                          label: 'Today earnings',
                          value: Formatters.currency(
                            state.profile.todayEarnings,
                          ),
                          icon: Icons.currency_rupee_rounded,
                          accent: AppColors.gold,
                          trend: '+12%',
                        ),
                      ),
                      SizedBox(
                        width: wideCard > 400 ? 220 : wideCard,
                        child: MetricCard(
                          label: 'Completed deliveries',
                          value: '${state.profile.completedDeliveries}',
                          icon: Icons.local_shipping_rounded,
                          accent: AppColors.emerald,
                          trend: '+4 today',
                        ),
                      ),
                      SizedBox(
                        width: wideCard > 400 ? 220 : wideCard,
                        child: MetricCard(
                          label: 'Active orders',
                          value:
                              '${state.profile.activeDeliveries + state.queuedOrders.length}',
                          icon: Icons.route_rounded,
                          accent: AppColors.ember,
                          trend: state.queuedOrders.isEmpty
                              ? 'Single run'
                              : 'Stacked lane',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Live performance',
                    subtitle:
                        'Stay ahead of the rush with current shift visibility.',
                    trailing: TextButton(
                      onPressed: () => context.push('/availability'),
                      child: const Text('Shift controls'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      SizedBox(
                        width: isDesktop
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                        child: _PerformancePanel(state: state),
                      ),
                      SizedBox(
                        width: isDesktop
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                        child: _QuickActionsPanel(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Current delivery lane',
                    subtitle: state.activeOrder == null
                        ? 'Accept a new premium order to begin.'
                        : 'Jump back into your active route and rider tasks.',
                    trailing: TextButton(
                      onPressed: () => context.go('/delivery'),
                      child: const Text('Open'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (state.activeOrder == null)
                    EmptyStateCard(
                      icon: Icons.route_outlined,
                      title: 'No active delivery',
                      message:
                          'Your next assigned order will appear here once accepted from the requests screen.',
                      action: PrimaryButton(
                        label: 'View Requests',
                        icon: Icons.bolt_rounded,
                        onPressed: () => context.go('/requests'),
                      ),
                    )
                  else
                    _CurrentOrderPreview(order: state.activeOrder!),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Earnings pulse',
                    subtitle: 'Weekly momentum with incentive-ready pacing.',
                    trailing: TextButton(
                      onPressed: () => context.go('/earnings'),
                      child: const Text('Analytics'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InsightChart(points: state.earnings.trend),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.profile,
    required this.shiftSummary,
    required this.unreadCount,
    required this.onNotificationTap,
    required this.onToggleOnline,
  });

  final RiderProfile profile;
  final ShiftSummary shiftSummary;
  final int unreadCount;
  final VoidCallback onNotificationTap;
  final ValueChanged<bool> onToggleOnline;

  @override
  Widget build(BuildContext context) {
    final isOnline = shiftSummary.status == AvailabilityStatus.online ||
        shiftSummary.status == AvailabilityStatus.busy;
    final statusColor = switch (shiftSummary.status) {
      AvailabilityStatus.online => AppColors.emerald,
      AvailabilityStatus.busy => AppColors.ember,
      AvailabilityStatus.onBreak => AppColors.sky,
      AvailabilityStatus.offline => AppColors.danger,
    };

    return PremiumProfileCard(
      initials: profile.avatarInitials,
      title: 'Good evening, ${profile.name.split(' ').first}',
      subtitle: '${profile.vehicleType} - ${profile.city}',
      accent: AppColors.gold,
      supportingText: shiftSummary.statusMessage,
      trailing: Stack(
        children: [
          IconButton(
            onPressed: onNotificationTap,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ember,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$unreadCount',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: switch (shiftSummary.status) {
                  AvailabilityStatus.online => 'Online',
                  AvailabilityStatus.busy => 'Busy',
                  AvailabilityStatus.onBreak => 'On break',
                  AvailabilityStatus.offline => 'Offline',
                },
                color: statusColor,
                icon: Icons.circle,
              ),
              const Spacer(),
              PremiumStatusToggle(
                label: 'Rider mode',
                value: isOnline,
                onChanged: onToggleOnline,
                activeLabel: 'Live',
                inactiveLabel: 'Paused',
                accent: AppColors.emerald,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Shift ${Formatters.time(shiftSummary.shiftStart)} - ${Formatters.time(shiftSummary.shiftEnd)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Preferred window: ${shiftSummary.preferredWindow}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PerformancePanel extends StatelessWidget {
  const _PerformancePanel({required this.state});

  final RiderHubState state;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.ember,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Shift summary',
            subtitle:
                'Breaks, stacked queue, and payout readiness at a glance.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoRow(
            label: 'Break minutes used',
            value: '${state.shiftSummary.breakMinutes} min',
          ),
          _InfoRow(
            label: 'Queue depth',
            value: '${state.queuedOrders.length} orders',
          ),
          _InfoRow(
            label: 'Wallet pending',
            value: Formatters.currency(state.payoutSummary.pendingPayout),
          ),
          _InfoRow(
            label: 'Rating',
            value: state.profile.rating.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.bolt_rounded, 'Requests', 'Open nearby offers', '/requests', AppColors.gold),
      (Icons.history_rounded, 'History', 'Review completed drops', '/history', AppColors.sky),
      (Icons.notifications_rounded, 'Alerts', 'Dispatch updates', '/notifications', AppColors.ember),
      (Icons.schedule_rounded, 'Availability', 'Shift controls', '/availability', AppColors.emerald),
      (Icons.account_balance_wallet_rounded, 'Wallet', 'Payout overview', '/wallet', AppColors.gold),
      (Icons.support_agent_rounded, 'Support', 'Help center', '/support', AppColors.ember),
      (Icons.star_rate_rounded, 'Ratings', 'Service score', '/ratings', AppColors.sky),
      (Icons.settings_rounded, 'Settings', 'App controls', '/settings', AppColors.emerald),
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Quick actions',
            subtitle: 'Jump into the rider tools used most often during the shift.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final item in items)
                PremiumQuickActionTile(
                  width: 152,
                  icon: item.$1,
                  label: item.$2,
                  subtitle: item.$3,
                  accent: item.$5,
                  onTap: () => context.push(item.$4),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrentOrderPreview extends StatelessWidget {
  const _CurrentOrderPreview({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return PremiumOrderCard(
      order: order,
      accent: AppColors.ember,
      subtitle: 'Drop for ${order.customerName}',
      showNotes: false,
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
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: const [
        ShimmerCard(height: 220),
        SizedBox(height: AppSpacing.xl),
        ShimmerCard(height: 150),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 150),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 190),
      ],
    );
  }
}






