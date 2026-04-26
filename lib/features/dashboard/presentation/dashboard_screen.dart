import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/delivery_helpers.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../core/services/fcm_service.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_cards.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../../delivery/models/delivery_models.dart';
import '../../delivery/providers/rider_delivery_provider.dart';
import '../../delivery/widgets/incoming_order_request_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final deliveryNotifier = ref.read(riderDeliveryControllerProvider.notifier);
      final deliveryState = ref.read(riderDeliveryControllerProvider);
      if (deliveryState.isOnline) {
         deliveryNotifier.refreshPendingRequests();
         if (deliveryState.activeOrderId != null) {
            deliveryNotifier.fetchActiveOrder(deliveryState.activeOrderId!);
         }
      }
    }
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    if (lat == 0 && lng == 0) return;
    final url = Uri.parse('google.navigation:q=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final iosUrl = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng');
      if (await canLaunchUrl(iosUrl)) {
        await launchUrl(iosUrl);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for new incoming requests
    ref.listen(riderDeliveryControllerProvider.select((s) => s.pendingRequests), (previous, next) {
      if (next.isNotEmpty) {
        final newRequests = next.where((r) => !(previous?.any((pr) => pr.requestId == r.requestId) ?? false));
        for (var request in newRequests) {
          IncomingOrderRequestSheet.show(context, request);
        }
      }
    });

    final profileAsync = ref.watch(profileControllerProvider);
    final deliveryAsync = ref.watch(deliveryControllerProvider);
    final earningsAsync = ref.watch(earningsControllerProvider);
    final ordersAsync = ref.watch(ordersControllerProvider);
    final riderDeliveryState = ref.watch(riderDeliveryControllerProvider);

    return PremiumScaffold(
      onRefresh: () async {
        await Future.wait([
          ref.read(profileControllerProvider.notifier).refresh(),
          ref.read(deliveryControllerProvider.notifier).refresh(),
          ref.read(earningsControllerProvider.notifier).refresh(),
          ref.read(riderDeliveryControllerProvider.notifier).refreshPendingRequests(),
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
                isOnline: riderDeliveryState.isOnline,
                onNotifications: () => context.push('/notifications'),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Shift toggle ─────────────────────────────────
              GlassCard(
                accent: riderDeliveryState.isOnline
                    ? AppColors.emerald
                    : AppColors.smoke,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riderDeliveryState.isOnline
                                ? 'You are online'
                                : 'You are offline',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            riderDeliveryState.isOnline
                                ? (riderDeliveryState.isAvailable ? 'Waiting for requests...' : 'On active delivery')
                                : 'Go online to receive delivery requests',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    PremiumStatusToggle(
                      label: 'Shift status',
                      value: riderDeliveryState.isOnline,
                      activeLabel: 'Online',
                      inactiveLabel: 'Offline',
                      onChanged: (active) async {
                        try {
                          await ref
                              .read(riderDeliveryControllerProvider.notifier)
                              .toggleOnline(active);
                        } catch (e) {
                          if (!context.mounted) return;
                          showLuxurySnackBar(context, 'Failed to change status: $e');
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
              if (riderDeliveryState.activeOrder != null)
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
                              riderDeliveryState.activeOrder!.restaurantName ?? 'Restaurant',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                          ),
                          StatusPill(
                            label: DeliveryStatusHelper.getLabel(
                              riderDeliveryState.activeOrder!.deliveryStatus,
                            ),
                            color: AppColors.gold,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${riderDeliveryState.activeOrder!.customerName ?? "Customer"} · Pick up',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PremiumButton(
                        label: riderDeliveryState.activeOrder!.deliveryStatus == 'rider_assigned'
                            ? 'Navigate to Pickup'
                            : 'Navigate to Delivery',
                        icon: Icons.navigation_rounded,
                        onPressed: () => _launchNavigation(
                          riderDeliveryState.activeOrder!.deliveryStatus == 'rider_assigned'
                              ? riderDeliveryState.activeOrder!.pickupLatitude
                              : riderDeliveryState.activeOrder!.dropLatitude,
                          riderDeliveryState.activeOrder!.deliveryStatus == 'rider_assigned'
                              ? riderDeliveryState.activeOrder!.pickupLongitude
                              : riderDeliveryState.activeOrder!.dropLongitude,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Incoming orders badge ────────────────────────
              if (riderDeliveryState.pendingRequests.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: GlassCard(
                    accent: AppColors.ember,
                    onTap: () {
                       // Optionally show the first request in the list
                       IncomingOrderRequestSheet.show(context, riderDeliveryState.pendingRequests.first);
                    },
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
                                '${riderDeliveryState.pendingRequests.length} new request${riderDeliveryState.pendingRequests.length > 1 ? 's' : ''}',
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
