import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/delivery_helpers.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/app_models.dart';
import '../models/delivery_models.dart';
import '../providers/rider_delivery_provider.dart';
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
          if (deliveryState.activeOrderId != null) {
              await ref.read(riderDeliveryControllerProvider.notifier).fetchActiveOrder(deliveryState.activeOrderId!);
          }
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
                          label: DeliveryStatusHelper.getLabel(order.deliveryStatus),
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
                    StatusTimeline(
                      currentStage: order.stage,
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
                            onPressed: () async {
                               final phone = (order.deliveryStatus == 'rider_assigned' || order.deliveryStatus == 'rider_arrived_restaurant') ? order.restaurantPhone : order.customerPhone;
                               if (phone != null && phone.isNotEmpty) {
                                  final uri = Uri.parse('tel:$phone');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  } else {
                                     showLuxurySnackBar(context, 'Could not launch dialer for $phone');
                                  }
                               } else {
                                  showLuxurySnackBar(context, 'Phone number not available');
                               }
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Navigate',
                            icon: Icons.navigation_rounded,
                            onPressed: () async {
                              final lat = (order.deliveryStatus == 'rider_assigned' || order.deliveryStatus == 'rider_arrived_restaurant') ? order.pickupLatitude : order.dropLatitude;
                              final lng = (order.deliveryStatus == 'rider_assigned' || order.deliveryStatus == 'rider_arrived_restaurant') ? order.pickupLongitude : order.dropLongitude;
                              final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              } else {
                                showLuxurySnackBar(context, 'Could not open maps');
                              }
                            },
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
            ],
          );
      }(),
    );
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
  bool _loading = false;

  String get _label {
    if (_loading) return 'Updating...';
    switch (widget.order.deliveryStatus) {
      case 'rider_assigned':
        return 'I reached restaurant';
      case 'rider_arrived_restaurant':
        return 'Picked up order';
      case 'picked_up':
        return 'Start delivery';
      case 'on_the_way':
        return 'Mark delivered';
      case 'delivered':
        return 'Back to Home';
      default:
        return 'Advance Status';
    }
  }

  String? get _nextStatus {
    switch (widget.order.deliveryStatus) {
      case 'rider_assigned':
        return 'rider_arrived_restaurant';
      case 'rider_arrived_restaurant':
        return 'picked_up';
      case 'picked_up':
        return 'on_the_way';
      case 'on_the_way':
        return 'delivered';
      case 'delivered':
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.order.deliveryStatus == 'delivered';

    return PrimaryButton(
      label: _label,
      icon: isDone ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
      expanded: true,
      onPressed: _loading
          ? null
          : () async {
              if (isDone) {
                 context.go('/');
                 return;
              }
              await _advance();
            },
    );
  }

  Future<void> _advance() async {
    final status = _nextStatus;
    if (status == null) return;
    
    setState(() => _loading = true);
    try {
      await ref
          .read(riderDeliveryControllerProvider.notifier)
          .updateDeliveryStatus(status);
      if (mounted && status == 'delivered') {
          showLuxurySnackBar(context, 'Delivery marked as completed!');
      }
    } catch (e) {
      if (!mounted) return;
      showLuxurySnackBar(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
