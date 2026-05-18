import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../../delivery/providers/rider_delivery_provider.dart';
import '../../delivery/widgets/rider_location_status_card.dart';
import '../providers/restaurant_rider_provider.dart';
import '../widgets/rider_tab_state.dart';

class ActiveOrdersScreen extends ConsumerWidget {
  const ActiveOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrdersState = ref.watch(activeOrdersProvider);
    final riderDeliveryState = ref.watch(riderDeliveryControllerProvider);

    return PremiumScaffold(
      title: 'Active Orders',
      subtitle: 'Orders assigned to you',
      onRefresh: () async {
        ref.invalidate(activeOrdersProvider);
        await ref.read(activeOrdersProvider.future).catchError((_) {
          return <DeliveryOrder>[];
        });
      },
      child: activeOrdersState.when(
        data: (orders) {
          final showLocationStatus =
              riderDeliveryState.shouldShowLocationStatus;
          if (orders.isEmpty) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                if (showLocationStatus) ...[
                  const RiderLocationStatusCard(),
                  const SizedBox(height: AppSpacing.md),
                ],
                const RiderEmptyState(
                  icon: Icons.motorcycle_rounded,
                  title: 'No active orders right now',
                  message:
                      'You will see new orders here as soon as they are assigned.',
                  accent: AppColors.sky,
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              if (showLocationStatus) ...[
                const RiderLocationStatusCard(),
                const SizedBox(height: AppSpacing.md),
              ],
              for (final order in orders) ...[
                _ActiveOrderCard(order: order),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          final unauthorized = isUnauthorizedRiderError(err);
          return RiderErrorState(
            icon: unauthorized
                ? Icons.lock_outline_rounded
                : Icons.cloud_off_rounded,
            title: 'Could not load active orders',
            message: riderErrorMessage(err),
            actionLabel: unauthorized ? 'Sign in' : 'Retry',
            onRetry: () async {
              if (unauthorized) {
                await ref.read(sessionControllerProvider.notifier).logout();
                if (context.mounted) context.go(AppRoutes.login);
                return;
              }
              ref.invalidate(activeOrdersProvider);
            },
          );
        },
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});
  final DeliveryOrder order;

  Color _statusColor(DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.assigned:
      case DeliveryStage.accepted:
        return AppColors.warning;
      case DeliveryStage.pickedUp:
      case DeliveryStage.onTheWay:
        return AppColors.riderPrimary;
      case DeliveryStage.delivered:
        return AppColors.emerald;
      default:
        return AppColors.smoke;
    }
  }

  String _statusLabel(DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.assigned:
        return 'ASSIGNED';
      case DeliveryStage.accepted:
        return 'ACCEPTED';
      case DeliveryStage.reachedRestaurant:
        return 'AT RESTAURANT';
      case DeliveryStage.pickedUp:
        return 'PICKED UP';
      case DeliveryStage.onTheWay:
        return 'OUT FOR DELIVERY';
      case DeliveryStage.reachedCustomer:
        return 'AT CUSTOMER';
      case DeliveryStage.delivered:
        return 'DELIVERED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);

    return GlassCard(
      accent: statusColor,
      onTap: () =>
          context.push(AppRoutes.restaurantOrder(order.id), extra: order),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: order code + status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${order.orderCode}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              StatusPill(label: _statusLabel(order.status), color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Restaurant
          Row(
            children: [
              Icon(Icons.storefront_rounded, size: 16, color: AppColors.smoke),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(order.restaurantName)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Customer
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: AppColors.smoke,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(order.customerName)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.smoke,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  order.dropAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Footer: amount + items + payment
          Row(
            children: [
              Text(
                '₹${order.payout.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.riderPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${order.itemsCount} items · ${order.paymentMethod}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.smoke),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // View Details button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(
                AppRoutes.restaurantOrder(order.id),
                extra: order,
              ),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }
}
