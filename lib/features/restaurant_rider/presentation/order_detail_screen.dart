import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
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
  String? _canonicalStatus;

  @override
  void initState() {
    super.initState();
    _canonicalStatus = _statusFromStage(widget.order.status);
    unawaited(_refreshCanonicalStatus());
  }

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

  Future<void> _launchMaps(
    double latitude,
    double longitude, {
    required String address,
  }) async {
    final result = await ref
        .read(mapLauncherServiceProvider)
        .openPoint(latitude: latitude, longitude: longitude, address: address);
    if (!mounted || result.opened) {
      return;
    }
    _showMapFallback(
      address: result.displayAddress ?? address,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> _markPickedUp() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(riderBackendApiProvider);
      final currentStatus = await _currentDeliveryStatus();
      if (!_canMarkPickedUp(currentStatus)) {
        if (mounted) {
          showLuxurySnackBar(
            context,
            'Order status changed. Refreshing the valid next step.',
          );
          ref.invalidate(activeOrdersProvider);
        }
        return;
      }
      _debugAction('picked_up', currentStatus);
      final response = await api.delivery.updateRiderOrderStatus(
        widget.order.id,
        deliveryStatus: 'picked_up',
      );
      _debugActionResult('picked_up', response.statusCode);
      if (mounted) {
        showLuxurySnackBar(context, 'Pickup confirmed');
        ref.invalidate(activeOrdersProvider);
        context.pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        if (error.statusCode == 409 || error.statusCode == 400) {
          await _refreshCanonicalStatus();
          if (!mounted) return;
        }
        ref.invalidate(activeOrdersProvider);
        showLuxurySnackBar(context, _statusErrorMessage(error), isError: true);
      }
    } catch (e) {
      if (mounted) {
        showLuxurySnackBar(context, 'Could not update order', isError: true);
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
      final currentStatus = await _currentDeliveryStatus();
      if (!_canMarkDelivered(currentStatus)) {
        if (mounted) {
          showLuxurySnackBar(
            context,
            currentStatus == 'rider_assigned'
                ? 'Confirm pickup before marking delivery complete.'
                : 'Order status changed. Refreshing the valid next step.',
          );
          ref.invalidate(activeOrdersProvider);
        }
        return;
      }
      final paymentCollected = _isCashPayment(widget.order.paymentMethod)
          ? true
          : null;
      _debugAction('delivered', currentStatus);
      final response = await api.delivery.updateRiderOrderStatus(
        widget.order.id,
        deliveryStatus: 'delivered',
        paymentCollected: paymentCollected,
      );
      _debugActionResult('delivered', response.statusCode);
      if (mounted) {
        showLuxurySnackBar(context, 'Order marked as delivered');
        ref.invalidate(activeOrdersProvider);
        ref.invalidate(deliveredOrdersProvider);
        context.pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        if (error.statusCode == 409 || error.statusCode == 400) {
          await _refreshCanonicalStatus();
          if (!mounted) return;
        }
        ref.invalidate(activeOrdersProvider);
        showLuxurySnackBar(context, _statusErrorMessage(error), isError: true);
      }
    } catch (e) {
      if (mounted) {
        showLuxurySnackBar(context, 'Could not update order', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _currentDeliveryStatus() async {
    final api = ref.read(riderBackendApiProvider);
    try {
      final response = await api.delivery.riderOrderDetail(widget.order.id);
      final raw = response.data;
      final order = _asMap(raw['order']);
      final status = _asString(
        _firstPresent([
          raw['delivery_status'],
          order['delivery_status'],
          raw['status'],
          order['status'],
        ]),
        fallback: _statusFromStage(widget.order.status),
      );
      _debugStatus(status, response.statusCode);
      if (mounted && status != _canonicalStatus) {
        setState(() => _canonicalStatus = status);
      }
      return status;
    } on ApiException catch (error) {
      _debugStatus('fallback:${widget.order.status.name}', error.statusCode);
      if (error.statusCode == 404) {
        final fallback = _statusFromStage(widget.order.status);
        if (mounted && fallback != _canonicalStatus) {
          setState(() => _canonicalStatus = fallback);
        }
        return fallback;
      }
      rethrow;
    }
  }

  Future<void> _refreshCanonicalStatus() async {
    try {
      await _currentDeliveryStatus();
    } catch (error) {
      _debugRestaurantFlow(
        'status refresh failed orderId=${widget.order.id} error=$error',
      );
    }
  }

  void _showMapFallback({
    required String address,
    required double latitude,
    required double longitude,
  }) {
    final hasAddress = address.trim().isNotEmpty;
    final fallbackText = hasAddress
        ? address.trim()
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

  void _debugStatus(String status, int? statusCode) {
    _debugRestaurantFlow(
      'status refresh orderId=${widget.order.id} status=$status '
      'http=${statusCode ?? 'unknown'} assignmentType=${widget.order.assignmentType}',
    );
  }

  void _debugAction(String nextStatus, String currentStatus) {
    _debugRestaurantFlow(
      'action orderId=${widget.order.id} currentStatus=$currentStatus '
      'nextStatus=$nextStatus endpoint=/api/v1/riders/orders/:orderId/status',
    );
  }

  void _debugActionResult(String nextStatus, int? statusCode) {
    _debugRestaurantFlow(
      'action result orderId=${widget.order.id} nextStatus=$nextStatus '
      'http=${statusCode ?? 'unknown'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final currentStatus = (_canonicalStatus ?? _statusFromStage(order.status))
        .toLowerCase();
    final isPickedUp =
        currentStatus == 'picked_up' ||
        currentStatus == 'on_the_way' ||
        currentStatus == 'out_for_delivery';
    final isAssigned =
        currentStatus == 'rider_assigned' ||
        currentStatus == 'rider_arrived_restaurant';
    final isDelivered = currentStatus == 'delivered';
    final canCallRestaurant = order.restaurantPhone.trim().isNotEmpty;
    final canCallCustomer = order.customerPhone.trim().isNotEmpty;
    final canNavigatePickup = _hasNavigationTarget(
      order.restaurantLat,
      order.restaurantLng,
      order.pickupAddress,
    );
    final canNavigateDrop = _hasNavigationTarget(
      order.deliveryLat,
      order.deliveryLng,
      order.dropAddress,
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
            if (isDelivered)
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
                  if (canCallRestaurant ||
                      (isAssigned && canNavigatePickup)) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        if (canCallRestaurant)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _launchPhone(order.restaurantPhone),
                              icon: const Icon(Icons.phone),
                              label: const Text('Call restaurant'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        if (canCallRestaurant &&
                            isAssigned &&
                            canNavigatePickup)
                          const SizedBox(width: AppSpacing.sm),
                        if (isAssigned && canNavigatePickup)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _launchMaps(
                                order.restaurantLat,
                                order.restaurantLng,
                                address: order.pickupAddress,
                              ),
                              icon: const Icon(Icons.map),
                              label: const Text('Route'),
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
                  if (canCallCustomer || (isPickedUp && canNavigateDrop)) ...[
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
                        if (canCallCustomer && isPickedUp && canNavigateDrop)
                          const SizedBox(width: AppSpacing.sm),
                        if (isPickedUp && canNavigateDrop)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _launchMaps(
                                order.deliveryLat,
                                order.deliveryLng,
                                address: order.dropAddress,
                              ),
                              icon: const Icon(Icons.map),
                              label: const Text('Route'),
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
                  'Confirm Pickup',
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

bool _hasNavigationTarget(double latitude, double longitude, String address) {
  final normalizedAddress = address.trim().toLowerCase();
  final hasAddress =
      normalizedAddress.isNotEmpty &&
      !normalizedAddress.contains('not available');
  return _hasUsableCoordinate(latitude, longitude) || hasAddress;
}

bool _canMarkPickedUp(String status) {
  return status == 'ready' ||
      status == 'rider_assigned' ||
      status == 'rider_arrived_restaurant';
}

bool _canMarkDelivered(String status) {
  return status == 'picked_up' || status == 'on_the_way';
}

bool _isCashPayment(String paymentMethod) {
  final normalized = paymentMethod.trim().toLowerCase();
  return normalized == 'cash' || normalized == 'cod';
}

String _statusFromStage(DeliveryStage stage) {
  switch (stage) {
    case DeliveryStage.assigned:
    case DeliveryStage.accepted:
      return 'rider_assigned';
    case DeliveryStage.reachedRestaurant:
      return 'rider_arrived_restaurant';
    case DeliveryStage.pickedUp:
      return 'picked_up';
    case DeliveryStage.onTheWay:
    case DeliveryStage.reachedCustomer:
      return 'on_the_way';
    case DeliveryStage.delivered:
      return 'delivered';
  }
}

String _statusErrorMessage(ApiException error) {
  if (error.statusCode == 409 || error.statusCode == 400) {
    return 'Order status changed. Refreshing the valid next step.';
  }
  if (error.statusCode == 0) {
    return 'Network unavailable. Please try again.';
  }
  return 'Could not update order. Please retry.';
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const <String, dynamic>{};
}

Object? _firstPresent(List<Object?> values) {
  for (final value in values) {
    if (value == null) {
      continue;
    }
    if (value is String && value.trim().isEmpty) {
      continue;
    }
    return value;
  }
  return null;
}

String _asString(Object? value, {String fallback = ''}) {
  final present = _firstPresent([value]);
  return present == null ? fallback : '$present'.trim();
}

void _debugRestaurantFlow(String message) {
  assert(() {
    debugPrint('[RestaurantRiderOrder] $message');
    return true;
  }());
}
