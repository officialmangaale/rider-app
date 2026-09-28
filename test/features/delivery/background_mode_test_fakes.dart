import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_controller.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_policy.dart';
import 'package:rydex_rider/features/delivery/background/incoming_ringer.dart';
import 'package:rydex_rider/features/delivery/background/request_alert_notifier.dart';
import 'package:rydex_rider/features/delivery/background/rider_platform.dart';

class FakeServiceGateway implements OnlineServiceGateway {
  bool running = false;
  int starts = 0;
  final List<String> sent = [];

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> start() async {
    starts++;
    running = true;
  }

  @override
  void send(String command) => sent.add(command);
}

class FakeRiderPlatform implements RiderPlatform {
  bool overlayGranted = false;
  bool bubbleVisible = false;
  int overlaySettingsOpened = 0;

  @override
  Future<bool> canDrawOverlays() async => overlayGranted;

  @override
  Future<void> openOverlaySettings() async => overlaySettingsOpened++;

  @override
  Future<void> showBubble() async => bubbleVisible = true;

  @override
  Future<void> hideBubble() async => bubbleVisible = false;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;

  @override
  Future<void> openBatteryOptimizationSettings() async {}
}

/// Records what would have been shown instead of calling the plugin.
class FakeNotifier implements RequestAlertNotifier {
  final Map<int, PolledOffer> showing = {};
  int posts = 0;
  bool permission = true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<bool> areEnabled() async => permission;

  @override
  Future<void> showRequest(PolledOffer offer, {DateTime? now}) async {
    posts++;
    showing[offer.requestId] = offer;
  }

  /// Quiet outcome notifications ("accepted", "already taken"...), in the order
  /// they were posted; the last one for a request is what the rider sees.
  final List<FakeOutcome> outcomes = [];

  @override
  Future<void> showOutcome({
    required int requestId,
    required String title,
    required String body,
    String? payload,
    Duration visibleFor = const Duration(seconds: 20),
    bool inProgress = false,
  }) async {
    outcomes.add(
      FakeOutcome(requestId, title, body, payload, visibleFor, inProgress),
    );
    // An outcome replaces the offer under the same notification id.
    showing.remove(requestId);
  }

  FakeOutcome? lastOutcomeFor(int requestId) {
    for (final outcome in outcomes.reversed) {
      if (outcome.requestId == requestId) return outcome;
    }
    return null;
  }

  final Map<int, int> orderByRequest = {};

  @override
  Future<void> cancelOffersForOrder(int orderId) async {
    for (final entry in orderByRequest.entries.toList()) {
      if (entry.value == orderId) showing.remove(entry.key);
    }
  }

  @override
  Future<DeliveryAlertHealth> health() async => DeliveryAlertHealth(
    notificationsEnabled: permission,
    channelImportance: null,
  );

  @override
  Future<void> cancelRequest(int requestId) async {
    showing.remove(requestId);
    // Cancelling removes whatever is shown under the id, progress included.
    outcomes.removeWhere((o) => o.requestId == requestId);
  }

  @override
  Future<void> cancelAllRequests() async => showing.clear();
}

class FakeOutcome {
  const FakeOutcome(
    this.requestId,
    this.title,
    this.body,
    this.payload,
    this.visibleFor,
    this.inProgress,
  );

  final int requestId;
  final String title;
  final String body;
  final String? payload;
  final Duration visibleFor;
  final bool inProgress;
}

class FakeRingtoneOutput implements RingtoneOutput {
  int starts = 0;
  int stops = 0;
  bool playing = false;

  @override
  Future<void> start() async {
    starts++;
    playing = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    playing = false;
  }
}

class FakeServiceInstance implements ServiceInstance {
  final Map<String, StreamController<Map<String, dynamic>?>> _controllers = {};
  int stopSelfCalls = 0;

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {}

  @override
  Stream<Map<String, dynamic>?> on(String method) =>
      _controllers.putIfAbsent(method, StreamController.broadcast).stream;

  void emit(String method) => _controllers[method]?.add(null);

  @override
  Future<void> stopSelf() async => stopSelfCalls++;
}
