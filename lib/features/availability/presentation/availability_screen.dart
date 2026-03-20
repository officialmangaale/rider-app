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

class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shift = ref.watch(riderHubStateProvider)?.shiftSummary;
    if (shift == null) {
      return const PremiumScaffold(child: SizedBox.shrink());
    }

    return PremiumScaffold(
      title: 'Availability & shift',
      subtitle:
          'Switch online status, break mode, and shift context with animated chips.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        children: [
          GlassCard(
            accent: AppColors.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Availability mode',
                  subtitle: 'Set the rider lane you want dispatch to see.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: const [
                    _StatusChoice(status: AvailabilityStatus.online),
                    _StatusChoice(status: AvailabilityStatus.onBreak),
                    _StatusChoice(status: AvailabilityStatus.offline),
                  ],
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
                  title: 'Shift summary',
                  subtitle:
                      'Current session timing and rider preference details.',
                ),
                const SizedBox(height: AppSpacing.lg),
                _Row(
                  label: 'Shift start',
                  value: Formatters.time(shift.shiftStart),
                ),
                _Row(
                  label: 'Shift end',
                  value: Formatters.time(shift.shiftEnd),
                ),
                _Row(label: 'Preferred window', value: shift.preferredWindow),
                _Row(label: 'Break used', value: '${shift.breakMinutes} min'),
                _Row(
                  label: 'Active hours',
                  value: '${shift.activeHours.toStringAsFixed(1)} h',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            accent: AppColors.sky,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Backend-aligned controls',
                  subtitle:
                      'Online, break, and offline map directly to the rider API surface.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'The previous busy mode was a mock-only state, so this screen now stays aligned with the real backend availability states.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChoice extends ConsumerWidget {
  const _StatusChoice({required this.status});

  final AvailabilityStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(riderHubStateProvider)?.shiftSummary.status;
    final active = current == status;
    final color = switch (status) {
      AvailabilityStatus.online => AppColors.emerald,
      AvailabilityStatus.busy => AppColors.ember,
      AvailabilityStatus.onBreak => AppColors.sky,
      AvailabilityStatus.offline => AppColors.danger,
    };

    return ChoiceChip(
      selected: active,
      label: Text(_statusLabel(status)),
      selectedColor: color.withValues(alpha: 0.22),
      side: BorderSide(color: color.withValues(alpha: active ? 0.4 : 0.18)),
      onSelected: (_) async {
        try {
          await ref
              .read(riderHubControllerProvider.notifier)
              .setAvailabilityStatus(status);
        } on ApiException catch (error) {
          if (!context.mounted) {
            return;
          }
          showLuxurySnackBar(context, error.message);
        }
      },
    );
  }

  String _statusLabel(AvailabilityStatus status) => switch (status) {
    AvailabilityStatus.online => 'Online',
    AvailabilityStatus.busy => 'Busy',
    AvailabilityStatus.onBreak => 'On break',
    AvailabilityStatus.offline => 'Offline',
  };
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

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
