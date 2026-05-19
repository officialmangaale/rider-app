import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';

class RouteAuthSnapshot {
  const RouteAuthSnapshot({
    required this.isAuthenticated,
    required this.hasSeenOnboarding,
    this.role,
  });

  final bool isAuthenticated;
  final bool hasSeenOnboarding;
  final String? role;
}

class AppRoutes {
  const AppRoutes._();

  static const root = '/';
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';

  static const home = '/home';
  static const requests = '/requests';
  static const delivery = '/delivery';
  static const earnings = '/earnings';
  static const profile = '/profile';

  static const activeOrders = '/active-orders';
  static const deliveredOrders = '/delivered-orders';

  static const navigation = '/navigation';
  static const history = '/history';
  static const notifications = '/notifications';
  static const support = '/support';
  static const availability = '/availability';
  static const wallet = '/wallet';
  static const ratings = '/ratings';
  static const settings = '/settings';
  static const restaurantOrderBase = '/restaurant-order';

  static const canonicalRiderRole = 'delivery_driver';
  static const _legacyRiderRoles = {'rider'};
  static const _supportedRiderRoles = {canonicalRiderRole};

  static String historyDetail(String id) => '$history/$id';

  static String restaurantOrder(String id) => '$restaurantOrderBase/$id';

  static String? normalizeRole(String? role) {
    final normalized = role?.trim().toLowerCase().replaceAll('-', '_');
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (_legacyRiderRoles.contains(normalized)) {
      return canonicalRiderRole;
    }
    return normalized;
  }

  static String? rawRole(String? role) {
    final normalized = role?.trim().toLowerCase().replaceAll('-', '_');
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String? extractRole(Map<String, dynamic> data) {
    final raw = extractRawRole(data);
    return raw == null ? null : normalizeRole(raw);
  }

  static String? extractRawRole(Map<String, dynamic> data) {
    final user = _asStringMap(data['user']);
    final rider = _asStringMap(data['rider']);
    for (final value in [
      user?['primary_role'],
      user?['role'],
      user?['user_type'],
      _firstRole(user?['roles']),
      rider?['primary_role'],
      rider?['role'],
      rider?['user_type'],
      _firstRole(rider?['roles']),
      data['primary_role'],
      data['role'],
      data['user_type'],
      _firstRole(data['roles']),
    ]) {
      if (value is String && value.trim().isNotEmpty) {
        return rawRole(value);
      }
    }
    return null;
  }

  static String? _firstRole(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    if (value is Iterable) {
      for (final item in value) {
        if (item is String && item.trim().isNotEmpty) {
          return item;
        }
      }
    }
    return null;
  }

  static bool isSupportedRiderRole(String? role) {
    final normalized = normalizeRole(role);
    return normalized == null || _supportedRiderRoles.contains(normalized);
  }

  static String resolvePostAuthRoute({String? role}) {
    if (!isSupportedRiderRole(role)) {
      return login;
    }
    return AppConstants.restaurantOwnedRiderMode ? activeOrders : home;
  }

  static String resolveEntryRoute(RouteAuthSnapshot auth) {
    if (!auth.hasSeenOnboarding) {
      return onboarding;
    }
    if (!auth.isAuthenticated) {
      return login;
    }
    return resolvePostAuthRoute(role: auth.role);
  }

  static bool isAuthPath(String path) => path == login || path == signup;

  static bool isEntryAlias(String path) => path == root || path == home;

  static bool isPublicPath(String path) {
    return path == root ||
        path == splash ||
        path == onboarding ||
        path == login ||
        path == signup;
  }

  static bool isProtectedPath(String path) => !isPublicPath(path);

  static List<String> registeredPaths() {
    return [
      root,
      splash,
      onboarding,
      login,
      signup,
      if (AppConstants.restaurantOwnedRiderMode) ...[
        home,
        activeOrders,
        deliveredOrders,
        profile,
      ] else ...[
        home,
        requests,
        delivery,
        earnings,
        profile,
      ],
      navigation,
      history,
      '$history/:id',
      notifications,
      support,
      availability,
      wallet,
      ratings,
      settings,
      '$restaurantOrderBase/:id',
    ];
  }

  static void debugLogRouteTable() {
    assert(() {
      debugPrint('GoRouter registered paths: ${registeredPaths().join(', ')}');
      return true;
    }());
  }

  static void debugLogPostAuthRoute({
    required String source,
    required String route,
    String? role,
  }) {
    assert(() {
      debugPrint(
        'Post-auth route resolved: $route for rawRole=${rawRole(role) ?? 'unknown'} normalizedRole=${normalizeRole(role) ?? 'unknown'} source=$source',
      );
      return true;
    }());
  }

  static Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return null;
  }
}
