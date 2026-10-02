import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../models/delivery_models.dart';
import '../models/delivery_request_intent.dart';
import '../providers/request_notification_provider.dart';
import '../providers/rider_delivery_provider.dart';

class IncomingOrderRequestSheet extends ConsumerStatefulWidget {
  const IncomingOrderRequestSheet({
    super.key,
    required this.request,
    this.initialAction = DeliveryRequestAction.open,
  });

  final RiderOrderRequestModel request;
  final DeliveryRequestAction initialAction;

  static Future<void> show(
    BuildContext context,
    RiderOrderRequestModel request, {
    DeliveryRequestAction initialAction = DeliveryRequestAction.open,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => IncomingOrderRequestSheet(
        request: request,
        initialAction: initialAction,
      ),
    );
  }

  @override
  ConsumerState<IncomingOrderRequestSheet> createState() =>
      _IncomingOrderRequestSheetState();
}

class _IncomingOrderRequestSheetState
    extends ConsumerState<IncomingOrderRequestSheet> {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isLoading = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.request.expiresAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 86400);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _calculateRemainingTime();
      if (_closing) return;
      switch (widget.initialAction) {
        case DeliveryRequestAction.accept:
          unawaited(_acceptOrder());
        case DeliveryRequestAction.decline:
          unawaited(_rejectOrder());
        case DeliveryRequestAction.open:
          break;
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateRemainingTime();
    });
  }

  void _calculateRemainingTime() {
    final now = DateTime.now().toUtc();
    final remaining = widget.request.expiresAt.difference(now);
    final diff = (remaining.inMilliseconds / 1000).ceil();

    if (diff <= 0) {
      _timer?.cancel();
      if (mounted && !_isLoading && !_closing) {
        // Auto dismiss if expired
        _close();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order request expired')));
      }
    } else {
      if (mounted) {
        setState(() {
          _remainingSeconds = diff;
        });
      }
    }
  }

  void _close() {
    if (!mounted || _closing) return;
    _closing = true;
    final route = ModalRoute.of(context);
    if (route == null) return;
    final navigator = Navigator.of(context);
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _acceptOrder() async {
    if (_isLoading || _closing) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(riderDeliveryControllerProvider.notifier)
          .acceptRequest(widget.request.requestId);
      if (mounted) {
        final router = GoRouter.of(context);
        _close();
        // Go to active delivery screen (or home dashboard which routes to active)
        router.go(AppRoutes.delivery);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException
                  ? e.message
                  : 'Could not confirm acceptance. Refresh delivery status.',
            ),
          ),
        );
        _close();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectOrder() async {
    if (_isLoading || _closing) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(riderDeliveryControllerProvider.notifier)
          .rejectRequest(widget.request.requestId);
      _close();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Could not decline. Try again.',
            ),
          ),
        );
        if (error is ApiException &&
            (error.statusCode == 409 || error.statusCode == 404)) {
          _close();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _calculateRemainingTime();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // The app-wide host will validate and open the specifically tapped offer.
    ref.listen(deliveryRequestIntentProvider, (_, intent) {
      if (intent != null && !_isLoading) _close();
    });
    // Listen to pending requests to close automatically if expired or assigned to other
    ref.listen(
      riderDeliveryControllerProvider.select((s) => s.pendingRequests),
      (previous, next) {
        if (!next.any((r) => r.requestId == widget.request.requestId)) {
          if (mounted && !_isLoading && Navigator.canPop(context)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This request is no longer available.'),
              ),
            );
            _close();
          }
        }
      },
    );

    return PopScope(
      canPop: !_isLoading,
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.request.isGrocery
                                ? 'New Grocery Delivery'
                                : 'New Delivery Request',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (widget.request.isGrocery)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: _GroceryBadge(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ember.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_remainingSeconds s',
                        style: const TextStyle(
                          color: AppColors.ember,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.request.isGrocery
                                ? Icons.local_grocery_store_rounded
                                : Icons.storefront_rounded,
                            color: AppColors.riderPrimary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((widget.request.restaurantName ?? '')
                                    .isNotEmpty)
                                  Text(
                                    widget.request.restaurantName!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                Text(
                                  widget.request.pickupAddress,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 10.0,
                        ),
                        child: Icon(
                          Icons.more_vert,
                          size: 16,
                          color: AppColors.smoke,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.ember,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              widget.request.deliveryDistanceKm == null
                                  ? widget.request.dropAddress
                                  : 'Approx. ${widget.request.deliveryDistanceKm!.toStringAsFixed(0)} km from pickup',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order total',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          Formatters.currency(widget.request.amount),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.gold,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Distance to pickup',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          Formatters.distance(widget.request.distanceKm),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Decline',
                        onPressed: _isLoading ? null : _rejectOrder,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        label: 'Accept',
                        icon: Icons.check_circle_rounded,
                        onPressed: _isLoading ? null : _acceptOrder,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small, unmistakable mark that this pickup is a grocery shop rather than a
/// restaurant. The workflow underneath is identical.
class _GroceryBadge extends StatelessWidget {
  const _GroceryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('grocery_delivery_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.riderPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Grocery',
        style: TextStyle(
          color: AppColors.riderPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
