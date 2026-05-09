import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/profile_provider.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../providers/restaurant_rider_provider.dart';

class RestaurantProfileScreen extends ConsumerWidget {
  const RestaurantProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final linkedRestaurantsState = ref.watch(linkedRestaurantsProvider);

    return PremiumScaffold(
      title: 'Profile',
      subtitle: 'Your rider details',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile card ──────────────────────────
            profileState.when(
              data: (profile) {
                return GlassCard(
                  accent: AppColors.riderPrimary,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.riderPrimary.withValues(alpha: 0.12),
                        child: Text(
                          profile.avatarInitials,
                          style: TextStyle(
                            fontSize: 24,
                            color: AppColors.riderPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        profile.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        profile.phone,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.smoke,
                        ),
                      ),
                      Text(
                        profile.city,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.smoke,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ProfileStat(
                            label: 'Deliveries',
                            value: '${profile.completedDeliveries}',
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          _ProfileStat(
                            label: 'Rating',
                            value: profile.rating > 0
                                ? profile.rating.toStringAsFixed(1)
                                : '—',
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          _ProfileStat(
                            label: 'Today',
                            value: '₹${profile.todayEarnings.toStringAsFixed(0)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => GlassCard(
                child: Text(
                  'Could not load profile details',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Linked restaurants ────────────────────
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.sm),
              child: Text(
                'Linked Restaurants',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            linkedRestaurantsState.when(
              data: (restaurants) {
                if (restaurants.isEmpty) {
                  return GlassCard(
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.smoke),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'No linked restaurants found.\nYour restaurant owner will assign you.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.smoke,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: restaurants.map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: GlassCard(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: AppColors.emerald.withValues(alpha: 0.12),
                              ),
                              child: const Icon(Icons.storefront_rounded, color: AppColors.emerald, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                r['name'] as String? ?? 'Restaurant',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text('Could not load linked restaurants'),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Logout ────────────────────────────────
            FilledButton.icon(
              onPressed: () async {
                await ref.read(sessionControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.all(AppSpacing.md),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.riderPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.smoke,
          ),
        ),
      ],
    );
  }
}
