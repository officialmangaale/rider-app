import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../models/delivery_request_intent.dart';
import 'background_mode_store.dart';
import 'request_alert_notifier.dart';

/// What became of an Accept or Decline answered from a notification.
enum OfferActionOutcome {
  /// The backend confirmed the assignment.
  accepted,

  /// The backend recorded the decline (or it had already been recorded).
  declined,

  /// The offer ran out before the answer arrived.
  expired,

  /// Another rider accepted first.
  takenByOther,

  /// The backend refused for another reason (rider unavailable, order
  /// cancelled, offer withdrawn).
  unavailable,

  /// No session, or the access token is no longer valid.
  unauthorized,

  /// The request never got an answer and acceptance could not be confirmed
  /// either way.
  unconfirmed,

  /// Another tap for the same offer is already being handled.
  alreadyRunning,
}

/// The response of POST .../order-requests/:id/accept, reduced to what the
/// notification needs.
class AcceptResponse {
  const AcceptResponse(this.outcome, {this.orderId, this.message = ''});

  final OfferActionOutcome outcome;
  final int? orderId;

  /// The backend's own words, for [OfferActionOutcome.unavailable].
  final String message;
}

/// Maps the accept endpoint's HTTP response to an outcome. Pure, so the whole
/// table is tested without a network.
///
/// Success is only a 2xx: the notification says "assigned" only when the
/// backend has said so. See rider-service DeliveryHandler.AcceptRequest for the
/// codes (`ORDER_ALREADY_ASSIGNED`, `OFFER_EXPIRED`, ...).
AcceptResponse classifyAcceptResponse(int status, String body) {
  Map<String, dynamic> json = const {};
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) json = Map<String, dynamic>.from(decoded);
  } catch (_) {}

  if (status >= 200 && status < 300) {
    final data = json['data'];
    final orderId = data is Map ? _asInt(data['order_id']) : null;
    return AcceptResponse(OfferActionOutcome.accepted, orderId: orderId);
  }
  if (status == 401) {
    return const AcceptResponse(OfferActionOutcome.unauthorized);
  }
  final code = '${json['error_code'] ?? json['error'] ?? ''}'.toUpperCase();
  final message = '${json['message'] ?? ''}'.trim();
  if (status == 409 || status == 404 || status == 400) {
    if (code == 'ORDER_ALREADY_ASSIGNED') {
      return AcceptResponse(OfferActionOutcome.takenByOther, message: message);
    }
    if (code == 'OFFER_EXPIRED') {
      return AcceptResponse(OfferActionOutcome.expired, message: message);
    }
    return AcceptResponse(OfferActionOutcome.unavailable, message: message);
  }
  if (status == 403) {
    return AcceptResponse(OfferActionOutcome.unavailable, message: message);
  }
  // 5xx and anything unexpected: the answer is unknown, not a refusal.
  return const AcceptResponse(OfferActionOutcome.unconfirmed);
}

/// Carries out Accept and Decline for a delivery offer without any screen.
///
/// It runs in whichever isolate the notification action reaches: the
/// background isolate Android starts for the action (app closed or in the
/// background), or the app's own isolate. It talks to the backend directly and
/// reports the result by updating the offer's notification.
///
/// It never refreshes the access token (see rider_online_service.dart: two
/// isolates rotating a refresh token race, and the loser signs the rider out).
/// An expired session is reported as "open the app to sign in".
///
/// The notification is replaced by an in-progress message the moment an action
/// starts, which removes the Accept and Decline buttons, so a second tap cannot
/// send a second request. The backend is idempotent for the winning rider and
/// for a repeated decline in any case.
class OfferActionRunner {
  OfferActionRunner({
    required this.store,
    required this.notifier,
    required this.client,
    DateTime Function()? clock,
    this.baseUrl = AppConstants.apiBaseUrl,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _clock = clock ?? DateTime.now;

  final BackgroundModeStore store;
  final RequestAlertNotifier notifier;
  final http.Client client;
  final String baseUrl;
  final Duration requestTimeout;
  final DateTime Function() _clock;

  /// Offers being answered in this isolate.
  static final Set<int> _inFlight = <int>{};

  Future<OfferActionOutcome?> run(DeliveryRequestIntent intent) async {
    switch (intent.action) {
      case DeliveryRequestAction.accept:
        return _guarded(intent, _accept);
      case DeliveryRequestAction.decline:
        return _guarded(intent, _decline);
      case DeliveryRequestAction.open:
        return null;
    }
  }

  Future<OfferActionOutcome> _guarded(
    DeliveryRequestIntent intent,
    Future<OfferActionOutcome> Function(DeliveryRequestIntent) action,
  ) async {
    if (!_inFlight.add(intent.requestId)) {
      return OfferActionOutcome.alreadyRunning;
    }
    try {
      return await action(intent);
    } finally {
      _inFlight.remove(intent.requestId);
    }
  }

  Future<OfferActionOutcome> _accept(DeliveryRequestIntent intent) async {
    final requestId = intent.requestId;
    final token = await _token();
    if (token == null) return _signedOut(requestId, intent);
    if (_expired(intent)) return _expiredOutcome(requestId);

    await notifier.showOutcome(
      requestId: requestId,
      title: 'Accepting delivery${_ref(intent)}',
      body: 'Confirming with the server…',
      inProgress: true,
      visibleFor: const Duration(seconds: 30),
    );

    AcceptResponse result;
    try {
      final response = await client
          .post(_uri('/api/v1/riders/order-requests/$requestId/accept'), headers: _headers(token))
          .timeout(requestTimeout);
      result = classifyAcceptResponse(response.statusCode, response.body);
    } on TimeoutException {
      result = await _recoverAcceptance(intent, token);
    } on SocketException {
      result = await _recoverAcceptance(intent, token);
    } on http.ClientException {
      result = await _recoverAcceptance(intent, token);
    }

    switch (result.outcome) {
      case OfferActionOutcome.accepted:
        // Only now, with the backend's confirmation, is it assigned.
        await store.setActiveDelivery(true);
        await notifier.showOutcome(
          requestId: requestId,
          title: 'Delivery accepted${_ref(intent, orderId: result.orderId)}',
          body: 'This order is assigned to you. Tap to open pickup details.',
          payload: jsonEncode({
            'type': 'ACTIVE_DELIVERY',
            'order_id': result.orderId ?? intent.orderId,
          }),
          visibleFor: const Duration(minutes: 2),
        );
      case OfferActionOutcome.takenByOther:
        await notifier.showOutcome(
          requestId: requestId,
          title: 'Delivery already taken',
          body: 'Another rider accepted this request first.',
          visibleFor: const Duration(seconds: 15),
        );
      case OfferActionOutcome.expired:
        await _expiredOutcome(requestId);
      case OfferActionOutcome.unavailable:
        await notifier.showOutcome(
          requestId: requestId,
          title: 'Delivery no longer available',
          body: result.message.isEmpty
              ? 'This request can no longer be accepted.'
              : result.message,
          visibleFor: const Duration(seconds: 15),
        );
      case OfferActionOutcome.unauthorized:
        await _signedOut(requestId, intent);
      case OfferActionOutcome.unconfirmed:
        await notifier.showOutcome(
          requestId: requestId,
          title: 'Could not confirm${_ref(intent)}',
          body:
              'No connection. Tap to open the app and check before the request '
              'expires.',
          payload: _offerPayload(intent),
          visibleFor: _remaining(intent),
        );
      case OfferActionOutcome.declined:
      case OfferActionOutcome.alreadyRunning:
        break;
    }
    return result.outcome;
  }

  /// A lost response does not mean a lost acceptance: the backend may have
  /// committed it. The rider's active order says which it was.
  Future<AcceptResponse> _recoverAcceptance(
    DeliveryRequestIntent intent,
    String token,
  ) async {
    try {
      final response = await client
          .get(_uri('/api/v1/orders/active'), headers: _headers(token))
          .timeout(requestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map ? _activeOrder(decoded) : null;
        final orderId = data == null ? null : _asInt(data['order_id']);
        if (orderId != null && orderId == intent.orderId) {
          return AcceptResponse(OfferActionOutcome.accepted, orderId: orderId);
        }
      }
      if (response.statusCode == 404 || response.statusCode == 200) {
        // The backend answered and this order is not ours: not accepted, and
        // unknown whether it can still be. Let the rider check.
        return const AcceptResponse(OfferActionOutcome.unconfirmed);
      }
    } catch (_) {
      // Still unreachable.
    }
    return const AcceptResponse(OfferActionOutcome.unconfirmed);
  }

  Future<OfferActionOutcome> _decline(DeliveryRequestIntent intent) async {
    final requestId = intent.requestId;
    final token = await _token();
    if (token == null) return _signedOut(requestId, intent);
    if (_expired(intent)) return _expiredOutcome(requestId);

    await notifier.showOutcome(
      requestId: requestId,
      title: 'Declining${_ref(intent)}',
      body: 'Confirming with the server…',
      inProgress: true,
      visibleFor: const Duration(seconds: 30),
    );

    try {
      final response = await client
          .post(_uri('/api/v1/riders/order-requests/$requestId/reject'), headers: _headers(token))
          .timeout(requestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Declined: only this rider's offer. The customer's order is untouched
        // and the other riders' offers stand.
        await notifier.cancelRequest(requestId);
        return OfferActionOutcome.declined;
      }
      if (response.statusCode == 401) return _signedOut(requestId, intent);
      // 409: already expired, accepted or withdrawn. Nothing left to decline.
      await notifier.cancelRequest(requestId);
      return response.statusCode == 409
          ? OfferActionOutcome.expired
          : OfferActionOutcome.unavailable;
    } on TimeoutException {
      return _declineUnconfirmed(intent);
    } on SocketException {
      return _declineUnconfirmed(intent);
    } on http.ClientException {
      return _declineUnconfirmed(intent);
    }
  }

  Future<OfferActionOutcome> _declineUnconfirmed(
    DeliveryRequestIntent intent,
  ) async {
    await notifier.showOutcome(
      requestId: intent.requestId,
      title: 'Could not decline${_ref(intent)}',
      body: 'No connection. Tap to open the app; the request expires by itself.',
      payload: _offerPayload(intent),
      visibleFor: _remaining(intent),
    );
    return OfferActionOutcome.unconfirmed;
  }

  Future<OfferActionOutcome> _signedOut(
    int requestId,
    DeliveryRequestIntent intent,
  ) async {
    await notifier.showOutcome(
      requestId: requestId,
      title: 'Sign in to answer requests',
      body: 'Open Mangaale Rider to sign in again.',
      visibleFor: const Duration(minutes: 5),
    );
    return OfferActionOutcome.unauthorized;
  }

  Future<OfferActionOutcome> _expiredOutcome(int requestId) async {
    await notifier.showOutcome(
      requestId: requestId,
      title: 'Request expired',
      body: 'This delivery request ran out before it was answered.',
      visibleFor: const Duration(seconds: 10),
    );
    return OfferActionOutcome.expired;
  }

  bool _expired(DeliveryRequestIntent intent) {
    final expiresAt = intent.expiresAt;
    return expiresAt != null && !expiresAt.toUtc().isAfter(_clock().toUtc());
  }

  Duration _remaining(DeliveryRequestIntent intent) {
    final expiresAt = intent.expiresAt;
    if (expiresAt == null) return const Duration(minutes: 1);
    final left = expiresAt.toUtc().difference(_clock().toUtc());
    return left > const Duration(seconds: 5) ? left : const Duration(seconds: 5);
  }

  Future<String?> _token() async {
    await store.reload();
    final token = store.accessToken?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  String _ref(DeliveryRequestIntent intent, {int? orderId}) {
    final id = orderId ?? intent.orderId;
    return id == null || id <= 0 ? '' : ' #$id';
  }

  String _offerPayload(DeliveryRequestIntent intent) => jsonEncode({
    'type': 'DELIVERY_ORDER_REQUEST',
    'request_id': intent.requestId,
    'order_id': intent.orderId,
    'expires_at': intent.expiresAt?.toUtc().toIso8601String(),
  });

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  static Map<String, dynamic>? _activeOrder(Map<dynamic, dynamic> body) {
    for (final key in const ['data', 'order', 'delivery']) {
      final value = body[key];
      if (value is Map) {
        final nested = _activeOrder(value);
        return nested ?? Map<String, dynamic>.from(value);
      }
    }
    return body.containsKey('order_id') ? Map<String, dynamic>.from(body) : null;
  }

}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
