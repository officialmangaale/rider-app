import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availabilityAsync = ref.watch(availabilityControllerProvider);

    return PremiumScaffold(
      title: 'Availability',
      subtitle: 'Manage your shift status and break controls.',
      onRefresh: () =>
          ref.read(availabilityControllerProvider.notifier).refresh(),
      child: availabilityAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [ShimmerCard(), SizedBox(height: AppSpacing.md), ShimmerCard()],
          ),
        ),
        error: (error, _) => Center(
          child: EmptyStateCard(
            icon: Icons.warning_rounded,
            title: 'Could not load availability',
            subtitle: error is ApiException ? error.message : 'Something went wrong.',
          ),
        ),
        data: (shift) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
          ),
          children: [
            // ── Status toggle ──────────────────────────────
            GlassCard(
              accent: shift.status == AvailabilityStatus.online
                  ? AppColors.emerald
                  : AppColors.smoke,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Current status',
                    subtitle: 'Switch between online, break, and offline.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          switch (shift.status) {
                            AvailabilityStatus.online => 'You are online',
                            AvailabilityStatus.onBreak => 'On a break',
                            AvailabilityStatus.busy => 'Busy (delivering)',
                            AvailabilityStatus.offline => 'You are offline',
                          },
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      PremiumStatusToggle(
                        label: 'Shift status',
                        value: shift.status == AvailabilityStatus.online,
                        activeLabel: 'Online',
                        inactiveLabel: 'Offline',
                        onChanged: (active) async {
                          try {
                            await ref.read(availabilityControllerProvider.notifier).setStatus(
                              active ? AvailabilityStatus.online : AvailabilityStatus.offline,
                            );
                          } on ApiException catch (e) {
                            if (!context.mounted) return;
                            showLuxurySnackBar(context, e.message);
                          }
                        },
                      ),
                    ],
                  ),
                  if (shift.status == AvailabilityStatus.online) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SecondaryButton(
                      label: 'Start break',
                      icon: Icons.coffee_rounded,
                      onPressed: () async {
                        try {
                          await ref.read(availabilityControllerProvider.notifier).setStatus(
                            AvailabilityStatus.onBreak,
                          );
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showLuxurySnackBar(context, e.message);
                        }
                      },
                    ),
                  ],
                  if (shift.status == AvailabilityStatus.onBreak) ...[
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'End break',
                      icon: Icons.play_arrow_rounded,
                      expanded: true,
                      onPressed: () async {
                        try {
                          await ref.read(availabilityControllerProvider.notifier).setStatus(
                            AvailabilityStatus.online,
                          );
                        } on ApiException catch (e) {
                          if (!context.mounted) return;
                          showLuxurySnackBar(context, e.message);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Shift summary ──────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Shift summary',
                    subtitle: 'Hours, breaks, and preferences.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ShiftRow(
                    label: 'Shift start',
                    value: Formatters.time(shift.shiftStart),
                  ),
                  _ShiftRow(
                    label: 'Shift end',
                    value: Formatters.time(shift.shiftEnd),
                  ),
                  _ShiftRow(
                    label: 'Active hours',
                    value: '${shift.activeHours.toStringAsFixed(1)} hrs',
                  ),
                  _ShiftRow(
                    label: 'Break time',
                    value: '${shift.breakMinutes} min',
                  ),
                  if (shift.preferredWindow.isNotEmpty)
                    _ShiftRow(
                      label: 'Window',
                      value: shift.preferredWindow,
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

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.label, required this.value});
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
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
