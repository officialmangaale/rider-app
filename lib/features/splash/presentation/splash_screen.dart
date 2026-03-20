import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _routeForward();
  }

  Future<void> _routeForward() async {
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) {
      return;
    }

    final session = ref.read(sessionControllerProvider);
    if (!session.hasSeenOnboarding) {
      context.go('/onboarding');
      return;
    }
    if (!session.isAuthenticated) {
      context.go('/login');
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandMark(size: 84)
                  .animate()
                  .scale(duration: 700.ms, curve: Curves.easeOutBack)
                  .fadeIn(duration: 600.ms),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.displayMedium,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppConstants.appTagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: AppSpacing.xxxl),
              Container(
                width: 220,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 2200),
                  curve: Curves.easeInOutCubic,
                  builder: (context, value, child) {
                    return FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: [AppColors.gold, AppColors.ember],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
