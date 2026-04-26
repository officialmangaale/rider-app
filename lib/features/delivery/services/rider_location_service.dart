import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class RiderLocationService {
  RiderLocationService({
    required this.onLocationUpdate,
  });

  final Function(Position position) onLocationUpdate;

  StreamSubscription<Position>? _positionStream;
  Timer? _idleTimer;
  Position? _lastPosition;
  bool _isActiveDelivery = false;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  void startTracking({bool isActiveDelivery = false}) async {
    _isActiveDelivery = isActiveDelivery;
    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    _positionStream?.cancel();
    _idleTimer?.cancel();

    if (_isActiveDelivery) {
      // Active delivery: updates every 5-10 seconds based on distance/time
      final settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
      );
      _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen((position) {
        _lastPosition = position;
        onLocationUpdate(position);
      });
      // Fallback timer if rider doesn't move
      _idleTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        if (_lastPosition != null) {
          onLocationUpdate(_lastPosition!);
        }
      });
    } else {
      // Idle online: updates every 30 seconds
      try {
        _lastPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium);
        if (_lastPosition != null) {
          onLocationUpdate(_lastPosition!);
        }
      } catch (_) {}

      _idleTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        try {
          _lastPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium);
          if (_lastPosition != null) {
            onLocationUpdate(_lastPosition!);
          }
        } catch (_) {}
      });
    }
  }

  void stopTracking() {
    _positionStream?.cancel();
    _idleTimer?.cancel();
    _positionStream = null;
    _idleTimer = null;
  }
}
