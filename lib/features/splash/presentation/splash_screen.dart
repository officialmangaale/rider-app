import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../presentation/providers/app_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Give the splash a brief moment to render, then check session.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final session = ref.read(sessionControllerProvider);
    if (!session.hasSeenOnboarding) {
      context.go(AppRoutes.onboarding);
    } else if (session.status == AuthStatus.authenticated) {
      final route = AppRoutes.resolvePostAuthRoute(role: session.role);
      AppRoutes.debugLogPostAuthRoute(
        source: 'splash',
        role: session.role,
        route: route,
      );
      context.go(route);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
                  'assets/icons/brand_mark.svg',
                  width: 96,
                  height: 96,
                  colorFilter: ColorFilter.mode(
                    scheme.primary,
                    BlendMode.srcIn,
                  ),
                )
                .animate()
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  duration: 800.ms,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: 600.ms),
            const SizedBox(height: 24),
            Text(
              'Mangaale Express',
              style: Theme.of(context).textTheme.headlineMedium,
            ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
            const SizedBox(height: 8),
            Text(
              'Premium rider experience',
              style: Theme.of(context).textTheme.bodySmall,
            ).animate().fadeIn(delay: 500.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}
