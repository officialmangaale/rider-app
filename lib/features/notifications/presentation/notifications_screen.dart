import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsControllerProvider);

    return PremiumScaffold(
      title: 'Notifications',
      subtitle:
          'New order alerts, payouts, incentives, support, and system updates.',
      actions: [
        TextButton(
          onPressed: () async {
            try {
              await ref
                  .read(notificationsControllerProvider.notifier)
                  .markAllRead();
              if (!context.mounted) return;
              showLuxurySnackBar(context, 'All notifications marked as read.');
            } on ApiException catch (error) {
              if (!context.mounted) return;
              showLuxurySnackBar(context, error.message);
            }
          },
          child: const Text('Mark all read'),
        ),
      ],
      onRefresh: () =>
          ref.read(notificationsControllerProvider.notifier).refresh(),
      child: notificationsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(children: [ShimmerCard(), SizedBox(height: AppSpacing.md), ShimmerCard()]),
        ),
        error: (error, _) => Center(
          child: EmptyStateCard(
            icon: Icons.warning_rounded,
            title: 'Could not load notifications',
            subtitle: error is ApiException ? error.message : 'Something went wrong.',
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: EmptyStateCard(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications',
                subtitle: 'You\'re all caught up.',
              ),
            );
          }

          final today = notifications
              .where((item) =>
                  DateTime.now().difference(item.createdAt).inHours < 24)
              .toList();
          final earlier = notifications
              .where((item) =>
                  DateTime.now().difference(item.createdAt).inHours >= 24)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
            ),
            children: [
              if (today.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Today',
                  subtitle: 'Fresh rider updates and dispatch movement.',
                ),
                const SizedBox(height: AppSpacing.md),
                ...today.map((item) => _NotificationCard(item: item)),
              ],
              if (earlier.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Earlier',
                  subtitle: 'Recent app and payout history notifications.',
                ),
                const SizedBox(height: AppSpacing.md),
                ...earlier.map((item) => _NotificationCard(item: item)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item});
  final AppNotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (item.type) {
      NotificationType.order => AppColors.gold,
      NotificationType.payout => AppColors.emerald,
      NotificationType.incentive => AppColors.ember,
      NotificationType.update => AppColors.sky,
      NotificationType.support => AppColors.warning,
    };

    final icon = switch (item.type) {
      NotificationType.order => Icons.delivery_dining_rounded,
      NotificationType.payout => Icons.payments_rounded,
      NotificationType.incentive => Icons.card_giftcard_rounded,
      NotificationType.update => Icons.system_update_rounded,
      NotificationType.support => Icons.support_agent_rounded,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        accent: color,
        onTap: () async {
          if (!item.isUnread) return;
          try {
            await ref
                .read(notificationsControllerProvider.notifier)
                .markRead(item.id);
          } on ApiException catch (error) {
            if (!context.mounted) return;
            showLuxurySnackBar(context, error.message);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: color.withValues(alpha: 0.14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (item.isUnread)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    Formatters.dayTime(item.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
