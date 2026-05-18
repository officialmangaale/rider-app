import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../features/delivery/providers/rider_delivery_provider.dart';
import '../presentation/providers/app_providers.dart';

class RydexRiderApp extends ConsumerStatefulWidget {
  const RydexRiderApp({super.key});

  @override
  ConsumerState<RydexRiderApp> createState() => _RydexRiderAppState();
}

class _RydexRiderAppState extends ConsumerState<RydexRiderApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncLocationForSession(ref.read(sessionControllerProvider));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(riderDeliveryControllerProvider.notifier)
        .handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      if (previous?.status != next.status || previous?.role != next.role) {
        _syncLocationForSession(next);
      }
    });

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      routerConfig: router,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
    );
  }

  void _syncLocationForSession(SessionState session) {
    final controller = ref.read(riderDeliveryControllerProvider.notifier);
    if (session.status == AuthStatus.authenticated) {
      unawaited(controller.bootstrapSessionLocation(requestPermission: true));
    } else {
      controller.clearSession();
    }
  }
}
