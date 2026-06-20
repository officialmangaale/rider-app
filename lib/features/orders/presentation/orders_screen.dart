import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../../delivery/models/delivery_models.dart';
import '../../delivery/providers/rider_delivery_provider.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryState = ref.watch(riderDeliveryControllerProvider);
    final requests = deliveryState.pendingRequests;

    return PremiumScaffold(
      title: 'Requests',
      subtitle: 'Incoming delivery requests waiting for your response.',
      onRefresh: () => ref
          .read(riderDeliveryControllerProvider.notifier)
          .refreshPendingRequests(),
      child: RefreshIndicator(
        onRefresh: () => ref
            .read(riderDeliveryControllerProvider.notifier)
            .refreshPendingRequests(),
        child: requests.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                children: [
                  EmptyStateCard(
                    icon: deliveryState.isOnline
                        ? Icons.delivery_dining_rounded
                        : Icons.power_settings_new_rounded,
                    title: deliveryState.isOnline
                        ? 'No incoming requests'
                        : 'You are offline',
                    subtitle:
                        deliveryState.requestErrorMessage ??
                        (deliveryState.isOnline
                            ? 'New orders will appear here when dispatch assigns them.'
                            : 'Go online from Home or Availability to receive delivery requests.'),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                itemCount: requests.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  return _IncomingRequestCard(request: requests[index]);
                },
              ),
      ),
    );
  }
}

class _IncomingRequestCard extends ConsumerStatefulWidget {
  const _IncomingRequestCard({required this.request});

  final RiderOrderRequestModel request;

  @override
  ConsumerState<_IncomingRequestCard> createState() =>
      _IncomingRequestCardState();
}

class _IncomingRequestCardState extends ConsumerState<_IncomingRequestCard> {
  Timer? _timer;
  bool _acting = false;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final remaining = widget.request.expiresAt
        .difference(DateTime.now().toUtc())
        .inSeconds;
    if (!mounted) return;
    setState(() => _remainingSeconds = remaining < 0 ? 0 : remaining);
    if (remaining <= 0) {
      _timer?.cancel();
      unawaited(
        ref
            .read(riderDeliveryControllerProvider.notifier)
            .refreshPendingRequests(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return GlassCard(
      accent: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (request.restaurantName ?? '').isEmpty
                          ? 'Restaurant'
                          : request.restaurantName!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      Formatters.distance(request.distanceKm),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: '${_remainingSeconds}s',
                color: _remainingSeconds > 15
                    ? AppColors.emerald
                    : AppColors.ember,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _AddressLine(
            icon: Icons.storefront_rounded,
            color: AppColors.riderPrimary,
            text: request.pickupAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AddressLine(
            icon: Icons.location_on_rounded,
            color: AppColors.ember,
            text: request.dropAddress,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _MetricPill(
                label: 'Payout',
                value: Formatters.currency(request.amount),
              ),
              const SizedBox(width: AppSpacing.sm),
              _MetricPill(label: 'Order', value: '#${request.orderId}'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Reject',
                  icon: Icons.close_rounded,
                  onPressed: _acting ? null : _reject,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: _acting ? 'Accepting...' : 'Accept',
                  icon: Icons.check_circle_rounded,
                  expanded: true,
                  onPressed: _acting ? null : _accept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _accept() async {
    setState(() => _acting = true);
    try {
      await ref
          .read(riderDeliveryControllerProvider.notifier)
          .acceptRequest(widget.request.requestId);
      if (mounted) context.go(AppRoutes.delivery);
    } on ApiException catch (error) {
      if (mounted) {
        showLuxurySnackBar(context, error.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        showLuxurySnackBar(
          context,
          'Could not accept this request. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _acting = true);
    try {
      await ref
          .read(riderDeliveryControllerProvider.notifier)
          .rejectRequest(widget.request.requestId);
    } on ApiException catch (error) {
      if (mounted) {
        showLuxurySnackBar(context, error.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        showLuxurySnackBar(
          context,
          'Could not reject this request. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.frost.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
