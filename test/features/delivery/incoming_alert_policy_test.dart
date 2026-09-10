import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/features/delivery/services/incoming_alert_policy.dart';

/// Both transports deliver at least once, so these rules are what stop a rider
/// being alerted repeatedly for one order.
void main() {
  group('shouldAlertForRequest', () {
    test('alerts for a request the rider has not seen', () {
      expect(
        shouldAlertForRequest(requestId: 42, seenRequestIds: const {}),
        isTrue,
      );
    });

    // The reconnect case: the socket replays pending requests, and the rider
    // must not be alerted a second time for one already on screen.
    test('stays silent for a request replayed after a reconnect', () {
      expect(
        shouldAlertForRequest(requestId: 42, seenRequestIds: const {42}),
        isFalse,
      );
    });

    // The same request can arrive over the socket and a push notification.
    test('stays silent for the same request arriving on a second transport', () {
      final seen = <int>{};
      final firstFromSocket = shouldAlertForRequest(requestId: 7, seenRequestIds: seen);
      seen.add(7);
      final thenFromPush = shouldAlertForRequest(requestId: 7, seenRequestIds: seen);

      expect(firstFromSocket, isTrue);
      expect(thenFromPush, isFalse, reason: 'one request must ring once');
    });

    // seenRequestIds keeps handled requests, so an order the rider already
    // declined or accepted cannot ring again if the server re-sends it.
    test('stays silent for a request the rider already handled', () {
      const handled = {11, 12, 13};
      for (final id in handled) {
        expect(shouldAlertForRequest(requestId: id, seenRequestIds: handled), isFalse,
            reason: 'request $id was already handled');
      }
      expect(shouldAlertForRequest(requestId: 14, seenRequestIds: handled), isTrue);
    });
  });

  group('shouldAlertForAssignment', () {
    test('alerts when a restaurant assigns a new order', () {
      expect(shouldAlertForAssignment(orderId: 1195, activeOrderId: null), isTrue);
      expect(shouldAlertForAssignment(orderId: 1195, activeOrderId: 1100), isTrue);
    });

    // Assignment events are at-least-once; a repeat of the order the rider
    // already holds is a replay, not a new job.
    test('stays silent when the order is already the active one', () {
      expect(shouldAlertForAssignment(orderId: 1195, activeOrderId: 1195), isFalse);
    });

    test('never alerts for an invalid order id', () {
      expect(shouldAlertForAssignment(orderId: 0, activeOrderId: null), isFalse);
      expect(shouldAlertForAssignment(orderId: -1, activeOrderId: null), isFalse);
    });
  });
}
