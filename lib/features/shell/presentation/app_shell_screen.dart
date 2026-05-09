import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/navigation_widgets.dart';

class AppShellScreen extends StatelessWidget {
  const AppShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final items = AppConstants.restaurantOwnedRiderMode
        ? const [
            PremiumBottomNavItem(label: 'Active Orders', icon: Icons.motorcycle_rounded),
            PremiumBottomNavItem(label: 'Delivered', icon: Icons.check_circle_outline_rounded),
            PremiumBottomNavItem(label: 'Profile', icon: Icons.person_rounded),
          ]
        : const [
            PremiumBottomNavItem(label: 'Home', icon: Icons.space_dashboard_rounded),
            PremiumBottomNavItem(label: 'Requests', icon: Icons.bolt_rounded),
            PremiumBottomNavItem(label: 'Delivery', icon: Icons.route_rounded),
            PremiumBottomNavItem(label: 'Earnings', icon: Icons.bar_chart_rounded),
            PremiumBottomNavItem(label: 'Profile', icon: Icons.person_rounded),
          ];

    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.transparent,
      body: navigationShell,
      bottomNavigationBar: PremiumBottomNavigation(
        items: items,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

