import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/app_models.dart';
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
import '../../features/restaurant_rider/presentation/active_orders_screen.dart';
import '../../features/restaurant_rider/presentation/delivered_orders_screen.dart';
import '../../features/restaurant_rider/presentation/order_detail_screen.dart';
import '../../features/restaurant_rider/presentation/restaurant_profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../presentation/providers/rider_compliance_provider.dart';
import 'app_routes.dart';

class AppRouterRefreshListenable extends ChangeNotifier {
  void refresh() => notifyListeners();
}

GoRouter buildAppRouter({
  required RouteAuthSnapshot Function() readAuthSnapshot,
  required Listenable refreshListenable,
}) {
  AppRoutes.debugLogRouteTable();

  String? redirect(GoRouterState state) {
    final path = state.uri.path;
    final auth = readAuthSnapshot();

    if (path == AppRoutes.splash) {
      return null;
    }

    if (AppRoutes.isEntryAlias(path)) {
      final target = AppRoutes.resolveEntryRoute(auth);
      return target == path ? null : target;
    }

    if (!auth.hasSeenOnboarding && path != AppRoutes.onboarding) {
      return AppRoutes.onboarding;
    }

    if (auth.isAuthenticated && AppRoutes.isAuthPath(path)) {
      final target = AppRoutes.resolvePostAuthRoute(role: auth.role);
      return target == path ? null : target;
    }

    if (!auth.isAuthenticated && AppRoutes.isProtectedPath(path)) {
      return AppRoutes.login;
    }

    return null;
  }

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
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) => redirect(state),
    errorBuilder: (context, state) {
      assert(() {
        debugPrint('GoRouter error for ${state.uri}: ${state.error}');
        return true;
      }());
      return _RouteErrorScreen(
        debugMessage: kDebugMode ? state.error.toString() : null,
        resolveHomeRoute: () => AppRoutes.resolveEntryRoute(readAuthSnapshot()),
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        redirect: (context, state) =>
            AppRoutes.resolveEntryRoute(readAuthSnapshot()),
      ),
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => buildPage(const SplashScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) =>
            buildPage(const OnboardingScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => buildPage(const AuthScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.signup,
        pageBuilder: (context, state) => buildPage(const SignupScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.modeGate,
        pageBuilder: (context, state) =>
            buildPage(const _RiderModeGateScreen(), state),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScreen(
            navigationShell: navigationShell,
            mode: RiderShellMode.restaurantOwned,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.activeOrders,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ActiveOrdersScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.deliveredOrders,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: DeliveredOrdersScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.restaurantProfile,
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: RestaurantProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScreen(
            navigationShell: navigationShell,
            mode: RiderShellMode.platform,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.requests,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: OrdersScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.delivery,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ActiveDeliveryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.earnings,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: EarningsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.navigation,
        pageBuilder: (context, state) =>
            buildPage(const NavigationScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.history,
        pageBuilder: (context, state) =>
            buildPage(const HistoryScreen(), state),
      ),
      GoRoute(
        path: '${AppRoutes.history}/:id',
        pageBuilder: (context, state) => buildPage(
          HistoryScreen(detailId: state.pathParameters['id']!),
          state,
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (context, state) =>
            buildPage(const NotificationsScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.support,
        pageBuilder: (context, state) =>
            buildPage(const SupportScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.availability,
        pageBuilder: (context, state) =>
            buildPage(const AvailabilityScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        pageBuilder: (context, state) => buildPage(const WalletScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.ratings,
        pageBuilder: (context, state) =>
            buildPage(const RatingsScreen(), state),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) =>
            buildPage(const SettingsScreen(), state),
      ),
      GoRoute(
        path: '${AppRoutes.restaurantOrderBase}/:id',
        pageBuilder: (context, state) {
          final order = state.extra;
          if (order is! DeliveryOrder) {
            return buildPage(
              _RouteErrorScreen(
                debugMessage: kDebugMode
                    ? 'Order detail route requires a DeliveryOrder payload.'
                    : null,
                resolveHomeRoute: () =>
                    AppRoutes.resolveEntryRoute(readAuthSnapshot()),
              ),
              state,
            );
          }
          return buildPage(
            OrderDetailScreen(
              orderId: state.pathParameters['id']!,
              order: order,
            ),
            state,
          );
        },
      ),
    ],
  );
}

class _RiderModeGateScreen extends ConsumerWidget {
  const _RiderModeGateScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(riderComplianceControllerProvider);

    return profileState.when(
      data: (state) {
        final profile = state.profile;
        final target = profile.isRestaurantLinked
            ? AppRoutes.activeOrders
            : AppRoutes.home;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          assert(() {
            debugPrint(
              'Rider mode resolved: mode=${profile.mode.isEmpty ? 'platform' : profile.mode} '
              'linkedRestaurants=${profile.linkedRestaurantCount} '
              'target=$target',
            );
            return true;
          }());
          context.go(target);
        });
        return const _ModeGateScaffold(
          message: 'Opening your rider workspace...',
        );
      },
      loading: () =>
          const _ModeGateScaffold(message: 'Loading your rider profile...'),
      error: (error, _) => _ModeGateScaffold(
        message: 'Could not load your rider profile.',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(riderComplianceControllerProvider),
        debugMessage: kDebugMode ? '$error' : null,
      ),
    );
  }
}

class _ModeGateScaffold extends StatelessWidget {
  const _ModeGateScaffold({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.debugMessage,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? debugMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onAction == null)
                    const CircularProgressIndicator()
                  else
                    Icon(
                      Icons.sync_problem_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (debugMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      debugMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.resolveHomeRoute, this.debugMessage});

  final String Function() resolveHomeRoute;
  final String? debugMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Page not available',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This link is not available in the current rider app.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (debugMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      debugMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(resolveHomeRoute()),
                    child: const Text('Go to app'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
