import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_models.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../providers/restaurant_rider_provider.dart';

class ActiveOrdersScreen extends ConsumerWidget {
  const ActiveOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrdersState = ref.watch(activeOrdersProvider);

    return PremiumScaffold(
      title: 'Active Orders',
      subtitle: 'Orders assigned to you',
      onRefresh: () => ref.refresh(activeOrdersProvider.future),
      child: activeOrdersState.when(
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.motorcycle_rounded, size: 64, color: AppColors.smoke),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No assigned orders yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.smoke,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'New orders will appear here when assigned.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _ActiveOrderCard(order: order);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: AppSpacing.md),
              const Text('Failed to load active orders'),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => ref.invalidate(activeOrdersProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
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
      onTap: () => context.push('/restaurant-order/${order.id}', extra: order),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              StatusPill(
                label: _statusLabel(order.status),
                color: statusColor,
              ),
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
              Icon(Icons.person_outline_rounded, size: 16, color: AppColors.smoke),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(order.customerName)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: AppColors.smoke),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.smoke,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // View Details button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/restaurant-order/${order.id}', extra: order),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }
}
