import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/features/delivery/services/incoming_alert_policy.dart';

/// Both transports deliver at least once, so these rules are what stop a rider
/// being alerted repeatedly for one order.
void main() {
  final expiry = DateTime.utc(2026, 9, 11, 6, 10, 30);
  String offer(int id, [DateTime? at]) =>
      requestOfferKey(requestId: id, expiresAt: at ?? expiry);

  group('requestOfferKey', () {
    // The socket and the pending-requests endpoint format the same instant,
    // possibly in different zones and with or without fractions.
    test('is the same for one instant however it is expressed', () {
      final local = DateTime.parse('2026-09-11T11:40:30+05:30');
      final withMillis = DateTime.utc(2026, 9, 11, 6, 10, 30, 450);

      expect(offer(42, local), offer(42));
      expect(offer(42, withMillis), offer(42));
    });

    test('differs when the request is offered again with a new expiry', () {
      final reOffered = expiry.add(const Duration(minutes: 2));
      expect(offer(42, reOffered), isNot(offer(42)));
    });

    test('differs between requests', () {
      expect(offer(42), isNot(offer(43)));
    });
  });

  group('shouldAlertForRequest', () {
    test('alerts for an offer the rider has not seen', () {
      expect(
        shouldAlertForRequest(offerKey: offer(42), seenOfferKeys: const {}),
        isTrue,
      );
    });

    // The reconnect case: the socket replays pending requests, and the rider
    // must not be alerted a second time for one already on screen.
    test('stays silent for an offer replayed after a reconnect', () {
      expect(
        shouldAlertForRequest(offerKey: offer(42), seenOfferKeys: {offer(42)}),
        isFalse,
      );
    });

    // The same offer can arrive over the socket and from polling.
    test('stays silent for the same offer arriving on a second transport', () {
      final seen = <String>{};
      final firstFromSocket = shouldAlertForRequest(
        offerKey: offer(7),
        seenOfferKeys: seen,
      );
      seen.add(offer(7));
      final thenFromPoll = shouldAlertForRequest(
        offerKey: offer(7),
        seenOfferKeys: seen,
      );

      expect(firstFromSocket, isTrue);
      expect(thenFromPoll, isFalse, reason: 'one offer must ring once');
    });

    // seenOfferKeys keeps handled offers, so an order the rider already
    // declined or accepted cannot ring again if the server re-sends it.
    test('stays silent for an offer the rider already handled', () {
      final handled = {offer(11), offer(12), offer(13)};
      for (final key in handled) {
        expect(
          shouldAlertForRequest(offerKey: key, seenOfferKeys: handled),
          isFalse,
          reason: 'offer $key was already handled',
        );
      }
      expect(
        shouldAlertForRequest(offerKey: offer(14), seenOfferKeys: handled),
        isTrue,
      );
    });

    // Order 13286: an offer that lapsed unanswered is offered again later
    // under the same request id. That is a new offer and must ring.
    test('alerts again when a lapsed request is offered again', () {
      final seen = {offer(42)};
      final reOffer = offer(42, expiry.add(const Duration(seconds: 90)));

      expect(
        shouldAlertForRequest(offerKey: reOffer, seenOfferKeys: seen),
        isTrue,
      );
    });
  });

  group('shouldAlertForSnapshot', () {
    test('rings when polling finds an offer the rider has not seen', () {
      expect(
        shouldAlertForSnapshot(
          offerKeys: [offer(1), offer(2)],
          seenOfferKeys: {offer(1)},
        ),
        isTrue,
      );
    });

    test('stays silent when every polled offer was already seen', () {
      expect(
        shouldAlertForSnapshot(
          offerKeys: [offer(1), offer(2)],
          seenOfferKeys: {offer(1), offer(2)},
        ),
        isFalse,
      );
    });

    test('stays silent for an empty poll', () {
      expect(
        shouldAlertForSnapshot(offerKeys: const [], seenOfferKeys: const {}),
        isFalse,
      );
    });
  });

  group('shouldAlertForAssignment', () {
    test('alerts when a restaurant assigns a new order', () {
      expect(
        shouldAlertForAssignment(orderId: 1195, activeOrderId: null),
        isTrue,
      );
      expect(
        shouldAlertForAssignment(orderId: 1195, activeOrderId: 1100),
        isTrue,
      );
    });

    // Assignment events are at-least-once; a repeat of the order the rider
    // already holds is a replay, not a new job.
    test('stays silent when the order is already the active one', () {
      expect(
        shouldAlertForAssignment(orderId: 1195, activeOrderId: 1195),
        isFalse,
      );
    });

    test('never alerts for an invalid order id', () {
      expect(
        shouldAlertForAssignment(orderId: 0, activeOrderId: null),
        isFalse,
      );
      expect(
        shouldAlertForAssignment(orderId: -1, activeOrderId: null),
        isFalse,
      );
    });
  });
}
