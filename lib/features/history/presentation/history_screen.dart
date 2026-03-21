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

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.detailId});
  final String? detailId;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  DeliveryOutcome? _filterOutcome;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earningsAsync = ref.watch(earningsControllerProvider);

    // If detail route, show detail view.
    if (widget.detailId != null) {
      final record = earningsAsync.valueOrNull?.history.where(
        (r) => r.id == widget.detailId,
      );
      if (record != null && record.isNotEmpty) {
        return _DetailView(record: record.first);
      }
      return PremiumScaffold(
        title: 'Delivery details',
        child: Center(
          child: EmptyStateCard(
            icon: Icons.search_off_rounded,
            title: 'Record not found',
            subtitle: 'This delivery record could not be located.',
          ),
        ),
      );
    }

    return PremiumScaffold(
      title: 'Delivery history',
      subtitle: 'Past deliveries and earnings breakdown.',
      onRefresh: () =>
          ref.read(earningsControllerProvider.notifier).refresh(),
      child: earningsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(children: [ShimmerCard(), SizedBox(height: AppSpacing.md), ShimmerCard()]),
        ),
        error: (error, _) => Center(
          child: EmptyStateCard(
            icon: Icons.warning_rounded,
            title: 'Could not load history',
            subtitle: error is ApiException ? error.message : 'Something went wrong.',
          ),
        ),
        data: (state) {
          var records = state.history;

          // Apply search filter.
          if (_query.isNotEmpty) {
            records = records.where((r) {
              return r.restaurantName.toLowerCase().contains(_query) ||
                  r.customerName.toLowerCase().contains(_query) ||
                  r.id.toLowerCase().contains(_query);
            }).toList();
          }

          // Apply outcome filter.
          if (_filterOutcome != null) {
            records =
                records.where((r) => r.outcome == _filterOutcome).toList();
          }

          return Column(
            children: [
              // ── Search + filter bar ──────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search deliveries...',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    PopupMenuButton<DeliveryOutcome?>(
                      icon: const Icon(Icons.filter_list_rounded),
                      onSelected: (v) => setState(() => _filterOutcome = v),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: null,
                          child: Text('All'),
                        ),
                        const PopupMenuItem(
                          value: DeliveryOutcome.completed,
                          child: Text('Completed'),
                        ),
                        const PopupMenuItem(
                          value: DeliveryOutcome.cancelled,
                          child: Text('Cancelled'),
                        ),
                        const PopupMenuItem(
                          value: DeliveryOutcome.failed,
                          child: Text('Failed'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Records list ────────────────────────────────
              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: EmptyStateCard(
                          icon: Icons.history_rounded,
                          title: 'No records found',
                          subtitle: 'Try a different search or filter.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
                        ),
                        itemCount: records.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (ctx, i) {
                          final record = records[i];
                          return _RecordCard(record: record);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Record card ────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});
  final DeliveryRecord record;

  @override
  Widget build(BuildContext context) {
    final outcomeColor = switch (record.outcome) {
      DeliveryOutcome.completed => AppColors.emerald,
      DeliveryOutcome.cancelled => AppColors.warning,
      DeliveryOutcome.failed => AppColors.danger,
    };

    return GlassCard(
      accent: outcomeColor,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _DetailView(record: record),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.restaurantName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${record.customerName} · ${Formatters.distance(record.distanceKm)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Formatters.dayTime(record.completedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.currency(record.earnings),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              StatusPill(
                label: record.outcome.name,
                color: outcomeColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Detail view ────────────────────────────────────────────────────────────

class _DetailView extends StatelessWidget {
  const _DetailView({required this.record});
  final DeliveryRecord record;

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Delivery #${record.id}',
      subtitle: Formatters.dateLong(record.completedAt),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
        ),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Route',
                  subtitle: 'Pickup and drop details.',
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(label: 'Restaurant', value: record.restaurantName),
                _DetailRow(label: 'Customer', value: record.customerName),
                _DetailRow(label: 'Pickup', value: record.pickupAddress),
                _DetailRow(label: 'Drop', value: record.dropAddress),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Earnings',
                  subtitle: 'Payout breakdown for this delivery.',
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: 'Total earnings',
                  value: Formatters.currency(record.earnings),
                ),
                _DetailRow(
                  label: 'Distance',
                  value: Formatters.distance(record.distanceKm),
                ),
                _DetailRow(
                  label: 'Duration',
                  value: Formatters.minutes(record.durationMinutes),
                ),
                _DetailRow(label: 'Payment', value: record.paymentMethod),
                _DetailRow(label: 'Items', value: '${record.itemsCount}'),
              ],
            ),
          ),
          if (record.timeline.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Timeline',
                    subtitle: 'Delivery stages for this order.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final step in record.timeline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: AppColors.emerald,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            step,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
