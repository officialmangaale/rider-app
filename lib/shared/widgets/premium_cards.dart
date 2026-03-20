import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/app_models.dart';
import 'premium_surfaces.dart';

class PremiumProfileCard extends StatelessWidget {
  const PremiumProfileCard({
    super.key,
    required this.initials,
    required this.title,
    required this.subtitle,
    this.accent = AppColors.gold,
    this.trailing,
    this.supportingText,
    this.child,
  });

  final String initials;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget? trailing;
  final String? supportingText;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: accent),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailing!,
              ],
            ],
          ),
          if (supportingText != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              supportingText!,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.55),
            ),
          ],
          if (child != null) ...[const SizedBox(height: AppSpacing.lg), child!],
        ],
      ),
    );
  }
}

class PremiumAnalyticsCard extends StatelessWidget {
  const PremiumAnalyticsCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SectionHeader(title: title, subtitle: subtitle),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class PremiumOrderCard extends StatelessWidget {
  const PremiumOrderCard({
    super.key,
    required this.order,
    this.accent,
    this.trailing,
    this.primaryAction,
    this.secondaryAction,
    this.footer,
    this.subtitle,
    this.showNotes = true,
  });

  final DeliveryOrder order;
  final Color? accent;
  final Widget? trailing;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final Widget? footer;
  final String? subtitle;
  final bool showNotes;

  @override
  Widget build(BuildContext context) {
    final cardAccent = accent ?? _priorityColor(order.priority);
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      accent: cardAccent,
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
                      order.restaurantName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle ??
                          'Order ${order.orderCode} for ${order.customerName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusPill(
                label: _priorityLabel(order.priority),
                color: cardAccent,
                icon: Icons.local_fire_department_rounded,
              ),
              StatusPill(
                label: _typeLabel(order.type),
                color: AppColors.sky,
                icon: Icons.layers_rounded,
              ),
              StatusPill(
                label: _statusLabel(order.status),
                color: AppColors.emerald,
                icon: Icons.route_rounded,
              ),
              if (order.isMultiOrder)
                const StatusPill(
                  label: 'Multi-order',
                  color: AppColors.gold,
                  icon: Icons.call_split_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _OrderRouteRow(
            icon: Icons.storefront_rounded,
            label: 'Pickup',
            value: order.pickupAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          _OrderRouteRow(
            icon: Icons.place_rounded,
            label: 'Drop',
            value: order.dropAddress,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _OrderMetric(
                label: 'Distance',
                value: Formatters.distance(order.distanceKm),
              ),
              _OrderMetric(
                label: 'ETA',
                value: Formatters.minutes(order.etaMinutes),
              ),
              _OrderMetric(label: 'Items', value: '${order.itemsCount}'),
              _OrderMetric(
                label: 'Payout',
                value: Formatters.currency(order.payout + order.tip),
                highlight: true,
              ),
            ],
          ),
          if (order.itemHighlights.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final item in order.itemHighlights.take(4))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: scheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ],
          if (showNotes && order.notes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: scheme.surfaceContainerHighest,
              ),
              child: Text(
                order.notes,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.lg),
            footer!,
          ],
          if (primaryAction != null || secondaryAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                if (secondaryAction != null) Expanded(child: secondaryAction!),
                if (secondaryAction != null && primaryAction != null)
                  const SizedBox(width: AppSpacing.md),
                if (primaryAction != null) Expanded(child: primaryAction!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _priorityColor(OrderPriority priority) => switch (priority) {
    OrderPriority.vip => AppColors.gold,
    OrderPriority.rush => AppColors.ember,
    OrderPriority.standard => AppColors.sky,
  };

  String _priorityLabel(OrderPriority priority) => switch (priority) {
    OrderPriority.vip => 'VIP',
    OrderPriority.rush => 'Rush',
    OrderPriority.standard => 'Standard',
  };

  String _typeLabel(OrderType type) => switch (type) {
    OrderType.solo => 'Solo',
    OrderType.stacked => 'Stacked',
    OrderType.scheduled => 'Scheduled',
  };

  String _statusLabel(DeliveryStage stage) => switch (stage) {
    DeliveryStage.assigned => 'Assigned',
    DeliveryStage.accepted => 'Accepted',
    DeliveryStage.reachedRestaurant => 'At pickup',
    DeliveryStage.pickedUp => 'Picked up',
    DeliveryStage.onTheWay => 'On route',
    DeliveryStage.reachedCustomer => 'At customer',
    DeliveryStage.delivered => 'Delivered',
  };
}

class _OrderRouteRow extends StatelessWidget {
  const _OrderRouteRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderMetric extends StatelessWidget {
  const _OrderMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 108),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: highlight ? AppColors.gold : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
