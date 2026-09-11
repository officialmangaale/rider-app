import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/map_launcher_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../presentation/providers/app_providers.dart';
import '../models/delivery_models.dart';
import '../providers/rider_delivery_provider.dart';
import '../services/delivery_action_policy.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class ActiveDeliveryScreen extends ConsumerWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryState = ref.watch(riderDeliveryControllerProvider);

    return PremiumScaffold(
      title: 'Active delivery',
      subtitle: 'Track and manage your current order.',
      onRefresh: () async {
        await ref
            .read(riderDeliveryControllerProvider.notifier)
            .refreshActiveOrder();
      },
      child: () {
        if (deliveryState.activeOrder == null) {
          return const Center(
            child: EmptyStateCard(
              icon: Icons.delivery_dining_rounded,
              title: 'No active delivery',
              subtitle: 'Accept an order from the Requests tab to start.',
            ),
          );
        }

        final order = deliveryState.activeOrder!;
        final headingToPickup = isHeadingToPickup(order);

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
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
                              order.restaurantName ?? 'Restaurant',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${_nonEmpty(order.customerName) ?? "Customer"} · ID: ${order.orderId}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: DeliveryStatusHelper.getLabel(
                          order.deliveryStatus,
                        ),
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
                        value: Formatters.currency(order.amount ?? 0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Stops: pickup, then drop ──────────────────
            DeliveryStopCard(
              title: 'Pickup',
              subtitle: 'Restaurant',
              icon: Icons.storefront_rounded,
              name: _nonEmpty(order.restaurantName) ?? 'Restaurant',
              address: order.pickupAddress,
              latitude: order.pickupLatitude,
              longitude: order.pickupLongitude,
              phone: order.restaurantPhone,
              navigateLabel: 'Navigate to restaurant',
              callLabel: 'Call restaurant',
              isCurrent: headingToPickup,
            ),
            const SizedBox(height: AppSpacing.lg),
            DeliveryStopCard(
              title: 'Drop',
              subtitle: 'Customer',
              icon: Icons.home_rounded,
              name: _nonEmpty(order.customerName) ?? 'Customer',
              address: order.dropAddress,
              latitude: order.dropLatitude,
              longitude: order.dropLongitude,
              phone: order.customerPhone,
              navigateLabel: 'Navigate to customer',
              callLabel: 'Call customer',
              isCurrent: !headingToPickup,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Order items ───────────────────────────────
            if (order.itemsSummary != null &&
                order.itemsSummary!.trim().isNotEmpty) ...[
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Order items',
                      subtitle: 'Summary of items to pick up.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      order.itemsSummary!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

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
                  StatusTimeline(currentStage: order.stage),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Next step ──────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Next step',
                    subtitle: 'Update the order as you go.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AdvanceButton(order: order),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      }(),
    );
  }
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Before pickup the rider is heading to the restaurant; after, to the customer.
bool isHeadingToPickup(ActiveDeliveryOrderModel order) {
  switch (order.deliveryStatus.trim().toLowerCase()) {
    case 'picked_up':
    case 'on_the_way':
    case 'out_for_delivery':
    case 'delivered':
      return false;
    default:
      return true;
  }
}

void _debugDeliveryAction(String message) {
  assert(() {
    debugPrint('[ActiveDelivery] $message');
    return true;
  }());
}

// ── Stop card ───────────────────────────────────────────────────────────────

/// One stop of the delivery: who, where, and buttons to navigate and call.
class DeliveryStopCard extends ConsumerWidget {
  const DeliveryStopCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.navigateLabel,
    required this.callLabel,
    required this.isCurrent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String navigateLabel;
  final String callLabel;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canNavigate =
        isUsableCoordinate(latitude, longitude) || isMeaningfulAddress(address);
    final callPhone = _nonEmpty(phone);
    final shownAddress = isMeaningfulAddress(address)
        ? address.trim()
        : 'Address not available';

    return GlassCard(
      accent: isCurrent ? AppColors.gold : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isCurrent ? AppColors.gold : null),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$title · $subtitle',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (isCurrent)
                const StatusPill(label: 'Current stop', color: AppColors.gold),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(name, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(shownAddress, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          // Stacked, full width: side by side, "Navigate to restaurant" and
          // "Call restaurant" overflow a phone-width card.
          SecondaryButton(
            label: navigateLabel,
            icon: Icons.navigation_rounded,
            expanded: true,
            onPressed: canNavigate ? () => _navigate(context, ref) : null,
          ),
          if (callPhone != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: callLabel,
              icon: Icons.call_rounded,
              expanded: true,
              onPressed: () => _call(context, callPhone),
            ),
          ],
          if (!canNavigate) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No location saved for this stop. Call to confirm the address.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _navigate(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(mapLauncherServiceProvider)
        .navigateTo(latitude: latitude, longitude: longitude, address: address);
    if (!context.mounted || result.opened) {
      return;
    }
    showLuxurySnackBar(
      context,
      'Could not open maps. Check that a browser or Google Maps is installed.',
      isError: true,
    );
  }

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // Falls through to the message below.
    }
    if (!context.mounted) return;
    showLuxurySnackBar(context, 'Could not open the phone dialer.');
  }
}

// ── Advance button ─────────────────────────────────────────────────────────

class _AdvanceButton extends ConsumerStatefulWidget {
  const _AdvanceButton({required this.order});
  final ActiveDeliveryOrderModel order;

  @override
  ConsumerState<_AdvanceButton> createState() => _AdvanceButtonState();
}

class _AdvanceButtonState extends ConsumerState<_AdvanceButton> {
  /// While the kitchen has not released the order, the pickup cannot
  /// succeed; refresh on this interval so the button unlocks by itself.
  static const _kitchenPollInterval = Duration(seconds: 15);

  bool _loading = false;
  Timer? _kitchenPoll;

  bool get _waitingForKitchen => isWaitingForKitchen(widget.order);

  @override
  void initState() {
    super.initState();
    _syncKitchenPoll();
  }

  @override
  void didUpdateWidget(covariant _AdvanceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncKitchenPoll();
  }

  @override
  void dispose() {
    _kitchenPoll?.cancel();
    super.dispose();
  }

  void _syncKitchenPoll() {
    if (_waitingForKitchen) {
      _kitchenPoll ??= Timer.periodic(_kitchenPollInterval, (_) {
        if (!mounted || _loading) return;
        unawaited(
          ref
              .read(riderDeliveryControllerProvider.notifier)
              .refreshActiveOrder(),
        );
      });
    } else {
      _kitchenPoll?.cancel();
      _kitchenPoll = null;
    }
  }

  String get _label {
    if (_loading) return 'Updating...';
    if (_normalizedStatus == 'delivered') {
      return widget.order.isRestaurantOwned ? 'Back to Orders' : 'Back to Home';
    }
    if (_waitingForKitchen) return 'Waiting for food to be ready';
    return nextDeliveryActionFor(widget.order)?.label ?? 'Refresh status';
  }

  String get _normalizedStatus =>
      widget.order.deliveryStatus.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final isDone = _normalizedStatus == 'delivered';
    final action = nextDeliveryActionFor(widget.order);
    final IconData icon;
    if (isDone) {
      icon = Icons.check_circle_rounded;
    } else if (action == null || _waitingForKitchen) {
      icon = Icons.refresh_rounded;
    } else {
      icon = Icons.arrow_forward_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_waitingForKitchen) ...[
          Text(
            'The restaurant is still preparing this order. Pickup unlocks as '
            'soon as they mark it ready.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        PrimaryButton(
          label: _label,
          icon: icon,
          expanded: true,
          onPressed: _loading
              ? null
              : () async {
                  if (isDone) {
                    final role = ref.read(sessionControllerProvider).role;
                    context.go(AppRoutes.resolvePostAuthRoute(role: role));
                    return;
                  }
                  await _advance();
                },
        ),
      ],
    );
  }

  Future<void> _refreshOnly() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(riderDeliveryControllerProvider.notifier)
          .refreshActiveOrder();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _advance() async {
    final action = nextDeliveryActionFor(widget.order);
    if (action == null || _waitingForKitchen) {
      _debugDeliveryAction(
        'refresh only orderId=${widget.order.orderId} '
        'current=${widget.order.deliveryStatus} '
        'waitingForKitchen=$_waitingForKitchen',
      );
      await _refreshOnly();
      return;
    }
    final status = action.nextStatus;

    setState(() => _loading = true);
    try {
      _debugDeliveryAction(
        'button chosen mode=${widget.order.isRestaurantOwned ? 'restaurant_owned' : 'platform'} '
        'orderId=${widget.order.orderId} deliveryOrderId=${widget.order.deliveryOrderId ?? 'none'} '
        'current=${widget.order.deliveryStatus} next=$status',
      );
      final needsCashConfirmation =
          status == 'delivered' && widget.order.requiresCashCollection;
      final paymentCollected = needsCashConfirmation
          ? await _confirmCashCollection()
          : null;
      if (needsCashConfirmation && paymentCollected != true) {
        return;
      }
      await ref
          .read(riderDeliveryControllerProvider.notifier)
          .updateDeliveryStatus(status, paymentCollected: paymentCollected);
      if (mounted && status == 'delivered') {
        showLuxurySnackBar(context, 'Delivery marked as completed!');
      }
    } catch (e) {
      _debugDeliveryAction(
        'update failed next=$status '
        '${e is ApiException ? 'code=${e.errorCode} reason=${e.message}' : 'error=$e'}',
      );
      if (!mounted) return;
      showLuxurySnackBar(context, deliveryUpdateErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _confirmCashCollection() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm cash collection'),
        content: Text(
          'Amount to collect: ${Formatters.currency(widget.order.amount ?? 0)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Collected'),
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
