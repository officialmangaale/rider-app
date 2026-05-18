import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../providers/rider_delivery_provider.dart';

class RiderLocationStatusCard extends ConsumerWidget {
  const RiderLocationStatusCard({super.key, this.alwaysShow = false});

  final bool alwaysShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(riderDeliveryControllerProvider);
    if (!alwaysShow && !state.shouldShowLocationStatus) {
      return const SizedBox.shrink();
    }

    final display = _displayFor(state);
    final lastUpdated = _lastUpdatedText(context, state.lastLocationUpdate);
    final subtitle = lastUpdated == null
        ? state.locationMessage
        : '${state.locationMessage} Last updated $lastUpdated.';

    return GlassCard(
      accent: display.color,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: display.color.withValues(alpha: 0.12),
                ),
                child: Icon(display.icon, color: display.color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      display.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasActions(state)) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (state.canRequestLocationPermission)
                  PrimaryButton(
                    label: 'Grant Permission',
                    icon: Icons.my_location_rounded,
                    onPressed: state.locationActionInProgress
                        ? null
                        : () => ref
                              .read(riderDeliveryControllerProvider.notifier)
                              .requestLocationPermission(),
                  ),
                if (state.canOpenLocationSettings)
                  PrimaryButton(
                    label: 'Enable GPS',
                    icon: Icons.location_searching_rounded,
                    onPressed: state.locationActionInProgress
                        ? null
                        : () => ref
                              .read(riderDeliveryControllerProvider.notifier)
                              .openLocationSettings(),
                  ),
                if (state.canOpenAppSettings)
                  SecondaryButton(
                    label: 'Open Settings',
                    icon: Icons.settings_rounded,
                    onPressed: state.locationActionInProgress
                        ? null
                        : () => ref
                              .read(riderDeliveryControllerProvider.notifier)
                              .openAppSettings(),
                  ),
                if (state.locationStatus == RiderLocationTrackingStatus.failed)
                  SecondaryButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: state.locationActionInProgress
                        ? null
                        : () => ref
                              .read(riderDeliveryControllerProvider.notifier)
                              .retryLocationUpdate(),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _hasActions(RiderDeliveryState state) {
    return state.canRequestLocationPermission ||
        state.canOpenLocationSettings ||
        state.canOpenAppSettings ||
        state.locationStatus == RiderLocationTrackingStatus.failed;
  }

  _LocationDisplay _displayFor(RiderDeliveryState state) {
    switch (state.locationStatus) {
      case RiderLocationTrackingStatus.active:
        return const _LocationDisplay(
          title: 'Tracking active',
          icon: Icons.gps_fixed_rounded,
          color: AppColors.emerald,
        );
      case RiderLocationTrackingStatus.checking:
        return const _LocationDisplay(
          title: 'Checking location',
          icon: Icons.gps_not_fixed_rounded,
          color: AppColors.gold,
        );
      case RiderLocationTrackingStatus.blocked:
        if (state.canOpenLocationSettings) {
          return const _LocationDisplay(
            title: 'GPS is disabled',
            icon: Icons.location_disabled_rounded,
            color: AppColors.warning,
          );
        }
        return const _LocationDisplay(
          title: 'Location permission required',
          icon: Icons.location_off_rounded,
          color: AppColors.warning,
        );
      case RiderLocationTrackingStatus.failed:
        return const _LocationDisplay(
          title: 'Location update failed',
          icon: Icons.cloud_off_rounded,
          color: AppColors.cherry,
        );
      case RiderLocationTrackingStatus.paused:
        return const _LocationDisplay(
          title: 'Tracking paused',
          icon: Icons.pause_circle_outline_rounded,
          color: AppColors.smoke,
        );
      case RiderLocationTrackingStatus.unauthorized:
        return const _LocationDisplay(
          title: 'Session expired',
          icon: Icons.lock_outline_rounded,
          color: AppColors.cherry,
        );
      case RiderLocationTrackingStatus.idle:
        return const _LocationDisplay(
          title: 'Location ready',
          icon: Icons.location_searching_rounded,
          color: AppColors.riderPrimary,
        );
    }
  }

  String? _lastUpdatedText(BuildContext context, DateTime? value) {
    if (value == null) {
      return null;
    }
    final diff = DateTime.now().difference(value.toLocal());
    if (diff.inSeconds < 45) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return '$minutes min ago';
    }
    return 'at ${TimeOfDay.fromDateTime(value.toLocal()).format(context)}';
  }
}

class _LocationDisplay {
  const _LocationDisplay({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;
}
