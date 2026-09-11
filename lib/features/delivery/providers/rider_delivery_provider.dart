import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/services/rider_backend_api.dart';
import '../../../domain/entities/rider_compliance_models.dart';
import '../../../presentation/providers/core_providers.dart';
import '../../restaurant_rider/providers/restaurant_rider_provider.dart';
import '../background/background_mode_controller.dart';
import '../background/background_mode_store.dart';
import '../background/incoming_ringer.dart';
import '../background/request_alert_notifier.dart';
import '../background/rider_platform.dart';
import '../models/delivery_models.dart';
import '../services/rider_delivery_api_service.dart';
import '../services/rider_location_service.dart';
import '../services/rider_socket_service.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../services/incoming_alert_policy.dart';

/// Owner of the Online foreground service, request notifications and bubble.
final backgroundModeControllerProvider = Provider<BackgroundModeController>((
  ref,
) {
  return BackgroundModeController(
    store: BackgroundModeStore(ref.watch(sharedPreferencesProvider)),
    service: PluginOnlineServiceGateway(),
    platform: ref.watch(riderPlatformProvider),
    notifier: RequestAlertNotifier(),
  );
});

final riderPlatformProvider = Provider<RiderPlatform>(
  (ref) => MethodChannelRiderPlatform(),
);

/// The in-app ring while a request card is on screen.
final incomingRingerProvider = Provider<IncomingRinger>((ref) {
  final ringer = IncomingRinger(SystemRingtoneOutput());
  ref.onDispose(() => unawaited(ringer.stop()));
  return ringer;
});

final riderDeliveryApiServiceProvider = Provider<RiderDeliveryApiService>((
  ref,
) {
  return RiderDeliveryApiService(ref.watch(apiClientProvider));
});

final riderLocationServiceProvider = Provider<RiderLocationService>((ref) {
  final service = RiderLocationService(
    onLocationUpdate: (position) {
      return ref
          .read(riderDeliveryControllerProvider.notifier)
          ._onLocationUpdated(position);
    },
    onLocationIssue: (result) {
      ref
          .read(riderDeliveryControllerProvider.notifier)
          ._onLocationIssue(result);
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

final riderSocketServiceProvider = Provider<RiderSocketService>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  return RiderSocketService(
    // A getter, not a value: ApiClient refreshes the token without
    // rebuilding this provider.
    tokenProvider: () => prefs.accessToken,
    onDeliveryOrderRequest: (request) {
      ref
          .read(riderDeliveryControllerProvider.notifier)
          ._onNewDeliveryRequest(request);
    },
    onOrderRequestExpired: (requestId, orderId) {
      ref
          .read(riderDeliveryControllerProvider.notifier)
          ._onRequestExpired(requestId);
    },
    onOrderAssignedToOther: (requestId, orderId) {
      ref
          .read(riderDeliveryControllerProvider.notifier)
          ._onRequestAssignedToOther(requestId);
    },
    onRestaurantOwnedOrderAssigned: (orderId, restaurantId) {
      ref
          .read(riderDeliveryControllerProvider.notifier)
          ._onRestaurantOwnedOrderAssigned(orderId, restaurantId);
    },
    onConnectionChanged: (connected) {
      ref
          .read(riderDeliveryControllerProvider.notifier)
          ._onSocketConnectionChanged(connected);
    },
  );
});

enum RiderLocationTrackingStatus {
  idle,
  checking,
  active,
  blocked,
  paused,
  failed,
  unauthorized,
}

class RiderDeliveryState {
  const RiderDeliveryState({
    this.isOnline = false,
    this.isAvailable = false,
    this.socketConnected = false,
    this.pollingFallbackActive = false,
    this.pendingRequests = const [],
    this.requestErrorMessage,
    this.activeOrderId,
    this.activeOrder,
    this.seenOfferKeys = const {},
    this.locationStatus = RiderLocationTrackingStatus.idle,
    this.locationMessage = 'Go online to start location tracking.',
    this.locationServiceEnabled = false,
    this.locationPermissionGranted = false,
    this.locationReadiness,
    this.locationActionInProgress = false,
    this.lastLocationUpdate,
    this.lastLocationFailure,
    this.foregroundOnlyTracking = true,
  });

  final bool isOnline;
  final bool isAvailable;
  final bool socketConnected;
  final bool pollingFallbackActive;
  final List<RiderOrderRequestModel> pendingRequests;
  final String? requestErrorMessage;
  final int? activeOrderId;
  final ActiveDeliveryOrderModel? activeOrder;
  final Set<String> seenOfferKeys;
  final RiderLocationTrackingStatus locationStatus;
  final String locationMessage;
  final bool locationServiceEnabled;
  final bool locationPermissionGranted;
  final RiderLocationReadiness? locationReadiness;
  final bool locationActionInProgress;
  final DateTime? lastLocationUpdate;
  final DateTime? lastLocationFailure;
  final bool foregroundOnlyTracking;

  bool get hasActiveDelivery => activeOrderId != null;

  bool get shouldShowLocationStatus =>
      isOnline ||
      locationStatus == RiderLocationTrackingStatus.blocked ||
      locationStatus == RiderLocationTrackingStatus.failed ||
      locationStatus == RiderLocationTrackingStatus.checking ||
      locationStatus == RiderLocationTrackingStatus.unauthorized;

  bool get canRequestLocationPermission =>
      locationReadiness == RiderLocationReadiness.permissionDenied;

  bool get canOpenAppSettings =>
      locationReadiness == RiderLocationReadiness.permissionDeniedForever ||
      locationReadiness == RiderLocationReadiness.reducedAccuracy;

  bool get canOpenLocationSettings =>
      locationReadiness == RiderLocationReadiness.serviceDisabled;

  RiderDeliveryState copyWith({
    bool? isOnline,
    bool? isAvailable,
    bool? socketConnected,
    bool? pollingFallbackActive,
    List<RiderOrderRequestModel>? pendingRequests,
    String? requestErrorMessage,
    bool clearRequestError = false,
    int? activeOrderId,
    bool clearActiveOrderId = false,
    ActiveDeliveryOrderModel? activeOrder,
    bool clearActiveOrder = false,
    Set<String>? seenOfferKeys,
    RiderLocationTrackingStatus? locationStatus,
    String? locationMessage,
    bool? locationServiceEnabled,
    bool? locationPermissionGranted,
    RiderLocationReadiness? locationReadiness,
    bool clearLocationReadiness = false,
    bool? locationActionInProgress,
    DateTime? lastLocationUpdate,
    bool clearLastLocationUpdate = false,
    DateTime? lastLocationFailure,
    bool clearLastLocationFailure = false,
    bool? foregroundOnlyTracking,
  }) {
    return RiderDeliveryState(
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      socketConnected: socketConnected ?? this.socketConnected,
      pollingFallbackActive:
          pollingFallbackActive ?? this.pollingFallbackActive,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      requestErrorMessage: clearRequestError
          ? null
          : (requestErrorMessage ?? this.requestErrorMessage),
      activeOrderId: clearActiveOrderId
          ? null
          : (activeOrderId ?? this.activeOrderId),
      activeOrder: clearActiveOrder ? null : (activeOrder ?? this.activeOrder),
      seenOfferKeys: seenOfferKeys ?? this.seenOfferKeys,
      locationStatus: locationStatus ?? this.locationStatus,
      locationMessage: locationMessage ?? this.locationMessage,
      locationServiceEnabled:
          locationServiceEnabled ?? this.locationServiceEnabled,
      locationPermissionGranted:
          locationPermissionGranted ?? this.locationPermissionGranted,
      locationReadiness: clearLocationReadiness
          ? null
          : (locationReadiness ?? this.locationReadiness),
      locationActionInProgress:
          locationActionInProgress ?? this.locationActionInProgress,
      lastLocationUpdate: clearLastLocationUpdate
          ? null
          : (lastLocationUpdate ?? this.lastLocationUpdate),
      lastLocationFailure: clearLastLocationFailure
          ? null
          : (lastLocationFailure ?? this.lastLocationFailure),
      foregroundOnlyTracking:
          foregroundOnlyTracking ?? this.foregroundOnlyTracking,
    );
  }
}

final riderDeliveryControllerProvider =
    NotifierProvider<RiderDeliveryController, RiderDeliveryState>(
      RiderDeliveryController.new,
    );

class RiderDeliveryController extends Notifier<RiderDeliveryState> {
  static const _idleSendInterval = Duration(seconds: 30);
  static const _activeSendInterval = Duration(seconds: 15);
  static const _duplicateHeartbeatInterval = Duration(minutes: 2);
  static const _fallbackPollInterval = Duration(seconds: 10);
  static const _connectedPollInterval = Duration(seconds: 30);
  static const _idleDistanceMeters = 25.0;
  static const _activeDistanceMeters = 10.0;

  Position? _lastSentPosition;
  DateTime? _lastSentAt;
  bool _sendInFlight = false;
  bool _desiredTracking = false;
  bool _isForeground = true;
  bool _bootstrapInFlight = false;
  Timer? _fallbackPollTimer;
  DateTime? _lastPollAt;
  bool _pollInFlight = false;

  @override
  RiderDeliveryState build() {
    final location = ref.read(riderLocationServiceProvider);
    final socket = ref.read(riderSocketServiceProvider);
    final ringer = ref.read(incomingRingerProvider);
    ref.onDispose(() {
      _desiredTracking = false;
      _stopFallbackPolling(updateState: false);
      location.stopTracking();
      socket.disconnect();
      unawaited(ringer.stop());
    });
    listenSelf(_syncBackgroundMode);
    return const RiderDeliveryState();
  }

  BackgroundModeController get _background =>
      ref.read(backgroundModeControllerProvider);

  /// Keeps background mode in step with state from one place, whichever
  /// path changed it (socket event, poll, accept, decline, expiry, restore).
  void _syncBackgroundMode(
    RiderDeliveryState? previous,
    RiderDeliveryState next,
  ) {
    if (previous?.hasActiveDelivery != next.hasActiveDelivery) {
      unawaited(_background.setActiveDelivery(next.hasActiveDelivery));
    }

    // An offer that left the list was accepted, declined, taken by another
    // rider, or expired: its notification must stop ringing.
    final previousIds =
        previous?.pendingRequests.map((r) => r.requestId).toSet() ?? const {};
    final nextIds = next.pendingRequests.map((r) => r.requestId).toSet();
    for (final requestId in previousIds.difference(nextIds)) {
      unawaited(_background.cancelRequestAlert(requestId));
    }
    if (next.pendingRequests.isEmpty) {
      unawaited(ref.read(incomingRingerProvider).stop());
    }
  }

  Future<void> bootstrapSessionLocation({
    bool requestPermission = false,
  }) async {
    if (_bootstrapInFlight) {
      return;
    }
    _bootstrapInFlight = true;
    try {
      if (!_hasValidSession()) {
        clearSession();
        return;
      }

      final location = ref.read(riderLocationServiceProvider);
      final readiness = await location.checkReadiness(
        requestPermission: requestPermission,
      );
      _applyLocationReadiness(readiness);

      final api = ref.read(riderBackendApiProvider);
      final envelope = await api.rider.getAvailability();
      final availability = _availabilityFromPayload(
        envelope.data,
        fallbackOnline: false,
      );

      state = state.copyWith(
        isOnline: availability.isOnline,
        isAvailable: availability.isAvailable,
        activeOrderId: availability.currentOrderId,
      );

      if (availability.isOnline) {
        // Restores background mode after an app restart while Online. The
        // server is the source of truth for Online, not the device.
        await _background.startOnline(
          hasActiveDelivery: availability.currentOrderId != null,
          locationGranted: readiness.canTrack,
        );
        ref.read(riderSocketServiceProvider).connect();
        _startFallbackPolling();
        await refreshPendingRequests();
        await _startLocationTracking(requestPermission: requestPermission);
        if (availability.currentOrderId != null) {
          await fetchActiveOrder(availability.currentOrderId!);
        } else {
          await refreshActiveOrder();
        }
      } else {
        _desiredTracking = false;
        _stopFallbackPolling();
        location.stopTracking();
        await _background.stopOnline();
        state = state.copyWith(
          locationStatus: readiness.canTrack
              ? RiderLocationTrackingStatus.idle
              : RiderLocationTrackingStatus.blocked,
          locationMessage: readiness.canTrack
              ? 'Location is ready. Go online to start tracking.'
              : readiness.message,
        );
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _markUnauthorized();
      } else {
        state = state.copyWith(
          locationStatus: RiderLocationTrackingStatus.failed,
          locationMessage:
              'Could not confirm rider availability. Location tracking is paused.',
          lastLocationFailure: DateTime.now(),
        );
        _debug('availability bootstrap failed status=${error.statusCode}');
      }
    } catch (error) {
      state = state.copyWith(
        locationStatus: RiderLocationTrackingStatus.failed,
        locationMessage:
            'Could not check location tracking right now. Please try again.',
        lastLocationFailure: DateTime.now(),
      );
      _debug('availability bootstrap error=$error');
    } finally {
      _bootstrapInFlight = false;
    }
  }

  void clearSession() {
    _desiredTracking = false;
    _sendInFlight = false;
    _lastSentAt = null;
    _lastSentPosition = null;
    _stopFallbackPolling();
    ref.read(riderLocationServiceProvider).stopTracking();
    ref.read(riderSocketServiceProvider).disconnect();
    // Sign-out ends everything: service, location, ringing, bubble.
    unawaited(ref.read(incomingRingerProvider).stop());
    unawaited(_background.stopOnline());
    state = const RiderDeliveryState();
  }

  Future<void> toggleOnline(bool online) async {
    if (!_hasValidSession()) {
      _markUnauthorized();
      throw const ApiException(
        message: 'Please sign in again before going online.',
        statusCode: 401,
        errorCode: 'AUTH_REQUIRED',
      );
    }

    final api = ref.read(riderBackendApiProvider);
    final location = ref.read(riderLocationServiceProvider);
    final socket = ref.read(riderSocketServiceProvider);

    if (!online) {
      await api.rider.goOffline();
      _desiredTracking = false;
      _stopFallbackPolling();
      location.stopTracking();
      socket.disconnect();
      await ref.read(incomingRingerProvider).stop();
      await _background.stopOnline();
      state = state.copyWith(
        isOnline: false,
        isAvailable: false,
        socketConnected: false,
        pollingFallbackActive: false,
        pendingRequests: const [],
        clearRequestError: true,
        locationStatus: RiderLocationTrackingStatus.idle,
        locationMessage: 'You are offline. Location tracking is off.',
      );
      _debug('rider offline; location stopped');
      return;
    }

    await _ensureProfileReadyForOnline(api);

    final readiness = await location.checkReadiness(requestPermission: true);
    _applyLocationReadiness(readiness);
    if (!readiness.canTrack) {
      _desiredTracking = false;
      throw ApiException(
        message: readiness.message,
        errorCode: readiness.readiness.name,
      );
    }

    final response = await api.rider.goOnline();
    final availability = _availabilityFromPayload(
      response.data,
      fallbackOnline: true,
    );

    state = state.copyWith(
      isOnline: availability.isOnline,
      isAvailable: availability.isAvailable,
      activeOrderId: availability.currentOrderId,
      clearLastLocationFailure: true,
    );

    if (availability.isOnline) {
      // The rider just tapped Online with the app on screen and location
      // granted, which is when Android allows a location foreground service
      // to start.
      await _background.startOnline(
        hasActiveDelivery: availability.currentOrderId != null,
        locationGranted: readiness.canTrack,
      );
      await _startLocationTracking(requestPermission: false);
      socket.connect();
      _startFallbackPolling();
      await refreshPendingRequests();
      if (availability.currentOrderId != null) {
        await fetchActiveOrder(availability.currentOrderId!);
      } else {
        await refreshActiveOrder();
      }
    }
  }

  Future<void> _ensureProfileReadyForOnline(RiderBackendApi api) async {
    try {
      final envelope = await api.rider.me();
      final profile = RiderComplianceProfile.fromJson(envelope.data);
      final missing = profile.missingItems(
        locationReady: true,
        includeLocation: false,
      );
      if (missing.isNotEmpty) {
        throw ApiException(
          message: 'Complete ${missing.join(', ')} before going online.',
          errorCode: 'PROFILE_INCOMPLETE',
          statusCode: 409,
        );
      }
    } on ApiException catch (error) {
      if (error.errorCode == 'PROFILE_INCOMPLETE') {
        rethrow;
      }
      if (error.statusCode == 404) {
        throw const ApiException(
          message: 'Complete your rider profile before going online.',
          errorCode: 'PROFILE_INCOMPLETE',
          statusCode: 409,
        );
      }
      rethrow;
    }
  }

  Future<void> requestLocationPermission() async {
    state = state.copyWith(locationActionInProgress: true);
    try {
      if (state.isOnline || _desiredTracking) {
        await _startLocationTracking(requestPermission: true);
      } else {
        final result = await ref
            .read(riderLocationServiceProvider)
            .checkReadiness(requestPermission: true);
        _applyLocationReadiness(result);
        if (result.canTrack) {
          state = state.copyWith(
            locationStatus: RiderLocationTrackingStatus.idle,
            locationMessage: 'Location is ready. Go online to start tracking.',
          );
        }
      }
    } finally {
      state = state.copyWith(locationActionInProgress: false);
    }
  }

  Future<void> openLocationSettings() async {
    state = state.copyWith(locationActionInProgress: true);
    try {
      await ref.read(riderLocationServiceProvider).openLocationSettings();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await refreshLocationStatus();
    } finally {
      state = state.copyWith(locationActionInProgress: false);
    }
  }

  Future<void> openAppSettings() async {
    state = state.copyWith(locationActionInProgress: true);
    try {
      await ref.read(riderLocationServiceProvider).openAppSettings();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await refreshLocationStatus();
    } finally {
      state = state.copyWith(locationActionInProgress: false);
    }
  }

  Future<void> refreshLocationStatus() async {
    final result = await ref
        .read(riderLocationServiceProvider)
        .checkReadiness();
    _applyLocationReadiness(result);
    if (result.canTrack && state.isOnline) {
      await _startLocationTracking(requestPermission: false);
    }
  }

  Future<void> retryLocationUpdate() async {
    if (!_hasValidSession()) {
      _markUnauthorized();
      return;
    }
    if (state.isOnline || _desiredTracking) {
      await _startLocationTracking(requestPermission: false);
      await ref.read(riderLocationServiceProvider).refreshCurrentPosition();
    } else {
      await refreshLocationStatus();
    }
  }

  void handleAppLifecycleState(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        _isForeground = true;
        _debug('app resumed');
        // The app alerts in-app again: stop service notifications, hide the
        // bubble.
        unawaited(_background.setAppInForeground(true, online: state.isOnline));
        if (_desiredTracking && state.isOnline) {
          unawaited(_startLocationTracking(requestPermission: false));
          // Tracking pauses in the background, so an offer made while the app
          // was hidden is only on the server. Fetch it now rather than on the
          // next poll, and reconnect a socket the OS may have closed.
          ref.read(riderSocketServiceProvider).connect();
          _startFallbackPolling();
          unawaited(_pollPendingRequests());
        } else if (_hasValidSession()) {
          unawaited(bootstrapSessionLocation());
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _isForeground = false;
        // The in-app location stream stops either way. While Online on
        // Android the foreground service picks uploads up within one
        // interval; elsewhere tracking pauses as before.
        final continuesInBackground = _background.supported && state.isOnline;
        if (_desiredTracking) {
          ref.read(riderLocationServiceProvider).stopTracking();
          state = state.copyWith(
            locationStatus: RiderLocationTrackingStatus.paused,
            locationMessage: continuesInBackground
                ? 'Online in the background. Location sharing continues while the Mangaale Rider notification is showing.'
                : 'Tracking pauses while the app is in the background and resumes when you return.',
          );
        }
        // `inactive` is not "left the app": it covers permission dialogs and
        // the notification shade. Showing the bubble then could cover a
        // system prompt, so only a real move to the background counts.
        if (lifecycleState != AppLifecycleState.inactive) {
          unawaited(ref.read(incomingRingerProvider).stop());
          unawaited(
            _background.setAppInForeground(false, online: state.isOnline),
          );
        }
        _debug(
          'app backgrounded state=${lifecycleState.name} '
          'backgroundMode=$continuesInBackground',
        );
        break;
    }
  }

  void _onLocationIssue(RiderLocationCheckResult result) {
    _applyLocationReadiness(result);
    if (!result.canTrack) {
      state = state.copyWith(
        locationStatus: RiderLocationTrackingStatus.blocked,
        locationMessage: result.message,
      );
    } else if (state.locationStatus != RiderLocationTrackingStatus.active) {
      state = state.copyWith(
        locationStatus: RiderLocationTrackingStatus.failed,
        locationMessage: result.message,
        lastLocationFailure: DateTime.now(),
      );
    }
  }

  Future<void> _onLocationUpdated(Position position) async {
    if (!state.isOnline || !_desiredTracking) {
      return;
    }
    if (!_hasValidSession()) {
      _markUnauthorized();
      return;
    }
    if (!_isUsableCoordinate(position)) {
      _debug('ignored invalid coordinate');
      return;
    }
    if (!_shouldSendPosition(position)) {
      return;
    }
    if (_sendInFlight) {
      _debug('location update skipped; request in flight');
      return;
    }

    _sendInFlight = true;
    try {
      final heading = _safeHeading(position.heading);
      final speed = _safeSpeed(position.speed);
      final envelope = await ref
          .read(riderBackendApiProvider)
          .location
          .updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            heading: heading,
            speed: speed,
          );
      final serverTimestamp = _lastUpdateFromPayload(envelope.data);
      final updatedAt = serverTimestamp ?? DateTime.now();
      _lastSentAt = DateTime.now();
      _lastSentPosition = position;
      // Lets the service skip an upload the app has just made.
      unawaited(_background.recordUpload(_lastSentAt!));
      state = state.copyWith(
        locationStatus: RiderLocationTrackingStatus.active,
        locationMessage: 'Tracking active.',
        lastLocationUpdate: updatedAt,
        clearLastLocationFailure: true,
        locationServiceEnabled: true,
        locationPermissionGranted: true,
        locationReadiness: RiderLocationReadiness.ready,
      );
      _debug(
        'location update success status=${envelope.statusCode ?? 'unknown'} '
        'heading=${heading ?? 'null'} speed=${speed ?? 'null'}',
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _markUnauthorized();
      } else {
        state = state.copyWith(
          locationStatus: RiderLocationTrackingStatus.failed,
          locationMessage: _friendlyLocationApiMessage(error),
          lastLocationFailure: DateTime.now(),
        );
        _debug(
          'location update failed status=${error.statusCode ?? 'unknown'} '
          'code=${error.errorCode ?? 'none'}',
        );
      }
    } catch (error) {
      state = state.copyWith(
        locationStatus: RiderLocationTrackingStatus.failed,
        locationMessage: 'Location update failed. Retrying shortly.',
        lastLocationFailure: DateTime.now(),
      );
      _debug('location update error=$error');
    } finally {
      _sendInFlight = false;
    }
  }

  Future<void> _startLocationTracking({required bool requestPermission}) async {
    if (!_hasValidSession()) {
      _markUnauthorized();
      return;
    }
    _desiredTracking = true;
    if (!_isForeground) {
      state = state.copyWith(
        locationStatus: RiderLocationTrackingStatus.paused,
        locationMessage:
            'Tracking is ready and will resume when the app is in the foreground.',
      );
      return;
    }

    state = state.copyWith(
      locationStatus: RiderLocationTrackingStatus.checking,
      locationMessage: 'Checking location permission...',
    );
    final result = await ref
        .read(riderLocationServiceProvider)
        .startTracking(
          isActiveDelivery: state.hasActiveDelivery,
          requestPermission: requestPermission,
        );
    _applyLocationReadiness(result);
    if (result.canTrack) {
      state = state.copyWith(
        locationStatus: RiderLocationTrackingStatus.active,
        locationMessage: 'Tracking active. Waiting for the next GPS update.',
      );
    } else {
      state = state.copyWith(
        locationStatus: RiderLocationTrackingStatus.blocked,
        locationMessage: result.message,
      );
    }
  }

  void _applyLocationReadiness(RiderLocationCheckResult result) {
    state = state.copyWith(
      locationServiceEnabled: result.serviceEnabled,
      locationPermissionGranted: result.canTrack,
      locationReadiness: result.readiness,
    );
    _debug(
      'permission service=${result.serviceEnabled} permission=${result.permission.name} '
      'accuracy=${result.accuracyStatus.name} readiness=${result.readiness.name}',
    );
  }

  bool _hasValidSession() {
    final prefs = ref.read(appPreferencesProvider);
    final token = prefs.accessToken;
    final rawRole = prefs.rawAuthRole;
    final role = AppRoutes.normalizeRole(rawRole);
    _debug(
      'session check rawRole=${rawRole ?? 'missing'} '
      'normalizedRole=${role ?? 'missing'}',
    );
    return prefs.isAuthenticated &&
        token != null &&
        token.isNotEmpty &&
        role != null &&
        AppRoutes.isSupportedRiderRole(role);
  }

  void _markUnauthorized() {
    _desiredTracking = false;
    _stopFallbackPolling();
    ref.read(riderLocationServiceProvider).stopTracking();
    ref.read(riderSocketServiceProvider).disconnect();
    unawaited(ref.read(incomingRingerProvider).stop());
    unawaited(_background.stopOnline());
    state = state.copyWith(
      isOnline: false,
      isAvailable: false,
      socketConnected: false,
      pollingFallbackActive: false,
      locationStatus: RiderLocationTrackingStatus.unauthorized,
      locationMessage: 'Your session expired. Please sign in again.',
      lastLocationFailure: DateTime.now(),
    );
    ref.read(appRouterRefreshProvider).refresh();
    _debug('location stopped because session is not authorized');
  }

  bool _shouldSendPosition(Position position) {
    final lastPosition = _lastSentPosition;
    final lastSentAt = _lastSentAt;
    if (lastPosition == null || lastSentAt == null) {
      return true;
    }

    final now = DateTime.now();
    final elapsed = now.difference(lastSentAt);
    final minInterval = state.hasActiveDelivery
        ? _activeSendInterval
        : _idleSendInterval;
    if (elapsed < minInterval) {
      _debug('location skipped; interval=${elapsed.inSeconds}s');
      return false;
    }

    final distance = Geolocator.distanceBetween(
      lastPosition.latitude,
      lastPosition.longitude,
      position.latitude,
      position.longitude,
    );
    final threshold = state.hasActiveDelivery
        ? _activeDistanceMeters
        : _idleDistanceMeters;
    if (distance < threshold && elapsed < _duplicateHeartbeatInterval) {
      _debug(
        'location skipped; distance=${distance.toStringAsFixed(1)}m '
        'elapsed=${elapsed.inSeconds}s',
      );
      return false;
    }
    return true;
  }

  bool _isUsableCoordinate(Position position) {
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180;
  }

  double? _safeHeading(double value) {
    if (!value.isFinite || value < 0 || value > 360) {
      return null;
    }
    return value;
  }

  double? _safeSpeed(double value) {
    if (!value.isFinite || value < 0) {
      return null;
    }
    return value;
  }

  DateTime? _lastUpdateFromPayload(Map<String, dynamic> data) {
    final raw = _firstPresent([
      data['last_location_update'],
      _asMap(data['location'])['last_location_update'],
      _asMap(data['rider'])['last_location_update'],
    ]);
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  String _friendlyLocationApiMessage(ApiException error) {
    if (error.statusCode == 0) {
      return 'Network unavailable. Location update failed. Retrying shortly.';
    }
    if ((error.statusCode ?? 0) >= 500) {
      return 'Server could not save location. Retrying shortly.';
    }
    if (error.errorCode == 'MALFORMED_RESPONSE') {
      return 'Server response could not be read. Retrying shortly.';
    }
    return 'Location update failed. Retrying shortly.';
  }

  void _onNewDeliveryRequest(RiderOrderRequestModel request) {
    if (!request.expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      _debug(
        'expired request ignored requestId=${request.requestId} orderId=${request.orderId}',
      );
      return;
    }

    // Compared by offer, not request id: rider-service re-offers a lapsed
    // request under the same id with a new expiry, and that must replace the
    // stale card rather than be dropped as a duplicate.
    final offerKey = _offerKey(request);
    if (state.pendingRequests.any((item) => _offerKey(item) == offerKey)) {
      _debug(
        'duplicate request ignored requestId=${request.requestId} orderId=${request.orderId}',
      );
      return;
    }

    // seenOfferKeys tracks every offer that has reached this rider, so it is
    // the right guard for the alert. Without it an offer replayed after a
    // reconnect — or arriving over both the socket and polling — sounds a
    // second time for an order already seen or handled.
    final isFirstSighting = shouldAlertForRequest(
      offerKey: offerKey,
      seenOfferKeys: state.seenOfferKeys,
    );
    _debug(
      'request received requestId=${request.requestId} orderId=${request.orderId} '
      'firstSighting=$isFirstSighting',
    );
    state = state.copyWith(
      pendingRequests: _mergePendingRequests(state.pendingRequests, [request]),
      seenOfferKeys: {...state.seenOfferKeys, offerKey},
      clearRequestError: true,
    );

    if (isFirstSighting) {
      unawaited(_alertNewOffers([request]));
    }
  }

  /// Alerts once for offers that are new to the rider.
  ///
  /// "New" is decided across the app and the Online service through the
  /// shared alerted list, so an offer the service already rang for while
  /// the app was hidden does not ring again when the rider opens it.
  ///
  ///  * app on screen      -> bounded in-app ring ([IncomingRinger])
  ///  * app not on screen  -> ringing heads-up notification, one per offer
  ///  * no background mode -> the original one-shot sound (iOS, web)
  Future<void> _alertNewOffers(List<RiderOrderRequestModel> offers) async {
    final now = DateTime.now().toUtc();
    final live = offers
        .where((offer) => offer.expiresAt.toUtc().isAfter(now))
        .toList();
    if (live.isEmpty) {
      return;
    }
    final background = _background;
    if (!background.supported) {
      FlutterRingtonePlayer().playNotification();
      return;
    }
    final alreadyAlerted = await background.alertedOfferKeys();
    final fresh = live
        .where((offer) => !alreadyAlerted.contains(_offerKey(offer)))
        .toList();
    if (fresh.isEmpty) {
      _debug('offer already alerted by the Online service');
      return;
    }
    await background.rememberAlerted(fresh.map(_offerKey));
    if (_isForeground) {
      final until = fresh
          .map((offer) => offer.expiresAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      await ref.read(incomingRingerProvider).ring(until: until);
    } else {
      await background.notifyInBackground(fresh);
    }
  }

  void _onRequestExpired(int requestId) {
    _debug('request expired requestId=$requestId');
    state = state.copyWith(
      pendingRequests: state.pendingRequests
          .where((r) => r.requestId != requestId)
          .toList(),
    );
  }

  void _onRequestAssignedToOther(int requestId) {
    _debug('request assigned to other requestId=$requestId');
    state = state.copyWith(
      pendingRequests: state.pendingRequests
          .where((r) => r.requestId != requestId)
          .toList(),
    );
  }

  void _onSocketConnectionChanged(bool connected) {
    state = state.copyWith(socketConnected: connected);
    _debug('socket connected=$connected');
    if (connected) {
      unawaited(refreshPendingRequests());
    } else if (state.isOnline) {
      _startFallbackPolling();
    }
  }

  Future<void> _onRestaurantOwnedOrderAssigned(
    int orderId,
    int? restaurantId,
  ) async {
    // Assignment events are delivered at least once, so the same assignment
    // can arrive again after a reconnect. If this order is already the
    // rider's active order the event is a replay: refresh state, but do not
    // sound the alert a second time.
    final isReplay = !shouldAlertForAssignment(
      orderId: orderId,
      activeOrderId: state.activeOrderId,
    );
    _debug(
      'restaurant-owned assignment orderId=$orderId '
      'restaurantId=${restaurantId ?? 'unknown'} replay=$isReplay',
    );
    state = state.copyWith(
      activeOrderId: orderId,
      isAvailable: false,
      pendingRequests: state.pendingRequests
          .where((request) => request.orderId != orderId)
          .toList(),
    );
    await fetchActiveOrder(orderId);
    ref.invalidate(activeOrdersProvider);

    if (!isReplay) {
      // Ringtone and vibration announce a newly assigned order.
      FlutterRingtonePlayer().playNotification();
    }
  }

  Future<void> refreshPendingRequests() async {
    try {
      final response = await ref
          .read(riderDeliveryApiServiceProvider)
          .getPendingOrderRequests();

      final pending = _mergePendingRequests(const [], response.data);
      final offerKeys = pending.map(_offerKey).toList();
      // This is the only path that delivers an offer while the socket is
      // down, so it has to ring for a new one exactly as the socket would.
      final hasNewOffer = shouldAlertForSnapshot(
        offerKeys: offerKeys,
        seenOfferKeys: state.seenOfferKeys,
      );
      final newOffers = pending
          .where((request) => !state.seenOfferKeys.contains(_offerKey(request)))
          .toList();
      state = state.copyWith(
        pendingRequests: pending,
        seenOfferKeys: {...state.seenOfferKeys, ...offerKeys},
        clearRequestError: true,
      );
      _debug(
        'pending requests refresh success status=${response.statusCode ?? 'unknown'} '
        'count=${response.data.length} newOffer=$hasNewOffer',
      );
      if (hasNewOffer) {
        unawaited(_alertNewOffers(newOffers));
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _markUnauthorized();
      } else if (error.statusCode == 404) {
        state = state.copyWith(
          pendingRequests: const [],
          clearRequestError: true,
        );
        _debug('pending requests refresh empty status=404');
      } else {
        state = state.copyWith(
          requestErrorMessage: _requestErrorMessage(error),
        );
        _debug(
          'pending requests refresh failed status=${error.statusCode ?? 'unknown'} code=${error.errorCode ?? 'none'}',
        );
      }
    } catch (error) {
      state = state.copyWith(
        requestErrorMessage: 'Could not refresh order requests.',
      );
      _debug('pending requests refresh failed error=$error');
    }
  }

  Future<void> fetchActiveOrder(int orderId) async {
    try {
      final response = await ref
          .read(riderDeliveryApiServiceProvider)
          .getActiveDeliveryOrder(orderId);
      final resolvedOrderId = response.data.orderId > 0
          ? response.data.orderId
          : orderId;
      state = state.copyWith(
        activeOrder: response.data,
        activeOrderId: resolvedOrderId == 0 ? null : resolvedOrderId,
        clearRequestError: true,
      );
      ref.invalidate(activeOrdersProvider);
      _debug(
        'active order refresh success status=${response.statusCode ?? 'unknown'} orderId=${response.data.orderId}',
      );
      if (state.isOnline) {
        await _startLocationTracking(requestPermission: false);
      }
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        state = state.copyWith(
          clearActiveOrder: true,
          clearActiveOrderId: true,
        );
        _debug('active order refresh empty status=404');
        return;
      }
      if (error.statusCode == 401) {
        _markUnauthorized();
        return;
      }
      state = state.copyWith(requestErrorMessage: _requestErrorMessage(error));
      _debug(
        'active order fetch failed status=${error.statusCode ?? 'unknown'} code=${error.errorCode ?? 'none'}',
      );
    } catch (error) {
      state = state.copyWith(
        requestErrorMessage: 'Could not refresh active order.',
      );
      _debug('active order fetch failed error=$error');
    }
  }

  Future<void> refreshActiveOrder() =>
      fetchActiveOrder(state.activeOrderId ?? state.activeOrder?.orderId ?? 0);

  Future<void> acceptRequest(int requestId) async {
    // The rider has answered: stop ringing whatever the outcome.
    unawaited(ref.read(incomingRingerProvider).stop());
    unawaited(_background.cancelRequestAlert(requestId));
    try {
      final pendingOrderId = _pendingOrderIdForRequest(requestId);
      final response = await ref
          .read(riderDeliveryApiServiceProvider)
          .acceptOrderRequest(requestId);
      _debug(
        'accept request success status=${response.statusCode ?? 'unknown'} requestId=$requestId',
      );
      state = state.copyWith(
        isAvailable: false,
        pendingRequests: state.pendingRequests
            .where((r) => r.requestId != requestId)
            .toList(),
        clearRequestError: true,
      );
      final acceptedOrderId = _acceptedOrderId(response.data) ?? pendingOrderId;
      if (acceptedOrderId != null && acceptedOrderId > 0) {
        state = state.copyWith(activeOrderId: acceptedOrderId);
      }
      await refreshActiveOrder();
      if (state.activeOrder == null) {
        throw const ApiException(
          message: 'Order accepted, but active order could not be loaded.',
          errorCode: 'ACTIVE_ORDER_REFRESH_FAILED',
        );
      }
      ref.invalidate(activeOrdersProvider);
      if (state.isOnline) {
        await _startLocationTracking(requestPermission: false);
      }
    } on ApiException catch (e) {
      _debug(
        'accept request failed status=${e.statusCode ?? 'unknown'} code=${e.errorCode ?? 'none'} requestId=$requestId',
      );
      rethrow;
    } catch (e) {
      _debug('accept request failed error=$e requestId=$requestId');
      rethrow;
    }
  }

  Future<void> rejectRequest(int requestId) async {
    unawaited(ref.read(incomingRingerProvider).stop());
    unawaited(_background.cancelRequestAlert(requestId));
    try {
      await ref
          .read(riderDeliveryApiServiceProvider)
          .rejectOrderRequest(requestId);
      _debug('reject request success requestId=$requestId');
      state = state.copyWith(
        pendingRequests: state.pendingRequests
            .where((r) => r.requestId != requestId)
            .toList(),
        clearRequestError: true,
      );
      await refreshPendingRequests();
    } on ApiException catch (e) {
      _debug(
        'reject request failed status=${e.statusCode ?? 'unknown'} code=${e.errorCode ?? 'none'} requestId=$requestId',
      );
      rethrow;
    } catch (e) {
      _debug('reject request failed error=$e requestId=$requestId');
      rethrow;
    }
  }

  Future<void> updateDeliveryStatus(
    String newStatus, {
    bool? paymentCollected,
    String? notes,
  }) async {
    final currentOrderId = state.activeOrderId ?? state.activeOrder?.orderId;
    if (currentOrderId == null || currentOrderId <= 0) return;

    try {
      final previousOrder = state.activeOrder;
      await fetchActiveOrder(currentOrderId);
      final activeOrder = state.activeOrder ?? previousOrder;
      final resolvedOrderId =
          state.activeOrderId ?? activeOrder?.orderId ?? currentOrderId;
      final orderIdStr = resolvedOrderId.toString();
      final isRestaurantOwned = activeOrder?.isRestaurantOwned ?? false;
      final useLegacyEndpoint =
          !isRestaurantOwned &&
          _isLegacySharedOrderStatus(activeOrder?.deliveryStatus) &&
          activeOrder?.deliveryOrderId == null;

      _debug(
        'status action mode=${isRestaurantOwned ? 'restaurant_owned' : 'platform'} '
        'orderId=$resolvedOrderId current=${activeOrder?.deliveryStatus ?? 'unknown'} '
        'next=$newStatus assignmentType=${activeOrder?.assignmentType ?? 'unknown'} '
        'deliveryOrderId=${activeOrder?.deliveryOrderId ?? 'none'}',
      );

      if (!useLegacyEndpoint) {
        final response = await ref
            .read(riderDeliveryApiServiceProvider)
            .updateDeliveryStatus(
              orderId: resolvedOrderId,
              deliveryStatus: newStatus,
              paymentCollected: paymentCollected,
              notes: notes,
            );
        _debug(
          'status action result endpoint=/api/v1/riders/orders/:orderId/status '
          'http=${response.statusCode ?? 'unknown'} orderId=$resolvedOrderId next=$newStatus',
        );
      } else {
        final api = ref.read(riderBackendApiProvider).delivery;
        switch (newStatus) {
          case 'rider_arrived_restaurant':
            final response = await api.arrivedAtRestaurant(orderIdStr);
            _debug(
              'status action result endpoint=legacy-arrived-restaurant '
              'http=${response.statusCode ?? 'unknown'}',
            );
            break;
          case 'picked_up':
            final response = await api.pickedUp(orderIdStr);
            _debug(
              'status action result endpoint=legacy-picked-up '
              'http=${response.statusCode ?? 'unknown'}',
            );
            break;
          case 'on_the_way':
            final response = await api.arrivedAtCustomer(orderIdStr);
            _debug(
              'status action result endpoint=legacy-arrived-customer '
              'http=${response.statusCode ?? 'unknown'}',
            );
            break;
          case 'delivered':
            final response = await api.delivered(
              orderIdStr,
              paymentCollected: paymentCollected,
              notes: notes,
            );
            _debug(
              'status action result endpoint=legacy-delivered '
              'http=${response.statusCode ?? 'unknown'}',
            );
            break;
          default:
            final response = await ref
                .read(riderDeliveryApiServiceProvider)
                .updateDeliveryStatus(
                  orderId: resolvedOrderId,
                  deliveryStatus: newStatus,
                  paymentCollected: paymentCollected,
                  notes: notes,
                );
            _debug(
              'status action result endpoint=/api/v1/riders/orders/:orderId/status '
              'http=${response.statusCode ?? 'unknown'} orderId=$resolvedOrderId next=$newStatus',
            );
        }
      }

      if (newStatus == 'delivered') {
        state = state.copyWith(
          clearActiveOrder: true,
          clearActiveOrderId: true,
          isAvailable: state.isOnline,
        );
        ref.invalidate(activeOrdersProvider);
        ref.invalidate(deliveredOrdersProvider);
        if (state.isOnline) {
          await _startLocationTracking(requestPermission: false);
        }
      } else {
        await fetchActiveOrder(resolvedOrderId);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 409 || e.statusCode == 400) {
        // State mismatch with backend, refresh active order.
        await fetchActiveOrder(currentOrderId);
      }
      _debug(
        'status action failed status=${e.statusCode ?? 'unknown'} '
        'code=${e.errorCode ?? 'none'} next=$newStatus',
      );
      rethrow;
    } catch (e) {
      _debug('status action failed error=$e next=$newStatus');
      rethrow;
    }
  }

  /// Polls pending offers while the rider is online.
  ///
  /// This was once reduced to a no-op on the assumption that the socket
  /// always reconnects. In production it could not connect at all — the
  /// proxy in front of rider-service dropped the WebSocket upgrade — so no
  /// offer reached the app and nothing rang. Polling is the floor the socket
  /// improves on, not a second listener to avoid: every [_fallbackPollInterval]
  /// while the socket is down, and every [_connectedPollInterval] while it is
  /// up, since a socket can look open after the far end has gone.
  ///
  /// Offers are 30 seconds long; a 10-second poll leaves the rider at least
  /// 20 of them.
  void _startFallbackPolling() {
    if (_fallbackPollTimer == null) {
      _debug('fallback polling started');
      _fallbackPollTimer = Timer.periodic(_fallbackPollInterval, (_) {
        if (!state.isOnline) {
          _stopFallbackPolling();
          return;
        }
        // Off screen, the Online service polls on the same cadence; polling
        // here too would double the requests. The socket stays connected and
        // still delivers instantly.
        if (!_isForeground && _background.supported) {
          return;
        }
        final lastPoll = _lastPollAt;
        if (state.socketConnected &&
            lastPoll != null &&
            DateTime.now().difference(lastPoll) < _connectedPollInterval) {
          return;
        }
        unawaited(_pollPendingRequests());
      });
    }
    if (!state.pollingFallbackActive) {
      state = state.copyWith(pollingFallbackActive: true);
    }
  }

  Future<void> _pollPendingRequests() async {
    if (_pollInFlight) {
      return;
    }
    _pollInFlight = true;
    _lastPollAt = DateTime.now();
    try {
      await refreshPendingRequests();
    } finally {
      _pollInFlight = false;
    }
  }

  bool _isLegacySharedOrderStatus(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'ready':
      case 'out_for_delivery':
        return true;
      default:
        return false;
    }
  }

  void _stopFallbackPolling({bool updateState = true}) {
    if (_fallbackPollTimer != null) {
      _debug('fallback polling stopped');
    }
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = null;
    _lastPollAt = null;
    if (updateState && state.pollingFallbackActive) {
      state = state.copyWith(pollingFallbackActive: false);
    }
  }

  List<RiderOrderRequestModel> _mergePendingRequests(
    List<RiderOrderRequestModel> existing,
    List<RiderOrderRequestModel> incoming,
  ) {
    final byKey = <String, RiderOrderRequestModel>{};
    for (final request in [...existing, ...incoming]) {
      if (request.requestId <= 0 && request.orderId <= 0) {
        _debug('ignored malformed request without identifiers');
        continue;
      }
      byKey[_requestKey(request)] = request;
    }
    final now = DateTime.now().toUtc();
    final requests = byKey.values
        .where((request) => request.expiresAt.toUtc().isAfter(now))
        .toList();
    requests.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return requests;
  }

  String _offerKey(RiderOrderRequestModel request) => requestOfferKey(
    requestId: request.requestId,
    expiresAt: request.expiresAt,
  );

  String _requestKey(RiderOrderRequestModel request) {
    if (request.requestId > 0) {
      return 'DELIVERY_ORDER_REQUEST:${request.requestId}';
    }
    return 'DELIVERY_ORDER_REQUEST:order:${request.orderId}';
  }

  int? _pendingOrderIdForRequest(int requestId) {
    for (final request in state.pendingRequests) {
      if (request.requestId == requestId && request.orderId > 0) {
        return request.orderId;
      }
    }
    return null;
  }

  int? _acceptedOrderId(Map<String, dynamic> data) {
    final order = _asMap(data['order']);
    return _asIntOrNull(
      _firstPresent([
        data['order_id'],
        data['id'],
        order['id'],
        order['order_id'],
      ]),
    );
  }

  String _requestErrorMessage(ApiException error) {
    if (error.statusCode == 0) {
      return 'Network unavailable. Retrying order requests.';
    }
    if (error.statusCode == 401) {
      return 'Your session expired. Please sign in again.';
    }
    if ((error.statusCode ?? 0) >= 500) {
      return 'Server could not refresh order requests. Retrying shortly.';
    }
    return error.message;
  }

  void _debug(String message) {
    assert(() {
      debugPrint('[RiderDelivery] $message');
      return true;
    }());
  }
}

RiderAvailabilityModel _availabilityFromPayload(
  Map<String, dynamic> data, {
  required bool fallbackOnline,
}) {
  final rider = _asMap(data['rider']);
  final availability = _asMap(data['availability']);
  final currentOrderId = _asIntOrNull(
    _firstPresent([
      data['current_order_id'],
      data['active_order_id'],
      data['order_id'],
      rider['current_order_id'],
      availability['current_order_id'],
    ]),
  );
  final onTrip =
      _asBool(_firstPresent([data['on_trip'], rider['on_trip']])) ?? false;
  final isAvailable =
      _asBool(
        _firstPresent([
          data['is_available'],
          data['available_for_assignment'],
          availability['is_available'],
          rider['is_available'],
        ]),
      ) ??
      fallbackOnline;
  final parsedOnline = _asBool(
    _firstPresent([
      data['is_online'],
      data['online'],
      data['is_available'],
      availability['is_online'],
      rider['is_online'],
    ]),
  );
  final isOnline =
      parsedOnline ??
      (isAvailable || onTrip || currentOrderId != null || fallbackOnline);

  return RiderAvailabilityModel(
    isOnline: isOnline,
    isAvailable: isAvailable && !onTrip && currentOrderId == null,
    currentOrderId: currentOrderId,
  );
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const <String, dynamic>{};
}

Object? _firstPresent(List<Object?> values) {
  for (final value in values) {
    if (value == null) {
      continue;
    }
    if (value is String && value.trim().isEmpty) {
      continue;
    }
    return value;
  }
  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'online') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'offline') {
      return false;
    }
  }
  return null;
}

int? _asIntOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}
