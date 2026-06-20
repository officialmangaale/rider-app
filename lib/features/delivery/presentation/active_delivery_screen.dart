import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_routes.dart';
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
        final navigationTarget = _navigationTargetFor(order);
        final isContactingPickup = _shouldContactPickup(order);
        final callPhone =
            (isContactingPickup ? order.restaurantPhone : order.customerPhone)
                ?.trim();
        final navigationLat = navigationTarget == _NavigationTarget.pickup
            ? order.pickupLatitude
            : order.dropLatitude;
        final navigationLng = navigationTarget == _NavigationTarget.pickup
            ? order.pickupLongitude
            : order.dropLongitude;
        final navigationAddress = navigationTarget == _NavigationTarget.pickup
            ? order.pickupAddress
            : order.dropAddress;
        final canCall = callPhone != null && callPhone.isNotEmpty;
        final canNavigate =
            navigationTarget != _NavigationTarget.none &&
            _hasNavigationTarget(
              navigationLat,
              navigationLng,
              navigationAddress,
            );

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
                              '${order.customerName ?? "Customer"} · ID: ${order.orderId}',
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
                  if (canCall || canNavigate) ...[
                    Row(
                      children: [
                        if (canCall)
                          Expanded(
                            child: SecondaryButton(
                              label: 'Call',
                              icon: Icons.call_rounded,
                              onPressed: () => _launchPhone(context, callPhone),
                            ),
                          ),
                        if (canCall && canNavigate)
                          const SizedBox(width: AppSpacing.md),
                        if (canNavigate)
                          Expanded(
                            child: SecondaryButton(
                              label: 'Navigate',
                              icon: Icons.navigation_rounded,
                              onPressed: () => _launchMaps(
                                context,
                                ref,
                                navigationLat,
                                navigationLng,
                                navigationAddress,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
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

// ── Advance button ─────────────────────────────────────────────────────────

bool _isUsableCoordinate(double latitude, double longitude) {
  return latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      latitude != 0 &&
      longitude != 0;
}

bool _hasNavigationTarget(double latitude, double longitude, String address) {
  return _isUsableCoordinate(latitude, longitude) ||
      _hasMeaningfulAddress(address);
}

Future<void> _launchPhone(BuildContext context, String phone) async {
  final uri = Uri.parse('tel:$phone');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
    return;
  }
  if (!context.mounted) return;
  showLuxurySnackBar(context, 'Could not open phone dialer');
}

Future<void> _launchMaps(
  BuildContext context,
  WidgetRef ref,
  double latitude,
  double longitude,
  String address,
) async {
  final result = await ref
      .read(mapLauncherServiceProvider)
      .openPoint(latitude: latitude, longitude: longitude, address: address);
  if (!context.mounted || result.opened) {
    return;
  }

  final fallbackText = _hasMeaningfulAddress(result.displayAddress ?? address)
      ? (result.displayAddress ?? address).trim()
      : '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  showPremiumBottomSheet(
    context: context,
    title: 'Route details',
    subtitle:
        'Maps are unavailable right now. Use this destination in your map app.',
    child: SelectableText(
      fallbackText,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );
}

bool _hasMeaningfulAddress(String address) {
  final normalized = address.trim().toLowerCase();
  return normalized.isNotEmpty && !normalized.contains('not available');
}

enum _NavigationTarget { pickup, drop, none }

String _normalizedDeliveryStatus(String status) => status.trim().toLowerCase();

bool _shouldContactPickup(ActiveDeliveryOrderModel order) {
  switch (_normalizedDeliveryStatus(order.deliveryStatus)) {
    case 'ready':
    case 'rider_assigned':
    case 'rider_arrived_restaurant':
      return true;
    default:
      return false;
  }
}

_NavigationTarget _navigationTargetFor(ActiveDeliveryOrderModel order) {
  switch (_normalizedDeliveryStatus(order.deliveryStatus)) {
    case 'ready':
    case 'rider_assigned':
      return _NavigationTarget.pickup;
    case 'picked_up':
    case 'on_the_way':
    case 'out_for_delivery':
      return _NavigationTarget.drop;
    default:
      return _NavigationTarget.none;
  }
}

void _debugDeliveryAction(String message) {
  assert(() {
    debugPrint('[ActiveDelivery] $message');
    return true;
  }());
}

class _AdvanceButton extends ConsumerStatefulWidget {
  const _AdvanceButton({required this.order});
  final ActiveDeliveryOrderModel order;

  @override
  ConsumerState<_AdvanceButton> createState() => _AdvanceButtonState();
}

class _AdvanceButtonState extends ConsumerState<_AdvanceButton> {
  bool _loading = false;

  String get _label {
    if (_loading) return 'Updating...';
    if (_normalizedDeliveryStatus(widget.order.deliveryStatus) == 'delivered') {
      return widget.order.isRestaurantOwned ? 'Back to Orders' : 'Back to Home';
    }
    return nextDeliveryActionFor(widget.order)?.label ?? 'Refresh status';
  }

  DeliveryAdvanceAction? get _action => nextDeliveryActionFor(widget.order);

  @override
  Widget build(BuildContext context) {
    final isDone =
        _normalizedDeliveryStatus(widget.order.deliveryStatus) == 'delivered';
    final action = _action;
    final IconData icon;
    if (isDone) {
      icon = Icons.check_circle_rounded;
    } else if (action == null) {
      icon = Icons.refresh_rounded;
    } else {
      icon = Icons.arrow_forward_rounded;
    }

    return PrimaryButton(
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
    );
  }

  Future<void> _advance() async {
    final action = _action;
    if (action == null) {
      setState(() => _loading = true);
      _debugDeliveryAction(
        'refresh only mode=${widget.order.isRestaurantOwned ? 'restaurant_owned' : 'platform'} '
        'orderId=${widget.order.orderId} current=${widget.order.deliveryStatus}',
      );
      try {
        await ref
            .read(riderDeliveryControllerProvider.notifier)
            .refreshActiveOrder();
      } finally {
        if (mounted) setState(() => _loading = false);
      }
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
      if (!mounted) return;
      showLuxurySnackBar(
        context,
        'Could not update order. Refreshing the valid next step.',
        isError: true,
      );
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
