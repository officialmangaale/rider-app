import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class DeliveryHistoryScreen extends ConsumerStatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  ConsumerState<DeliveryHistoryScreen> createState() =>
      _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends ConsumerState<DeliveryHistoryScreen> {
  final _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(riderHubStateProvider)?.history ?? const [];
    final query = _searchController.text.toLowerCase();
    final filtered = history.where((record) {
      final matchesFilter = _filter == 'all' || record.outcome.name == _filter;
      final matchesQuery =
          query.isEmpty ||
          record.restaurantName.toLowerCase().contains(query) ||
          record.customerName.toLowerCase().contains(query) ||
          record.id.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();

    return PremiumScaffold(
      title: 'Delivery history',
      subtitle:
          'Search completed, cancelled, and failed trips with premium detail cards.',
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(riderHubControllerProvider.notifier).refreshHub(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          children: [
            PremiumTextField(
              label: 'Search orders',
              hint: 'Restaurant, customer, or order ID',
              controller: _searchController,
              prefixIcon: Icons.search_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final filter in const [
                  'all',
                  'completed',
                  'cancelled',
                  'failed',
                ])
                  FilterChip(
                    selected: _filter == filter,
                    label: Text(filter.toUpperCase()),
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (filtered.isEmpty)
              const EmptyStateCard(
                icon: Icons.inventory_2_outlined,
                title: 'No matching deliveries',
                message: 'Try another date range, status, or search term.',
              )
            else
              for (final record in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: GlassCard(
                    onTap: () => context.push('/history/${record.id}'),
                    accent: _colorForOutcome(record.outcome),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                record.restaurantName,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            StatusPill(
                              label: record.outcome.name,
                              color: _colorForOutcome(record.outcome),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Order ${record.id} - ${record.customerName}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          record.dropAddress,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                Formatters.dayTime(record.completedAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              Formatters.currency(record.earnings),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class DeliveryDetailsScreen extends ConsumerWidget {
  const DeliveryDetailsScreen({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref
        .watch(riderHubStateProvider)
        ?.history
        .where((element) => element.id == recordId)
        .firstOrNull;

    return PremiumScaffold(
      title: 'Delivery details',
      subtitle: 'Full rider breakdown for a completed trip.',
      child: record == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: EmptyStateCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'Delivery not found',
                  message: 'The selected order is missing from your rider history.',
                  action: PrimaryButton(
                    label: 'Back to history',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: [
                GlassCard(
                  accent: _colorForOutcome(record.outcome),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.restaurantName,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          StatusPill(
                            label: record.outcome.name,
                            color: _colorForOutcome(record.outcome),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _DetailRow(label: 'Order ID', value: record.id),
                      _DetailRow(
                        label: 'Payment method',
                        value: record.paymentMethod,
                      ),
                      _DetailRow(label: 'Customer', value: record.customerName),
                      _DetailRow(
                        label: 'Distance',
                        value: Formatters.distance(record.distanceKm),
                      ),
                      _DetailRow(
                        label: 'Delivery time',
                        value: Formatters.dayTime(record.completedAt),
                      ),
                      _DetailRow(
                        label: 'Duration',
                        value: Formatters.minutes(record.durationMinutes),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Addresses and notes',
                        subtitle: 'Pickup, drop, and rider note context.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        record.pickupAddress,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        record.dropAddress,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        record.notes,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GlassCard(
                  accent: AppColors.gold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Earnings breakdown',
                        subtitle: 'Clear payout detail for the archived trip.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _DetailRow(
                        label: 'Base payout',
                        value: Formatters.currency(record.earnings - 34),
                      ),
                      _DetailRow(
                        label: 'Tips + boost',
                        value: Formatters.currency(34),
                      ),
                      _DetailRow(
                        label: 'Total credited',
                        value: Formatters.currency(record.earnings),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Timeline',
                        subtitle: 'Archived delivery milestones.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (final item in record.timeline)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.gold,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(item),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

Color _colorForOutcome(DeliveryOutcome outcome) => switch (outcome) {
  DeliveryOutcome.completed => AppColors.emerald,
  DeliveryOutcome.cancelled => AppColors.warning,
  DeliveryOutcome.failed => AppColors.danger,
};

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}



