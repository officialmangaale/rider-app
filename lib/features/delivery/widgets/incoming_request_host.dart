import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/delivery_models.dart';
import '../models/delivery_request_intent.dart';
import '../providers/request_notification_provider.dart';
import '../providers/rider_delivery_provider.dart';
import 'incoming_order_request_sheet.dart';

/// Lives above every rider tab. Sheets use the root navigator, never an
/// offstage Dashboard branch. Push, sockets and polling share this presenter.
class IncomingRequestHost extends ConsumerStatefulWidget {
  const IncomingRequestHost({
    super.key,
    required this.navigatorKey,
    required this.enabled,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final bool enabled;
  final Widget child;

  @override
  ConsumerState<IncomingRequestHost> createState() =>
      _IncomingRequestHostState();
}

class _IncomingRequestHostState extends ConsumerState<IncomingRequestHost>
    with WidgetsBindingObserver {
  final Set<String> _presented = {};
  bool _scheduled = false;
  bool _presenting = false;
  bool _handlingIntent = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(IncomingRequestHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _presented.clear();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      // A sheet dismissed before backgrounding must not hide a still-live offer.
      if (!_presenting) _presented.clear();
      _schedule();
    }
  }

  void _schedule() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_presentNext());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  String _key(RiderOrderRequestModel request) =>
      '${request.requestId}:${request.expiresAt.toUtc().toIso8601String()}';

  Future<void> _presentNext() async {
    if (!widget.enabled || !_foreground || _presenting || _handlingIntent) {
      return;
    }
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null || navigator.overlay == null) return;

    final intent = ref.read(deliveryRequestIntentProvider);
    RiderOrderRequestModel? selected;
    if (intent != null) {
      _handlingIntent = true;
      var consumed = false;
      try {
        final controller = ref.read(riderDeliveryControllerProvider.notifier);
        await controller.refreshPendingRequests();
        if (!mounted || !widget.enabled || !_foreground) return;
        // A newer notification tap takes priority over an older refresh.
        if (!identical(ref.read(deliveryRequestIntentProvider), intent)) {
          _schedule();
          return;
        }
        consumed = true;
        final state = ref.read(riderDeliveryControllerProvider);
        if (state.requestErrorMessage != null) {
          _message('Could not check this request. Retry from Requests.');
          return;
        }
        for (final request in state.pendingRequests) {
          if (intent.matches(request) &&
              request.expiresAt.isAfter(DateTime.now())) {
            selected = request;
            break;
          }
        }
        if (selected == null) {
          _message(
            'This request has expired, was cancelled, or is already assigned.',
          );
          return;
        }
      } finally {
        _handlingIntent = false;
        if (consumed &&
            mounted &&
            identical(ref.read(deliveryRequestIntentProvider), intent)) {
          ref.read(deliveryRequestIntentProvider.notifier).state = null;
        }
      }
    } else {
      final state = ref.read(riderDeliveryControllerProvider);
      if (state.hasActiveDelivery) return;
      final now = DateTime.now();
      for (final request in state.pendingRequests) {
        if (request.requestId > 0 &&
            request.orderId > 0 &&
            request.expiresAt.isAfter(now) &&
            !_presented.contains(_key(request))) {
          selected = request;
          break;
        }
      }
    }
    if (selected == null || !mounted || !_foreground || !widget.enabled) return;
    _presented.add(_key(selected));
    if (_presented.length > 200) _presented.remove(_presented.first);
    _presenting = true;
    try {
      await IncomingOrderRequestSheet.show(
        navigator.overlay!.context,
        selected,
        initialAction: intent?.action ?? DeliveryRequestAction.open,
      );
    } finally {
      _presenting = false;
      _schedule();
    }
  }

  void _message(String text) {
    final context = widget.navigatorKey.currentState?.overlay?.context;
    if (context != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      riderDeliveryControllerProvider.select((s) => s.pendingRequests),
      (_, _) => _schedule(),
    );
    ref.listen(deliveryRequestIntentProvider, (_, _) => _schedule());
    return widget.child;
  }
}
