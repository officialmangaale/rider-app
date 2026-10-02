import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_models.dart';
import 'app_providers.dart' show riderBackendApiProvider;

// ---------------------------------------------------------------------------
// Support provider.
//  * FAQs: the backend has no FAQ endpoint, so this list is intentionally empty.
//  * Tickets: created against POST /api/v1/support/tickets. A ticket only counts
//    as created once the server has accepted it; failures are thrown so the
//    screen can say so, never swallowed.
//  * Contact details: whatever operations has configured on the server.
// ---------------------------------------------------------------------------

final supportControllerProvider =
    AsyncNotifierProvider<SupportController, List<SupportFaq>>(
  SupportController.new,
);

class SupportController extends AsyncNotifier<List<SupportFaq>> {
  @override
  Future<List<SupportFaq>> build() async => const [];

  /// Files a ticket and returns its id. Throws (ApiException) if the server did
  /// not accept it.
  Future<int> createTicket({
    required String subject,
    required String description,
    String category = 'other',
    int? orderId,
  }) async {
    final api = ref.read(riderBackendApiProvider);
    final response = await api.support.createTicket(
      subject: subject,
      description: description,
      category: category,
      orderId: orderId,
    );
    ref.invalidate(myTicketsProvider);
    final id = response.data['id'];
    return id is num ? id.toInt() : 0;
  }

  Future<void> refresh() async {
    ref.invalidate(myTicketsProvider);
    ref.invalidate(supportContactProvider);
  }
}

/// A rider's own support ticket, as returned by the server.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    this.adminNote = '',
  });

  final int id;
  final String subject;
  final String category;
  final String status;
  final String adminNote;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: (json['id'] as num?)?.toInt() ?? 0,
        subject: (json['subject'] ?? '').toString(),
        category: (json['category'] ?? 'other').toString(),
        status: (json['status'] ?? 'open').toString(),
        adminNote: (json['admin_note'] ?? '').toString(),
      );
}

final myTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicket>>((ref) async {
  final response = await ref.watch(riderBackendApiProvider).support.myTickets();
  final list = response.data['tickets'];
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

/// Operations contact details. A field is an empty string when not configured.
class SupportContact {
  const SupportContact({this.phone = '', this.email = '', this.emergencyPhone = ''});

  final String phone;
  final String email;
  final String emergencyPhone;

  /// India's single national emergency number, used when operations has not
  /// configured its own emergency line, so the safety button always dials
  /// something real.
  static const String nationalEmergencyNumber = '112';

  String get emergencyNumberToDial =>
      emergencyPhone.isNotEmpty ? emergencyPhone : nationalEmergencyNumber;

  factory SupportContact.fromJson(Map<String, dynamic> json) => SupportContact(
        phone: (json['support_phone'] ?? '').toString().trim(),
        email: (json['support_email'] ?? '').toString().trim(),
        emergencyPhone: (json['emergency_phone'] ?? '').toString().trim(),
      );
}

final supportContactProvider =
    FutureProvider.autoDispose<SupportContact>((ref) async {
  try {
    final response =
        await ref.watch(riderBackendApiProvider).support.contact();
    return SupportContact.fromJson(response.data);
  } catch (_) {
    // Offline or an older backend: fall back to the national emergency number
    // only; no other contact is invented.
    return const SupportContact();
  }
});
