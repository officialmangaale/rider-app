import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rydex_rider/core/network/api_client.dart';
import 'package:rydex_rider/core/network/api_exception.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_controller.dart';
import 'package:rydex_rider/features/delivery/background/background_mode_store.dart';
import 'package:rydex_rider/features/delivery/background/incoming_ringer.dart';
import 'package:rydex_rider/features/delivery/models/delivery_models.dart';
import 'package:rydex_rider/features/delivery/providers/rider_delivery_provider.dart';
import 'package:rydex_rider/features/delivery/services/rider_delivery_api_service.dart';

import 'background_mode_test_fakes.dart';

ApiEnvelope<T> envelope<T>(T data) =>
    ApiEnvelope(success: true, message: 'ok', data: data, statusCode: 200);

class ControlledApi implements RiderDeliveryApiService {
  List<RiderOrderRequestModel> pending = [];
  int reads = 0;
  int accepts = 0;
  int declines = 0;
  int? acceptedRequest;
  Completer<ApiEnvelope<List<RiderOrderRequestModel>>>? firstRead;
  Completer<void>? acceptGate;
  bool lostAcceptResponse = false;
  bool missingEndpoint = false;
  int? assignedOrder;

  @override
  Future<ApiEnvelope<List<RiderOrderRequestModel>>>
  getPendingOrderRequests() async {
    reads++;
    if (missingEndpoint) {
      throw const ApiException(message: 'Not found', statusCode: 404);
    }
    if (reads == 1 && firstRead != null) return firstRead!.future;
    return envelope(pending);
  }

  @override
  Future<ApiEnvelope<Map<String, dynamic>>> acceptOrderRequest(int id) async {
    accepts++;
    acceptedRequest = id;
    await acceptGate?.future;
    assignedOrder = pending.firstWhere((r) => r.requestId == id).orderId;
    if (lostAcceptResponse) throw const ApiException(message: 'Timed out');
    return envelope({'order_id': assignedOrder});
  }

  @override
  Future<ApiEnvelope<Map<String, dynamic>>> rejectOrderRequest(int id) async {
    declines++;
    pending = pending.where((r) => r.requestId != id).toList();
    return envelope({});
  }

  @override
  Future<ApiEnvelope<ActiveDeliveryOrderModel>> getActiveDeliveryOrder(
    int orderId,
  ) async {
    if (assignedOrder == null) {
      throw const ApiException(message: 'No assignment', statusCode: 404);
    }
    return envelope(
      ActiveDeliveryOrderModel.fromJson({
        'order_id': assignedOrder,
        'delivery_status': 'rider_assigned',
        'restaurant_name': 'Kitchen',
        'pickup_address': 'Pickup',
        'drop_address': 'Private drop',
      }),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Only skips session/GPS startup; refresh, accept, decline and recovery are
/// the real production controller methods, backed by controlled API responses.
class ControllerWithoutSessionStartup extends RiderDeliveryController {
  @override
  RiderDeliveryState build() => const RiderDeliveryState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ControlledApi api;
  late ProviderContainer container;
  late RiderDeliveryController controller;

  RiderOrderRequestModel offer(int id) => RiderOrderRequestModel.fromJson({
    'request_id': id,
    'order_id': id + 100,
    'restaurant_id': 27,
    'expires_at': DateTime.now()
        .add(const Duration(seconds: 30))
        .toUtc()
        .toIso8601String(),
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final background = BackgroundModeController(
      store: BackgroundModeStore(await SharedPreferences.getInstance()),
      service: FakeServiceGateway(),
      platform: FakeRiderPlatform(),
      notifier: FakeNotifier(),
      supported: true,
    );
    api = ControlledApi();
    final ringer = IncomingRinger(FakeRingtoneOutput());
    container = ProviderContainer(
      overrides: [
        riderDeliveryControllerProvider.overrideWith(
          ControllerWithoutSessionStartup.new,
        ),
        riderDeliveryApiServiceProvider.overrideWithValue(api),
        backgroundModeControllerProvider.overrideWithValue(background),
        incomingRingerProvider.overrideWithValue(ringer),
      ],
    );
    controller = container.read(riderDeliveryControllerProvider.notifier);
    addTearDown(() async {
      // Let the controller's existing asynchronous sound notification finish.
      await Future<void>.delayed(Duration.zero);
      await ringer.stop();
      container.dispose();
    });
  });

  test(
    'live event arriving during REST refresh is reconciled, not dropped',
    () async {
      api.firstRead = Completer();
      api.pending = [offer(7)];
      final poll = controller.refreshPendingRequests();
      final liveEvent = controller.refreshPendingRequests();
      final push = controller.refreshPendingRequests();
      api.firstRead!.complete(envelope([]));
      await Future.wait([poll, liveEvent, push]);
      expect(api.reads, 2);
      expect(
        container
            .read(riderDeliveryControllerProvider)
            .pendingRequests
            .single
            .requestId,
        7,
      );
    },
  );

  test(
    'double acceptance shares one API operation; concurrent decline is refused',
    () async {
      api.pending = [offer(7)];
      await controller.refreshPendingRequests();
      api.acceptGate = Completer();
      final first = controller.acceptRequest(7);
      final duplicate = controller.acceptRequest(7);
      await expectLater(
        controller.rejectRequest(7),
        throwsA(isA<ApiException>()),
      );
      expect(api.accepts, 1);
      expect(api.declines, 0);
      api.acceptGate!.complete();
      await Future.wait([first, duplicate]);
      final state = container.read(riderDeliveryControllerProvider);
      expect(state.activeOrderId, 107);
      expect(state.pendingRequests, isEmpty);
    },
  );

  test(
    'lost accept response recovers assigned order instead of retrying acceptance',
    () async {
      api.pending = [offer(7)];
      api.lostAcceptResponse = true;
      await controller.refreshPendingRequests();
      await controller.acceptRequest(7);
      expect(api.accepts, 1);
      expect(
        container.read(riderDeliveryControllerProvider).activeOrderId,
        107,
      );
    },
  );

  test('decline sends offer ID and reconciles remaining offers', () async {
    api.pending = [offer(7), offer(8)];
    await controller.refreshPendingRequests();
    await controller.rejectRequest(7);
    expect(api.declines, 1);
    expect(api.assignedOrder, isNull);
    expect(
      container
          .read(riderDeliveryControllerProvider)
          .pendingRequests
          .single
          .requestId,
      8,
    );
  });

  test(
    'missing pending endpoint is a contract error, not an empty rider list',
    () async {
      api.missingEndpoint = true;
      await controller.refreshPendingRequests();
      expect(
        container.read(riderDeliveryControllerProvider).requestErrorMessage,
        contains('API is unavailable'),
      );
    },
  );

  test(
    'order status payload without a request ID or server expiry is not an offer',
    () async {
      api.pending = [
        RiderOrderRequestModel.fromJson({'order_id': 100}),
        RiderOrderRequestModel.fromJson({'request_id': 7, 'order_id': 100}),
      ];
      await controller.refreshPendingRequests();
      expect(
        container.read(riderDeliveryControllerProvider).pendingRequests,
        isEmpty,
      );
    },
  );
}
