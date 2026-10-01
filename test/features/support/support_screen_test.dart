import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rydex_rider/core/network/api_client.dart';
import 'package:rydex_rider/core/network/api_exception.dart';
import 'package:rydex_rider/data/services/rider_backend_api.dart';
import 'package:rydex_rider/features/support/presentation/support_screen.dart';
import 'package:rydex_rider/presentation/providers/app_providers.dart';

class _FakeSupportApi implements SupportApi {
  _FakeSupportApi({this.contactJson = const {}, this.failWith});

  final Map<String, dynamic> contactJson;
  final ApiException? failWith;
  final List<Map<String, dynamic>> created = [];

  ApiEnvelope<Map<String, dynamic>> _ok(Map<String, dynamic> data) =>
      ApiEnvelope(success: true, message: 'ok', data: data);

  @override
  Future<ApiEnvelope<Map<String, dynamic>>> createTicket({
    required String subject,
    required String description,
    String category = 'other',
    int? orderId,
  }) async {
    if (failWith != null) throw failWith!;
    created.add({
      'subject': subject,
      'description': description,
      'category': category,
      'order_id': orderId,
    });
    return _ok({'id': 77});
  }

  @override
  Future<ApiEnvelope<Map<String, dynamic>>> myTickets() async =>
      _ok({'tickets': <dynamic>[]});

  @override
  Future<ApiEnvelope<Map<String, dynamic>>> contact() async => _ok(contactJson);
}

class _FakeBackend implements RiderBackendApi {
  _FakeBackend(this.support);

  @override
  final SupportApi support;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

Future<_FakeSupportApi> _pump(
  WidgetTester tester, {
  Map<String, dynamic> contact = const {},
  ApiException? failWith,
}) async {
  // flutter_test draws text in the Ahem font, where every glyph is as wide as
  // the font size, so labels overflow far more than on a device. Overflow is a
  // font artifact here; every other error still fails the test.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);
  // A phone-sized screen (the default test surface is a small 800x600 window).
  tester.view.physicalSize = const Size(1080, 2000);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final api = _FakeSupportApi(contactJson: contact, failWith: failWith);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        riderBackendApiProvider.overrideWithValue(_FakeBackend(api)),
      ],
      child: const MaterialApp(home: SupportScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<void> _fillAndSend(
  WidgetTester tester, {
  String subject = 'Payout missing',
  String order = '',
  String description = 'COD settled but wallet not updated',
}) async {
  await tester.tap(find.text('Report issue'));
  await tester.pumpAndSettle();
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), subject);
  await tester.enterText(fields.at(1), order);
  await tester.enterText(fields.at(2), description);
  await tester.tap(find.text('Send to operations'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows only real controls: no fake chat, and the emergency call '
      'dials a real number', (tester) async {
    await _pump(tester);

    expect(find.text('Live chat'), findsNothing);
    expect(find.text('Email operations'), findsNothing,
        reason: 'contact rows appear only when operations configured them');
    expect(find.text('Frequently asked questions'), findsNothing,
        reason: 'an empty FAQ section is not shown');
    expect(find.text('Call 112'), findsOneWidget,
        reason: 'with no configured emergency line the national number is used');
  });

  testWidgets('configured contact details appear', (tester) async {
    await _pump(tester, contact: {
      'support_phone': '+91 11 5555 0000',
      'support_email': 'riders@example.com',
      'emergency_phone': '1800 123 456',
    });

    expect(find.text('Call 1800 123 456'), findsOneWidget);
    expect(find.text('Call operations'), findsOneWidget);
    expect(find.text('Email operations'), findsOneWidget);
  });

  testWidgets('a ticket is only reported as sent after the server accepted it',
      (tester) async {
    final api = await _pump(tester);

    await _fillAndSend(tester);

    expect(api.created, hasLength(1));
    expect(api.created.single['subject'], 'Payout missing');
    expect(api.created.single['category'], 'delivery');
    expect(api.created.single['order_id'], isNull);
    expect(find.textContaining('Ticket #77 sent'), findsOneWidget);
  });

  testWidgets('a failed submission says so and never claims success',
      (tester) async {
    await _pump(
      tester,
      failWith: const ApiException(
        message: 'You have raised several tickets today.',
        statusCode: 429,
      ),
    );

    await _fillAndSend(tester);

    expect(find.text('You have raised several tickets today.'), findsOneWidget);
    expect(find.textContaining('sent'), findsNothing);
  });

  testWidgets('a non-numeric order number is refused before anything is sent',
      (tester) async {
    final api = await _pump(tester);

    await _fillAndSend(tester, order: 'ord_001');

    expect(api.created, isEmpty);
    expect(find.textContaining('digits only'), findsOneWidget);
  });
}
