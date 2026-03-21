import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/availability/presentation/availability_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/delivery/presentation/active_delivery_screen.dart';
import '../../features/delivery/presentation/navigation_screen.dart';
import '../../features/earnings/presentation/earnings_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/ratings/presentation/ratings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';

GoRouter buildAppRouter(Ref ref) {
  CustomTransitionPage<void> buildPage(Widget child, GoRouterState state) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => buildPage(const SplashScreen(), state),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            buildPage(const OnboardingScreen(), state),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => buildPage(const AuthScreen(), state),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => buildPage(const SignupScreen(), state),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/requests',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: OrdersScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/delivery',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ActiveDeliveryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/earnings',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: EarningsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/navigation',
        pageBuilder: (context, state) =>
            buildPage(const NavigationScreen(), state),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) =>
            buildPage(const HistoryScreen(), state),
      ),
      GoRoute(
        path: '/history/:id',
        pageBuilder: (context, state) => buildPage(
          HistoryScreen(detailId: state.pathParameters['id']!),
          state,
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            buildPage(const NotificationsScreen(), state),
      ),
      GoRoute(
        path: '/support',
        pageBuilder: (context, state) =>
            buildPage(const SupportScreen(), state),
      ),
      GoRoute(
        path: '/availability',
        pageBuilder: (context, state) =>
            buildPage(const AvailabilityScreen(), state),
      ),
      GoRoute(
        path: '/wallet',
        pageBuilder: (context, state) => buildPage(const WalletScreen(), state),
      ),
      GoRoute(
        path: '/ratings',
        pageBuilder: (context, state) =>
            buildPage(const RatingsScreen(), state),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            buildPage(const SettingsScreen(), state),
      ),
    ],
  );
}



