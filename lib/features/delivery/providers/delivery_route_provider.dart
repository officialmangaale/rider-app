import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_exception.dart';
import '../models/delivery_map_data.dart';
import '../models/delivery_models.dart';
import '../models/delivery_polyline_decoder.dart';
import '../models/delivery_route.dart';
import '../models/delivery_route_policy.dart';
import 'rider_delivery_provider.dart';

final deliveryRouteControllerProvider =
    NotifierProvider<DeliveryRouteController, DeliveryRouteState>(
      DeliveryRouteController.new,
    );

enum DeliveryRouteStatus { idle, loading, ready, unavailable }

class DeliveryRouteState {
  const DeliveryRouteState({
    this.status = DeliveryRouteStatus.idle,
    this.route,
    this.activeKey,
    this.errorCode,
  });

  final DeliveryRouteStatus status;
  final DeliveryRouteModel? route;
  final String? activeKey;
  final String? errorCode;

  DeliveryRouteState copyWith({
    DeliveryRouteStatus? status,
    DeliveryRouteModel? route,
    bool clearRoute = false,
    String? activeKey,
    bool clearActiveKey = false,
    String? errorCode,
    bool clearError = false,
  }) {
    return DeliveryRouteState(
      status: status ?? this.status,
      route: clearRoute ? null : (route ?? this.route),
      activeKey: clearActiveKey ? null : (activeKey ?? this.activeKey),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

String? deliveryRouteKeyFor(ActiveDeliveryOrderModel? order) {
  if (order == null || isTerminalDeliveryMapPhase(order)) return null;
  return '${order.orderId}:${order.orderType}:${deliveryMapPhaseFor(order).name}';
}

class DeliveryRouteController extends Notifier<DeliveryRouteState> {
  final DeliveryRoutePolicy _policy = const DeliveryRoutePolicy();

  DateTime? _lastRequestAt;
  DeliveryRoutePoint? _lastRequestOrigin;
  String? _lastKey;
  int _generation = 0;
  bool _inFlight = false;
  int _offRouteSamples = 0;

  @override
  DeliveryRouteState build() => const DeliveryRouteState();

  Future<void> sync({
    required ActiveDeliveryOrderModel? order,
    required Position? position,
    required bool enabled,
    bool force = false,
  }) async {
    final key = deliveryRouteKeyFor(order);
    if (!enabled || order == null || key == null || position == null) {
      _clearIfNeeded();
      return;
    }
    if (!validMapCoordinate(position.latitude, position.longitude)) {
      return;
    }
    final origin = DeliveryRoutePoint(position.latitude, position.longitude);
    if (key != _lastKey) {
      _lastKey = key;
      _lastRequestAt = null;
      _lastRequestOrigin = null;
      _offRouteSamples = 0;
      _generation++;
      _inFlight = false;
      state = DeliveryRouteState(activeKey: key);
      force = true;
    }
    final now = DateTime.now();
    final route = state.activeKey == key ? state.route : null;
    final offRoute =
        route != null &&
        _policy.isOffRoute(
          route: route,
          rider: origin,
          accuracyMeters: position.accuracy,
        );
    _offRouteSamples = offRoute ? _offRouteSamples + 1 : 0;
    final shouldRefresh =
        force ||
        route == null ||
        _policy.isStale(route, now) ||
        _policy.movedEnough(_lastRequestOrigin, origin) ||
        _offRouteSamples >= 2;
    if (!shouldRefresh ||
        _inFlight ||
        !_policy.canRefresh(now, _lastRequestAt)) {
      return;
    }
    await _requestRoute(order, origin, key, now);
  }

  Future<void> _requestRoute(
    ActiveDeliveryOrderModel order,
    DeliveryRoutePoint origin,
    String key,
    DateTime requestedAt,
  ) async {
    _inFlight = true;
    _lastRequestAt = requestedAt;
    _lastRequestOrigin = origin;
    final generation = ++_generation;
    state = state.copyWith(
      status: state.route == null
          ? DeliveryRouteStatus.loading
          : DeliveryRouteStatus.ready,
      activeKey: key,
      clearError: true,
    );
    try {
      final envelope = await ref
          .read(riderDeliveryApiServiceProvider)
          .getDeliveryRoute(
            order: order,
            latitude: origin.latitude,
            longitude: origin.longitude,
          );
      if (generation != _generation || key != _lastKey) return;
      _offRouteSamples = 0;
      state = DeliveryRouteState(
        status: DeliveryRouteStatus.ready,
        route: envelope.data,
        activeKey: key,
      );
    } on ApiException catch (error) {
      if (generation != _generation || key != _lastKey) return;
      state = state.copyWith(
        status: state.route == null
            ? DeliveryRouteStatus.unavailable
            : DeliveryRouteStatus.ready,
        activeKey: key,
        errorCode: error.errorCode ?? error.message,
      );
    } catch (_) {
      if (generation != _generation || key != _lastKey) return;
      state = state.copyWith(
        status: state.route == null
            ? DeliveryRouteStatus.unavailable
            : DeliveryRouteStatus.ready,
        activeKey: key,
        errorCode: 'ROUTE_UNAVAILABLE',
      );
    } finally {
      if (generation == _generation) {
        _inFlight = false;
      }
    }
  }

  void _clearIfNeeded() {
    if (state.status == DeliveryRouteStatus.idle &&
        state.route == null &&
        state.activeKey == null) {
      return;
    }
    _lastKey = null;
    _lastRequestAt = null;
    _lastRequestOrigin = null;
    _offRouteSamples = 0;
    _generation++;
    _inFlight = false;
    state = const DeliveryRouteState();
  }
}
