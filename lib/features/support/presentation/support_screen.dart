import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

const _ticketCategories = <String, String>{
  'delivery': 'Delivery / order problem',
  'payout': 'Payout / wallet',
  'account': 'Account',
  'safety': 'Safety',
  'other': 'Something else',
};

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(supportControllerProvider).valueOrNull ?? const [];
    final contact =
        ref.watch(supportContactProvider).valueOrNull ?? const SupportContact();
    final tickets =
        ref.watch(myTicketsProvider).valueOrNull ?? const <SupportTicket>[];

    return PremiumScaffold(
      title: 'Help center',
      subtitle: 'Report a problem or reach rider operations.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        children: [
          GlassCard(
            accent: AppColors.ember,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Emergency support',
                  subtitle:
                      'Use only during rider safety incidents or urgent order issues.',
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Call ${contact.emergencyNumberToDial}',
                  icon: Icons.call_rounded,
                  expanded: true,
                  onPressed: () =>
                      _dial(context, contact.emergencyNumberToDial),
                ),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: 'Report issue',
                  icon: Icons.report_problem_outlined,
                  expanded: true,
                  onPressed: () =>
                      _showSupportTicketSheet(context: context, ref: ref),
                ),
              ],
            ),
          ),
          if (contact.phone.isNotEmpty || contact.email.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Contact support',
                    subtitle: 'Reach rider operations across your shift.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (contact.phone.isNotEmpty)
                    _SupportAction(
                      icon: Icons.call_outlined,
                      label: 'Call operations',
                      description: contact.phone,
                      onTap: () => _dial(context, contact.phone),
                    ),
                  if (contact.email.isNotEmpty)
                    _SupportAction(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email operations',
                      description: contact.email,
                      onTap: () => _launch(
                        context,
                        Uri(scheme: 'mailto', path: contact.email),
                        'Could not open your email app.',
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (tickets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Your tickets',
                    subtitle: 'What you have reported and where it stands.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final ticket in tickets.take(10))
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('#${ticket.id} · ${ticket.subject}'),
                        subtitle: Text(
                          ticket.adminNote.isNotEmpty
                              ? '${_statusLabel(ticket.status)} — ${ticket.adminNote}'
                              : _statusLabel(ticket.status),
                        ),
                        trailing: Icon(
                          ticket.status == 'resolved' ||
                                  ticket.status == 'closed'
                              ? Icons.check_circle_outline_rounded
                              : Icons.schedule_rounded,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (faqs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Frequently asked questions',
                    subtitle:
                        'Answers for daily rider operations and account issues.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final faq in faqs)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      collapsedIconColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                      iconColor: AppColors.gold,
                      title: Text(faq.question),
                      subtitle: Text(faq.category),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.xs,
                            right: AppSpacing.xs,
                            bottom: AppSpacing.md,
                          ),
                          child: Text(
                            faq.answer,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'open' => 'Received',
    'in_progress' => 'Being looked at',
    'resolved' => 'Resolved',
    'closed' => 'Closed',
    _ => status,
  };

  static Future<void> _dial(BuildContext context, String number) => _launch(
    context,
    Uri(scheme: 'tel', path: number),
    'Could not open the phone dialer. Please dial $number yourself.',
  );

  static Future<void> _launch(
    BuildContext context,
    Uri uri,
    String failureMessage,
  ) async {
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      showLuxurySnackBar(context, failureMessage);
    }
  }

  Future<void> _showSupportTicketSheet({
    required BuildContext context,
    required WidgetRef ref,
  }) {
    return showPremiumBottomSheet(
      context: context,
      title: 'Report issue',
      subtitle:
          'Tell operations what happened. They will review it and update the status here.',
      child: _TicketSheet(
        // The sheet closes itself once the server accepts the ticket; the
        // confirmation is shown on the screen underneath.
        onSent: (message) {
          if (context.mounted) showLuxurySnackBar(context, message);
        },
      ),
    );
  }
}

/// The report-issue form. It owns its text controllers so they are disposed
/// only when the sheet is really gone; disposing them right after the sheet
/// route is popped (while it is still animating out) throws "used after being
/// disposed".
class _TicketSheet extends ConsumerStatefulWidget {
  const _TicketSheet({required this.onSent});

  final void Function(String message) onSent;

  @override
  ConsumerState<_TicketSheet> createState() => _TicketSheetState();
}

class _TicketSheetState extends ConsumerState<_TicketSheet> {
  final _subject = TextEditingController();
  final _orderId = TextEditingController();
  final _description = TextEditingController();
  var _category = 'delivery';
  var _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _orderId.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final description = _description.text.trim();
    final orderText = _orderId.text.trim();
    final orderId = orderText.isEmpty ? null : int.tryParse(orderText);
    if (subject.isEmpty || description.isEmpty) {
      showLuxurySnackBar(context, 'Add both a subject and description first.');
      return;
    }
    if (orderText.isNotEmpty && orderId == null) {
      showLuxurySnackBar(
        context,
        'The order number should be digits only, or leave it empty.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final id = await ref
          .read(supportControllerProvider.notifier)
          .createTicket(
            subject: subject,
            description: description,
            category: _category,
            orderId: orderId,
          );
      if (!mounted) return;
      final message = id > 0
          ? 'Ticket #$id sent. Operations will review it.'
          : 'Ticket sent. Operations will review it.';
      Navigator.of(context).pop();
      widget.onSent(message);
    } on ApiException catch (error) {
      if (mounted) showLuxurySnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showLuxurySnackBar(
          context,
          'Could not send your ticket. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'What is it about?'),
            items: [
              for (final entry in _ticketCategories.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _submitting
                ? null
                : (value) => setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: AppSpacing.lg),
          PremiumTextField(
            label: 'Subject',
            hint: 'Customer not reachable',
            controller: _subject,
            prefixIcon: Icons.subject_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          PremiumTextField(
            label: 'Order number (optional)',
            hint: 'e.g. 13294',
            controller: _orderId,
            prefixIcon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          PremiumTextField(
            label: 'Description',
            hint: 'Describe what happened and what help you need.',
            controller: _description,
            prefixIcon: Icons.notes_rounded,
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _submitting ? 'Sending...' : 'Send to operations',
            icon: Icons.support_agent_rounded,
            expanded: true,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _SupportAction extends StatelessWidget {
  const _SupportAction({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppColors.gold.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: AppColors.gold),
        ),
        title: Text(label),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
