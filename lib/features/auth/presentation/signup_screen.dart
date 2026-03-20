import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();

  bool _submitting = false;
  String _vehicleType = _vehicleOptions.first;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) {
      return;
    }

    setState(() => _submitting = false);
    showLuxurySnackBar(
      context,
      'Signup flow is ready. Enable rider onboarding services to send applications.',
    );
  }

  void _goToLogin() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1140),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 11,
                            child: _SignupStoryPanel(onSignIn: _goToLogin),
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          Expanded(
                            flex: 9,
                            child: _SignupFormCard(
                              formKey: _formKey,
                              fullNameController: _fullNameController,
                              phoneController: _phoneController,
                              cityController: _cityController,
                              emailController: _emailController,
                              selectedVehicle: _vehicleType,
                              submitting: _submitting,
                              onVehicleChanged: (value) {
                                setState(() => _vehicleType = value);
                              },
                              onSubmit: _submit,
                              onSignIn: _goToLogin,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SignupStoryPanel(onSignIn: _goToLogin),
                          const SizedBox(height: AppSpacing.xl),
                          _SignupFormCard(
                            formKey: _formKey,
                            fullNameController: _fullNameController,
                            phoneController: _phoneController,
                            cityController: _cityController,
                            emailController: _emailController,
                            selectedVehicle: _vehicleType,
                            submitting: _submitting,
                            onVehicleChanged: (value) {
                              setState(() => _vehicleType = value);
                            },
                            onSubmit: _submit,
                            onSignIn: _goToLogin,
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SignupStoryPanel extends StatelessWidget {
  const _SignupStoryPanel({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandMark().animate().fadeIn(duration: 420.ms),
            const Spacer(),
            IconActionChip(
              label: 'Sign in',
              icon: Icons.arrow_back_rounded,
              onTap: onSignIn,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: const [
            StatusPill(
              label: '3-minute setup',
              color: AppColors.gold,
              icon: Icons.bolt_rounded,
            ),
            StatusPill(
              label: 'Phone-first flow',
              color: AppColors.sky,
              icon: Icons.phone_android_rounded,
            ),
            StatusPill(
              label: 'Docs later',
              color: AppColors.emerald,
              icon: Icons.verified_user_outlined,
            ),
          ],
        ).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Start your rider signup with only the essentials.',
          style: Theme.of(context).textTheme.displayMedium,
        ).animate().fadeIn(delay: 120.ms).slideX(begin: -0.03),
        const SizedBox(height: AppSpacing.md),
        Text(
          'A premium onboarding flow that keeps the first step simple: basic details, preferred vehicle, and a clear path to phone verification.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.6,
            color: scheme.onSurfaceVariant,
          ),
        ).animate().fadeIn(delay: 180.ms),
        const SizedBox(height: AppSpacing.xl),
        GlassCard(
          accent: AppColors.sky,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SignupBenefitRow(
                icon: Icons.person_outline_rounded,
                accent: AppColors.gold,
                title: 'Tell us who you are',
                subtitle:
                    'Name, mobile number, and city keep the opening step easy to finish on the move.',
              ),
              SizedBox(height: AppSpacing.lg),
              _SignupBenefitRow(
                icon: Icons.two_wheeler_rounded,
                accent: AppColors.ember,
                title: 'Pick your delivery vehicle',
                subtitle:
                    'Bike, scooter, or cycle selection makes the profile feel personalized right away.',
              ),
              SizedBox(height: AppSpacing.lg),
              _SignupBenefitRow(
                icon: Icons.sms_outlined,
                accent: AppColors.emerald,
                title: 'Finish verification next',
                subtitle:
                    'OTP confirmation, documents, and payout details can follow after the first signup step.',
              ),
            ],
          ),
        ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.03),
      ],
    );
  }
}

class _SignupFormCard extends StatelessWidget {
  const _SignupFormCard({
    required this.formKey,
    required this.fullNameController,
    required this.phoneController,
    required this.cityController,
    required this.emailController,
    required this.selectedVehicle,
    required this.submitting,
    required this.onVehicleChanged,
    required this.onSubmit,
    required this.onSignIn,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController cityController;
  final TextEditingController emailController;
  final String selectedVehicle;
  final bool submitting;
  final ValueChanged<String> onVehicleChanged;
  final VoidCallback onSubmit;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      accent: AppColors.gold,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create your rider profile',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Clean, fast, and easy to understand. Enter the essentials now and continue verification in the next step.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PremiumTextField(
              label: 'Full name',
              hint: 'Ravi Kumar',
              controller: fullNameController,
              prefixIcon: Icons.badge_outlined,
              validator: (value) {
                if (value == null || value.trim().length < 3) {
                  return 'Enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            PremiumTextField(
              label: 'Mobile number',
              hint: '+91 98765 43210',
              controller: phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_rounded,
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.length < 10) {
                  return 'Enter a valid mobile number';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            PremiumTextField(
              label: 'Operating city',
              hint: 'Bengaluru',
              controller: cityController,
              prefixIcon: Icons.location_on_outlined,
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Enter your city';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            PremiumTextField(
              label: 'Email address',
              hint: 'ravi@example.com',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return null;
                }
                final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailPattern.hasMatch(trimmed)) {
                  return 'Enter a valid email or leave it blank';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Preferred vehicle',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final option in _vehicleOptions)
                  _VehicleTypeChip(
                    label: option,
                    selected: selectedVehicle == option,
                    onTap: () => onVehicleChanged(option),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: AppColors.emerald.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.emerald.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.emerald.withValues(alpha: 0.14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.emerald,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Phone OTP, ID checks, and document upload can happen after this simple signup step.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: submitting ? 'Preparing signup...' : 'Continue signup',
              expanded: true,
              icon: Icons.person_add_alt_1_rounded,
              onPressed: submitting ? null : onSubmit,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Registration sending will go live once rider onboarding services are enabled.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                children: [
                  Text(
                    'Already have rider access?',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: onSignIn,
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.03);
  }
}

class _SignupBenefitRow extends StatelessWidget {
  const _SignupBenefitRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: accent.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VehicleTypeChip extends StatelessWidget {
  const _VehicleTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.gold, AppColors.amber],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.72),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? AppColors.obsidian : null,
          ),
        ),
      ),
    );
  }
}

const _vehicleOptions = ['Bike', 'Scooter', 'Cycle'];
