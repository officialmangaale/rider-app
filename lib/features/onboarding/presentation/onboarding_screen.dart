import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  final _pages = const [
    _OnboardingPageData(
      title: 'Own the premium dispatch lane.',
      subtitle:
          'Receive curated delivery requests with clear payout, timing, and route intelligence.',
      icon: Icons.bolt_rounded,
      accent: AppColors.gold,
    ),
    _OnboardingPageData(
      title: 'Navigate with polished rider flow.',
      subtitle:
          'Move from pickup to doorstep with rich route cards, call actions, and delivery checkpoints.',
      icon: Icons.route_rounded,
      accent: AppColors.ember,
    ),
    _OnboardingPageData(
      title: 'Track earnings beyond the rush.',
      subtitle:
          'See daily income, incentives, tips, and wallet movement in one elegant command center.',
      icon: Icons.bar_chart_rounded,
      accent: AppColors.emerald,
    ),
    _OnboardingPageData(
      title: 'Control availability like a pro.',
      subtitle:
          'Manage shifts, break mode, rider history, support, and profile settings without clutter.',
      icon: Icons.tune_rounded,
      accent: AppColors.sky,
    ),
  ];

  Future<void> _finish() async {
    await ref.read(sessionControllerProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Row(
              children: [
                const BrandMark(showWordmark: false),
                const Spacer(),
                TextButton(onPressed: _finish, child: const Text('Skip')),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _OnboardingPage(key: ValueKey(page.title), data: page);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: List.generate(
                _pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  margin: const EdgeInsets.only(right: AppSpacing.xs),
                  width: _index == index ? 30 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _index == index
                        ? _pages[index].accent
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                if (_index > 0)
                  Expanded(
                    child: SecondaryButton(
                      label: 'Back',
                      onPressed: () {
                        _controller.previousPage(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      icon: Icons.arrow_back_rounded,
                    ),
                  ),
                if (_index > 0) const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    label: _index == _pages.length - 1 ? 'Get Started' : 'Next',
                    expanded: true,
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      if (_index == _pages.length - 1) {
                        _finish();
                        return;
                      }
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({super.key, required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GlassCard(
            accent: data.accent,
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  right: -10,
                  child: Icon(
                    data.icon,
                    size: 140,
                    color: data.accent.withValues(alpha: 0.12),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: data.accent.withValues(alpha: 0.14),
                      ),
                      child: Icon(data.icon, size: 34, color: data.accent),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      data.subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: const [
                        _FeaturePill(label: 'Fast request review'),
                        _FeaturePill(label: 'Smooth route actions'),
                        _FeaturePill(label: 'Shift and wallet control'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.32),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
}
