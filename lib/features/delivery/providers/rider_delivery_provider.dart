import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/services/rider_backend_api.dart';
import '../../../domain/entities/rider_compliance_models.dart';
import '../../../presentation/providers/core_providers.dart';
import '../models/delivery_models.dart';
import '../services/rider_delivery_api_service.dart';
import '../services/rider_location_service.dart';
import '../services/rider_socket_service.dart';

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
    token: prefs.accessToken ?? '',
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
    this.pendingRequests = const [],
    this.activeOrderId,
    this.activeOrder,
    this.seenRequestIds = const {},
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
  final List<RiderOrderRequestModel> pendingRequests;
  final int? activeOrderId;
  final ActiveDeliveryOrderModel? activeOrder;
  final Set<int> seenRequestIds;
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
    List<RiderOrderRequestModel>? pendingRequests,
    int? activeOrderId,
    bool clearActiveOrderId = false,
    ActiveDeliveryOrderModel? activeOrder,
    bool clearActiveOrder = false,
    Set<int>? seenRequestIds,
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
      pendingRequests: pendingRequests ?? this.pendingRequests,
      activeOrderId: clearActiveOrderId
          ? null
          : (activeOrderId ?? this.activeOrderId),
      activeOrder: clearActiveOrder ? null : (activeOrder ?? this.activeOrder),
      seenRequestIds: seenRequestIds ?? this.seenRequestIds,
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
  static const _idleDistanceMeters = 25.0;
  static const _activeDistanceMeters = 10.0;

  Position? _lastSentPosition;
  DateTime? _lastSentAt;
  bool _sendInFlight = false;
  bool _desiredTracking = false;
  bool _isForeground = true;
  bool _bootstrapInFlight = false;

  @override
  RiderDeliveryState build() {
    final location = ref.read(riderLocationServiceProvider);
    final socket = ref.read(riderSocketServiceProvider);
    ref.onDispose(() {
      _desiredTracking = false;
      location.stopTracking();
      socket.disconnect();
    });
    return const RiderDeliveryState();
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
        await _startLocationTracking(requestPermission: requestPermission);
      } else {
        _desiredTracking = false;
        location.stopTracking();
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
    ref.read(riderLocationServiceProvider).stopTracking();
    ref.read(riderSocketServiceProvider).disconnect();
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
      location.stopTracking();
      socket.disconnect();
      state = state.copyWith(
        isOnline: false,
        isAvailable: false,
        socketConnected: false,
        pendingRequests: const [],
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
      await _startLocationTracking(requestPermission: false);
      socket.connect();
      state = state.copyWith(socketConnected: true);
      await refreshPendingRequests();
      if (availability.currentOrderId != null) {
        await fetchActiveOrder(availability.currentOrderId!);
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
        if (_desiredTracking && state.isOnline) {
          unawaited(_startLocationTracking(requestPermission: false));
        } else if (_hasValidSession()) {
          unawaited(bootstrapSessionLocation());
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _isForeground = false;
        if (_desiredTracking) {
          ref.read(riderLocationServiceProvider).stopTracking();
          state = state.copyWith(
            locationStatus: RiderLocationTrackingStatus.paused,
            locationMessage:
                'Tracking pauses while the app is in the background and resumes when you return.',
          );
        }
        _debug('app backgrounded; foreground-only tracking paused');
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
    ref.read(riderLocationServiceProvider).stopTracking();
    ref.read(riderSocketServiceProvider).disconnect();
    state = state.copyWith(
      isOnline: false,
      isAvailable: false,
      socketConnected: false,
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
    if (state.seenRequestIds.contains(request.requestId)) return;

    final updatedSeen = Set<int>.from(state.seenRequestIds)
      ..add(request.requestId);
    state = state.copyWith(
      pendingRequests: [...state.pendingRequests, request],
      seenRequestIds: updatedSeen,
    );
  }

  void _onRequestExpired(int requestId) {
    state = state.copyWith(
      pendingRequests: state.pendingRequests
          .where((r) => r.requestId != requestId)
          .toList(),
    );
  }

  void _onRequestAssignedToOther(int requestId) {
    state = state.copyWith(
      pendingRequests: state.pendingRequests
          .where((r) => r.requestId != requestId)
          .toList(),
    );
  }

  Future<void> refreshPendingRequests() async {
    try {
      final response = await ref
          .read(riderDeliveryApiServiceProvider)
          .getPendingOrderRequests();

      state = state.copyWith(pendingRequests: response.data);
    } catch (error) {
      _debug('pending requests refresh failed=$error');
    }
  }

  Future<void> fetchActiveOrder(int orderId) async {
    try {
      final response = await ref
          .read(riderDeliveryApiServiceProvider)
          .getActiveDeliveryOrder(orderId);
      state = state.copyWith(
        activeOrder: response.data,
        activeOrderId: orderId,
      );
      if (state.isOnline) {
        await _startLocationTracking(requestPermission: false);
      }
    } catch (error) {
      _debug('active order fetch failed=$error');
    }
  }

  Future<void> acceptRequest(int requestId) async {
    try {
      final response = await ref
          .read(riderDeliveryApiServiceProvider)
          .acceptOrderRequest(requestId);
      state = state.copyWith(
        activeOrder: response.data,
        activeOrderId: response.data.orderId,
        isAvailable: false,
        pendingRequests: state.pendingRequests
            .where((r) => r.requestId != requestId)
            .toList(),
      );
      if (state.isOnline) {
        await _startLocationTracking(requestPermission: false);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectRequest(int requestId) async {
    try {
      await ref
          .read(riderDeliveryApiServiceProvider)
          .rejectOrderRequest(requestId);
      state = state.copyWith(
        pendingRequests: state.pendingRequests
            .where((r) => r.requestId != requestId)
            .toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateDeliveryStatus(String newStatus) async {
    if (state.activeOrderId == null) return;

    try {
      final api = ref.read(riderBackendApiProvider).delivery;
      final orderIdStr = state.activeOrderId!.toString();

      switch (newStatus) {
        case 'rider_arrived_restaurant':
          await api.arrivedAtRestaurant(orderIdStr);
          break;
        case 'picked_up':
          await api.pickedUp(orderIdStr);
          break;
        case 'on_the_way':
          await api.arrivedAtCustomer(orderIdStr);
          break;
        case 'delivered':
          await api.delivered(orderIdStr);
          break;
        default:
          await ref
              .read(riderDeliveryApiServiceProvider)
              .updateDeliveryStatus(
                orderId: state.activeOrderId!,
                deliveryStatus: newStatus,
              );
      }

      if (newStatus == 'delivered') {
        state = state.copyWith(
          clearActiveOrder: true,
          clearActiveOrderId: true,
          isAvailable: state.isOnline,
        );
        if (state.isOnline) {
          await _startLocationTracking(requestPermission: false);
        }
      } else {
        await fetchActiveOrder(state.activeOrderId!);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 409 || e.statusCode == 400) {
        // State mismatch with backend, refresh active order.
        await fetchActiveOrder(state.activeOrderId!);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
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
