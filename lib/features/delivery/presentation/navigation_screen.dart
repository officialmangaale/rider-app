import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class NavigationScreen extends ConsumerWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveryAsync = ref.watch(deliveryControllerProvider);
    final order = deliveryAsync.valueOrNull?.activeOrder;

    return PremiumScaffold(
      title: 'Route preview',
      subtitle:
          'Premium placeholder map ready for live maps integration later.',
      child: order == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: EmptyStateCard(
                  icon: Icons.map_outlined,
                  title: 'No active route',
                  message:
                      'Accept or continue a delivery to unlock the navigation overlay.',
                  action: PrimaryButton(
                    label: 'Back to delivery',
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
                MapPlaceholder(order: order),
                const SizedBox(height: AppSpacing.xl),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Route overlay',
                        subtitle:
                            'Critical rider details on top of the map layer.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _OverlayRow(
                        label: 'ETA',
                        value: Formatters.minutes(order.etaMinutes),
                      ),
                      _OverlayRow(
                        label: 'Distance left',
                        value: Formatters.distance(order.distanceKm),
                      ),
                      _OverlayRow(
                        label: 'Customer address',
                        value: order.dropAddress,
                      ),
                      _OverlayRow(
                        label: 'Restaurant address',
                        value: order.pickupAddress,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Open maps',
                        icon: Icons.open_in_new_rounded,
                        onPressed: () async {
                          final opened = await ref
                              .read(mapLauncherServiceProvider)
                              .openExternalRoute(order);
                          if (!context.mounted) {
                            return;
                          }
                          if (!opened) {
                            showPremiumBottomSheet(
                              context: context,
                              title: 'Maps integration placeholder',
                              subtitle:
                                  'Swap the placeholder service with Google Maps or url_launcher when you connect real routing.',
                              child: const SizedBox.shrink(),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Advance route',
                        icon: Icons.flag_rounded,
                        expanded: true,
                        onPressed: () async {
                          try {
                            await ref
                                .read(deliveryControllerProvider.notifier)
                                .advanceActiveOrder();
                            if (!context.mounted) {
                              return;
                            }
                            showLuxurySnackBar(
                              context,
                              'Route checkpoint updated from map view.',
                            );
                          } on ApiException catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            showLuxurySnackBar(context, error.message);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _OverlayRow extends StatelessWidget {
  const _OverlayRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
