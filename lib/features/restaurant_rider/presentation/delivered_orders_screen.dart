import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_models.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../providers/restaurant_rider_provider.dart';

class DeliveredOrdersScreen extends ConsumerWidget {
  const DeliveredOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveredOrdersState = ref.watch(deliveredOrdersProvider);

    return PremiumScaffold(
      title: 'Delivered',
      subtitle: 'Your completed deliveries',
      onRefresh: () => ref.refresh(deliveredOrdersProvider.future),
      child: deliveredOrdersState.when(
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.smoke),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No delivered orders yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.smoke,
                    ),
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
              return _DeliveredOrderCard(order: order);
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
              const Text('Failed to load delivered orders'),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => ref.invalidate(deliveredOrdersProvider),
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

class _DeliveredOrderCard extends StatelessWidget {
  const _DeliveredOrderCard({required this.order});
  final DeliveryRecord order;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: AppColors.emerald,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order ${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              StatusPill(
                label: 'DELIVERED',
                color: AppColors.emerald,
                icon: Icons.check_circle_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.storefront_rounded, size: 16, color: AppColors.smoke),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(order.restaurantName)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: AppColors.smoke),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  order.dropAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '₹${order.earnings.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.emerald,
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(order.completedAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.smoke,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
