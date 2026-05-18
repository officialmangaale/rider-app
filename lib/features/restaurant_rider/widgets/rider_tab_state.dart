import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class RiderEmptyState extends StatelessWidget {
  const RiderEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent = AppColors.sky,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: EmptyStateCard(
          icon: icon,
          title: title,
          message: message,
          accent: accent,
        ),
      ),
    );
  }
}

class RiderErrorState extends StatelessWidget {
  const RiderErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Retry',
    this.icon = Icons.cloud_off_rounded,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: GlassCard(
          accent: AppColors.danger,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger.withValues(alpha: 0.10),
                ),
                child: Icon(icon, color: AppColors.danger, size: 30),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RiderInlineStateCard extends StatelessWidget {
  const RiderInlineStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent = AppColors.sky,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String riderErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.isUnauthorized) {
      return 'Your session has expired. Please sign in again.';
    }
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}

bool isUnauthorizedRiderError(Object error) {
  return error is ApiException && error.isUnauthorized;
}
