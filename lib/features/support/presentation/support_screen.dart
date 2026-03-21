import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supportAsync = ref.watch(supportControllerProvider);
    final faqs = supportAsync.valueOrNull ?? const [];

    return PremiumScaffold(
      title: 'Help center',
      subtitle: 'FAQ, support contact, and rider issue escalation.',
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
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Emergency call',
                        icon: Icons.call_rounded,
                        expanded: true,
                        onPressed: () => showLuxurySnackBar(
                          context,
                          'Emergency calling can be wired to your device dialer next.',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Report issue',
                        icon: Icons.report_problem_outlined,
                        onPressed: () => _showSupportTicketSheet(
                          context: context,
                          ref: ref,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                _SupportAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Live chat',
                  description:
                      'Ticket creation is live; chat and threaded replies can be connected next.',
                  onTap: () => showLuxurySnackBar(
                    context,
                    'Create a ticket below while live chat is being wired in.',
                  ),
                ),
                _SupportAction(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email operations',
                  description:
                      'Escalate payout or dispatch issues with attachments.',
                  onTap: () => showLuxurySnackBar(
                    context,
                    'Support ticket creation is available from Report issue.',
                  ),
                ),
              ],
            ),
          ),
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
      ),
    );
  }

  Future<void> _showSupportTicketSheet({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final subjectController = TextEditingController();
    final orderIdController = TextEditingController();
    final descriptionController = TextEditingController();
    var submitting = false;

    await showPremiumBottomSheet(
      context: context,
      title: 'Report issue',
      subtitle:
          'Create a rider support ticket for delivery, payout, or account issues.',
      child: StatefulBuilder(
        builder: (sheetContext, setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumTextField(
                label: 'Subject',
                hint: 'Customer not reachable',
                controller: subjectController,
                prefixIcon: Icons.subject_rounded,
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumTextField(
                label: 'Order ID (optional)',
                hint: 'ord_001',
                controller: orderIdController,
                prefixIcon: Icons.receipt_long_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              PremiumTextField(
                label: 'Description',
                hint: 'Describe what happened and what help you need.',
                controller: descriptionController,
                prefixIcon: Icons.notes_rounded,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: submitting ? 'Creating ticket...' : 'Create ticket',
                icon: Icons.support_agent_rounded,
                expanded: true,
                onPressed: submitting
                    ? null
                    : () async {
                        if (subjectController.text.trim().isEmpty ||
                            descriptionController.text.trim().isEmpty) {
                          showLuxurySnackBar(
                            context,
                            'Add both a subject and description first.',
                          );
                          return;
                        }
                        setModalState(() => submitting = true);
                        try {
                          await ref.read(supportControllerProvider.notifier).createTicket(
                            subject: subjectController.text.trim(),
                            description: descriptionController.text.trim(),
                            orderId: orderIdController.text.trim().isNotEmpty
                                ? orderIdController.text.trim()
                                : null,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                          showLuxurySnackBar(
                            context,
                            'Support ticket created successfully.',
                          );
                        } on ApiException catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          showLuxurySnackBar(context, error.message);
                        } finally {
                          if (sheetContext.mounted) {
                            setModalState(() => submitting = false);
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );

    subjectController.dispose();
    orderIdController.dispose();
    descriptionController.dispose();
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
    return ListTile(
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
    );
  }
}
