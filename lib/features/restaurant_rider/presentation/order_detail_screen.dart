import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/core_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../providers/restaurant_rider_provider.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.order,
  });

  final String orderId;
  final DeliveryOrder order;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isLoading = false;

  Future<void> _launchPhone(String phone) async {
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      showLuxurySnackBar(context, 'Phone number is not available');
      return;
    }
    final url = Uri.parse('tel:$trimmedPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      return;
    }
    if (!mounted) return;
    showLuxurySnackBar(context, 'Could not open phone dialer');
  }

  Future<void> _launchMaps(double latitude, double longitude) async {
    if (!_hasUsableCoordinate(latitude, longitude)) {
      showLuxurySnackBar(context, 'Map location is not available');
      return;
    }
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    showLuxurySnackBar(context, 'Could not open maps on this device');
  }

  Future<void> _markPickedUp() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(riderBackendApiProvider);
      await api.delivery.pickedUp(widget.order.id);
      if (mounted) {
        showLuxurySnackBar(context, 'Order marked as picked up');
        ref.invalidate(activeOrdersProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showLuxurySnackBar(context, 'Failed to update order');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markDelivered() async {
    // Check COD
    if (widget.order.paymentMethod.toLowerCase() == 'cash' ||
        widget.order.paymentMethod.toLowerCase() == 'cod') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Cash Collection'),
          content: Text(
            'Amount to collect: ₹${widget.order.payout.toStringAsFixed(0)}\n\nWas cash collected?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, collected'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isLoading = true);
    try {
      final api = ref.read(riderBackendApiProvider);
      // Wait, user specified api expects payment_collected and notes
      // We are using existing rider-service which has /api/v1/delivery/:orderId/delivered without body
      // User says: POST /rider/orders/:orderId/deliver Request: { "payment_collected": true, "notes": "Delivered" }
      // The instruction: "Use existing rider-service endpoints for ... delivered orders ... If an endpoint is missing, add a TODO and list required backend change instead of calling restaurant-service directly."
      // So we use existing `api.delivery.delivered` which does not take a body.
      // TODO: Backend rider-service needs to support COD payment flag in delivered endpoint.
      await api.delivery.delivered(widget.order.id);
      if (mounted) {
        showLuxurySnackBar(context, 'Order marked as delivered');
        ref.invalidate(activeOrdersProvider);
        ref.invalidate(deliveredOrdersProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showLuxurySnackBar(context, 'Failed to update order');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isPickedUp =
        order.status == DeliveryStage.pickedUp ||
        order.status == DeliveryStage.onTheWay ||
        order.status == DeliveryStage.reachedCustomer;
    final isAssigned =
        order.status == DeliveryStage.assigned ||
        order.status == DeliveryStage.accepted ||
        order.status == DeliveryStage.reachedRestaurant;
    final canCallRestaurant = order.restaurantPhone.trim().isNotEmpty;
    final canNavigatePickup = _hasUsableCoordinate(
      order.restaurantLat,
      order.restaurantLng,
    );
    final canCallCustomer = order.customerPhone.trim().isNotEmpty;
    final canNavigateDrop = _hasUsableCoordinate(
      order.deliveryLat,
      order.deliveryLng,
    );

    return PremiumScaffold(
      title: 'Order #${order.orderCode}',
      subtitle: 'Manage delivery status',
      actions: [
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status Banner ─────────────────────────
            if (order.status == DeliveryStage.delivered)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.emerald,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'This order has been completed.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.emerald,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Restaurant Details ────────────────────
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.riderPrimary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 16,
                          color: AppColors.riderPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Restaurant Details',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    order.restaurantName,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    order.pickupAddress,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.smoke),
                  ),
                  if (canCallRestaurant || canNavigatePickup) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        if (canCallRestaurant)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _launchPhone(order.restaurantPhone),
                              icon: const Icon(Icons.phone),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        if (canCallRestaurant && canNavigatePickup)
                          const SizedBox(width: AppSpacing.sm),
                        if (canNavigatePickup)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _launchMaps(
                                order.restaurantLat,
                                order.restaurantLng,
                              ),
                              icon: const Icon(Icons.map),
                              label: const Text('Navigate'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Customer Details ──────────────────────
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.riderPrimary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: AppColors.riderPrimary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Customer Details',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    order.customerName,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    order.dropAddress,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.smoke),
                  ),
                  if (order.notes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              order.notes,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (canCallCustomer || canNavigateDrop) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        if (canCallCustomer)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _launchPhone(order.customerPhone),
                              icon: const Icon(Icons.phone),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        if (canCallCustomer && canNavigateDrop)
                          const SizedBox(width: AppSpacing.sm),
                        if (canNavigateDrop)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _launchMaps(
                                order.deliveryLat,
                                order.deliveryLng,
                              ),
                              icon: const Icon(Icons.map),
                              label: const Text('Navigate'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Payment Summary ───────────────────────
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.payments_outlined,
                          size: 16,
                          color: AppColors.emerald,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Payment Summary',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Method:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.smoke,
                        ),
                      ),
                      StatusPill(
                        label: order.paymentMethod.toUpperCase(),
                        color:
                            order.paymentMethod.toLowerCase() == 'cash' ||
                                order.paymentMethod.toLowerCase() == 'cod'
                            ? AppColors.warning
                            : AppColors.emerald,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount to Collect:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.smoke,
                        ),
                      ),
                      Text(
                        '₹${order.payout.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Items:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.smoke,
                        ),
                      ),
                      Text(
                        '${order.itemsCount}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ── Action Buttons ────────────────────────
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (isAssigned)
              FilledButton(
                onPressed: _markPickedUp,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppColors.riderPrimary,
                ),
                child: const Text(
                  'Mark Picked Up / Start Delivery',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              )
            else if (isPickedUp)
              FilledButton(
                onPressed: _markDelivered,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppColors.emerald,
                ),
                child: const Text(
                  'Mark Delivered',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

bool _hasUsableCoordinate(double latitude, double longitude) {
  return latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      latitude != 0 &&
      longitude != 0;
}
