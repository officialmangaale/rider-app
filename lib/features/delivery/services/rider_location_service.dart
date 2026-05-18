import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum RiderLocationReadiness {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  reducedAccuracy,
  unavailable,
}

class RiderLocationCheckResult {
  const RiderLocationCheckResult({
    required this.readiness,
    required this.serviceEnabled,
    required this.permission,
    required this.accuracyStatus,
    required this.message,
  });

  final RiderLocationReadiness readiness;
  final bool serviceEnabled;
  final LocationPermission permission;
  final LocationAccuracyStatus accuracyStatus;
  final String message;

  bool get canTrack =>
      serviceEnabled &&
      (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse);

  bool get canRequestPermission =>
      readiness == RiderLocationReadiness.permissionDenied;

  bool get shouldOpenAppSettings =>
      readiness == RiderLocationReadiness.permissionDeniedForever ||
      readiness == RiderLocationReadiness.reducedAccuracy;

  bool get shouldOpenLocationSettings =>
      readiness == RiderLocationReadiness.serviceDisabled;

  factory RiderLocationCheckResult.ready({
    required LocationPermission permission,
    required LocationAccuracyStatus accuracyStatus,
  }) {
    return RiderLocationCheckResult(
      readiness: accuracyStatus == LocationAccuracyStatus.reduced
          ? RiderLocationReadiness.reducedAccuracy
          : RiderLocationReadiness.ready,
      serviceEnabled: true,
      permission: permission,
      accuracyStatus: accuracyStatus,
      message: accuracyStatus == LocationAccuracyStatus.reduced
          ? 'Precise location is off. Turn it on for reliable delivery tracking.'
          : 'Location is ready.',
    );
  }

  factory RiderLocationCheckResult.serviceDisabled({
    LocationPermission permission = LocationPermission.unableToDetermine,
    LocationAccuracyStatus accuracyStatus = LocationAccuracyStatus.unknown,
  }) {
    return RiderLocationCheckResult(
      readiness: RiderLocationReadiness.serviceDisabled,
      serviceEnabled: false,
      permission: permission,
      accuracyStatus: accuracyStatus,
      message:
          'GPS is disabled. Enable location services to share your live position.',
    );
  }

  factory RiderLocationCheckResult.permissionDenied({
    required bool forever,
    required bool serviceEnabled,
    LocationAccuracyStatus accuracyStatus = LocationAccuracyStatus.unknown,
  }) {
    return RiderLocationCheckResult(
      readiness: forever
          ? RiderLocationReadiness.permissionDeniedForever
          : RiderLocationReadiness.permissionDenied,
      serviceEnabled: serviceEnabled,
      permission: forever
          ? LocationPermission.deniedForever
          : LocationPermission.denied,
      accuracyStatus: accuracyStatus,
      message: forever
          ? 'Location permission is blocked. Open settings to allow access.'
          : 'Location permission is required before you can go online.',
    );
  }

  factory RiderLocationCheckResult.unavailable(String message) {
    return RiderLocationCheckResult(
      readiness: RiderLocationReadiness.unavailable,
      serviceEnabled: true,
      permission: LocationPermission.unableToDetermine,
      accuracyStatus: LocationAccuracyStatus.unknown,
      message: message,
    );
  }
}

class RiderLocationService {
  RiderLocationService({
    required this.onLocationUpdate,
    required this.onLocationIssue,
  });

  final Future<void> Function(Position position) onLocationUpdate;
  final void Function(RiderLocationCheckResult result) onLocationIssue;

  StreamSubscription<Position>? _positionStream;
  Timer? _pollTimer;
  Position? _lastPosition;
  bool _isActiveDelivery = false;
  bool _isPolling = false;

  bool get isTracking => _positionStream != null || _pollTimer != null;
  Position? get lastPosition => _lastPosition;

  Future<RiderLocationCheckResult> checkReadiness({
    bool requestPermission = false,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();

      if (!serviceEnabled) {
        _debug('readiness serviceEnabled=false permission=${permission.name}');
        return RiderLocationCheckResult.serviceDisabled(permission: permission);
      }

      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _debug('readiness permission=denied');
        return RiderLocationCheckResult.permissionDenied(
          forever: false,
          serviceEnabled: serviceEnabled,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        _debug('readiness permission=deniedForever');
        return RiderLocationCheckResult.permissionDenied(
          forever: true,
          serviceEnabled: serviceEnabled,
        );
      }

      final accuracyStatus = await _locationAccuracy();
      final result = RiderLocationCheckResult.ready(
        permission: permission,
        accuracyStatus: accuracyStatus,
      );
      _debug(
        'readiness ready permission=${permission.name} accuracy=${accuracyStatus.name}',
      );
      return result;
    } catch (error) {
      _debug('readiness error=$error');
      return RiderLocationCheckResult.unavailable(
        'Could not check location right now. Please try again.',
      );
    }
  }

  Future<RiderLocationCheckResult> startTracking({
    required bool isActiveDelivery,
    bool requestPermission = true,
  }) async {
    _isActiveDelivery = isActiveDelivery;
    final readiness = await checkReadiness(
      requestPermission: requestPermission,
    );
    if (!readiness.canTrack) {
      stopTracking();
      onLocationIssue(readiness);
      return readiness;
    }

    await _positionStream?.cancel();
    _pollTimer?.cancel();
    _positionStream = null;
    _pollTimer = null;

    final settings = LocationSettings(
      accuracy: isActiveDelivery
          ? LocationAccuracy.high
          : LocationAccuracy.medium,
      distanceFilter: isActiveDelivery ? 15 : 35,
    );
    final pollInterval = isActiveDelivery
        ? const Duration(seconds: 20)
        : const Duration(seconds: 30);

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          _handlePosition,
          onError: (Object error) {
            _debug('position stream error=$error');
            onLocationIssue(_resultForLocationError(error));
          },
          cancelOnError: false,
        );

    await _pollCurrentPosition(settings);
    _pollTimer = Timer.periodic(
      pollInterval,
      (_) => unawaited(_pollCurrentPosition(settings)),
    );

    _debug(
      'tracking started activeDelivery=$isActiveDelivery interval=${pollInterval.inSeconds}s',
    );
    return readiness;
  }

  Future<void> refreshCurrentPosition() async {
    final readiness = await checkReadiness();
    if (!readiness.canTrack) {
      onLocationIssue(readiness);
      return;
    }
    await _pollCurrentPosition(
      LocationSettings(
        accuracy: _isActiveDelivery
            ? LocationAccuracy.high
            : LocationAccuracy.medium,
      ),
    );
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  void stopTracking() {
    _debug('tracking stopped');
    _positionStream?.cancel();
    _pollTimer?.cancel();
    _positionStream = null;
    _pollTimer = null;
    _isPolling = false;
  }

  void dispose() => stopTracking();

  void _handlePosition(Position position) {
    _lastPosition = position;
    _debugPosition('position stream', position);
    unawaited(onLocationUpdate(position));
  }

  Future<void> _pollCurrentPosition(LocationSettings settings) async {
    if (_isPolling) {
      return;
    }
    _isPolling = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 15));
      _lastPosition = position;
      _debugPosition('position poll', position);
      await onLocationUpdate(position);
    } on TimeoutException {
      onLocationIssue(
        RiderLocationCheckResult.unavailable(
          'Still waiting for a GPS fix. Location updates will retry.',
        ),
      );
    } catch (error) {
      _debug('position poll error=$error');
      onLocationIssue(_resultForLocationError(error));
    } finally {
      _isPolling = false;
    }
  }

  Future<LocationAccuracyStatus> _locationAccuracy() async {
    try {
      return await Geolocator.getLocationAccuracy();
    } catch (_) {
      return LocationAccuracyStatus.unknown;
    }
  }

  RiderLocationCheckResult _resultForLocationError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('service') && text.contains('disabled')) {
      return RiderLocationCheckResult.serviceDisabled();
    }
    if (text.contains('permission')) {
      return RiderLocationCheckResult.permissionDenied(
        forever: false,
        serviceEnabled: true,
      );
    }
    return RiderLocationCheckResult.unavailable(
      'Location update failed. Retrying shortly.',
    );
  }

  void _debug(String message) {
    assert(() {
      debugPrint('[RiderLocation] $message');
      return true;
    }());
  }

  void _debugPosition(String source, Position position) {
    assert(() {
      debugPrint(
        '[RiderLocation] $source lat=${position.latitude} lng=${position.longitude} '
        'heading=${position.heading} speed=${position.speed}',
      );
      return true;
    }());
  }
}
