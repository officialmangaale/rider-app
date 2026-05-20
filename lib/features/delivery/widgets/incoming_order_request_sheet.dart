import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../models/delivery_models.dart';
import '../providers/rider_delivery_provider.dart';

class IncomingOrderRequestSheet extends ConsumerStatefulWidget {
  const IncomingOrderRequestSheet({super.key, required this.request});

  final RiderOrderRequestModel request;

  static void show(BuildContext context, RiderOrderRequestModel request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => IncomingOrderRequestSheet(request: request),
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

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateRemainingTime();
    });
  }

  void _calculateRemainingTime() {
    final now = DateTime.now().toUtc();
    final diff = widget.request.expiresAt.difference(now).inSeconds;

    if (diff <= 0) {
      _timer?.cancel();
      if (mounted) {
        // Auto dismiss if expired
        Navigator.of(context).pop();
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _acceptOrder() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(riderDeliveryControllerProvider.notifier)
          .acceptRequest(widget.request.requestId);
      if (mounted) {
        Navigator.of(context).pop();
        // Go to active delivery screen (or home dashboard which routes to active)
        context.go(AppRoutes.delivery);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to accept order: $e')));
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectOrder() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(riderDeliveryControllerProvider.notifier)
          .rejectRequest(widget.request.requestId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reject order request')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to pending requests to close automatically if expired or assigned to other
    ref.listen(
      riderDeliveryControllerProvider.select((s) => s.pendingRequests),
      (previous, next) {
        if (!next.any((r) => r.requestId == widget.request.requestId)) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        }
      },
    );

    return Container(
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
                Text(
                  'New Delivery Request',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
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
                      const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.riderPrimary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((widget.request.restaurantName ?? '').isNotEmpty)
                              Text(
                                widget.request.restaurantName!,
                                style: Theme.of(context).textTheme.titleSmall,
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
                          widget.request.dropAddress,
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
                      'Est. Payout',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      Formatters.currency(widget.request.amount),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                      'Total Distance',
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
                    label: 'Reject',
                    onPressed: _isLoading ? null : _rejectOrder,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: 'Accept Order',
                    icon: Icons.check_circle_rounded,
                    onPressed: _isLoading ? null : _acceptOrder,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
