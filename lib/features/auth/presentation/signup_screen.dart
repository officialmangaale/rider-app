import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  String _vehicleType = 'Motorcycle';
  bool _submitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _licenseNumberController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back button ──────────────────────────────
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/login'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                'Join Mangaale Express',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Register as a delivery rider.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // ── Story panel ──────────────────────────────
              GlassCard(
                accent: AppColors.gold,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Why ride with us?',
                      subtitle: 'Top reasons riders choose Mangaale.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final benefit in const [
                      'Premium payouts every Tuesday & Friday',
                      'Priority dispatch for top-rated riders',
                      'Transparent trip earnings — no hidden cuts',
                      'In-app safety tools and emergency support',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                benefit,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Signup form ──────────────────────────────
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(
                      title: 'Rider details',
                      subtitle: 'Fill in your information to get started.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumTextField(
                      label: 'First name',
                      hint: 'Abdullahi',
                      controller: _firstNameController,
                      prefixIcon: Icons.person_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumTextField(
                      label: 'Last name',
                      hint: 'Ahmed',
                      controller: _lastNameController,
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumTextField(
                      label: 'Phone number',
                      hint: '9876543210',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumTextField(
                      label: 'Email address',
                      hint: 'name@example.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumTextField(
                      label: 'Password',
                      hint: 'Create a strong password',
                      controller: _passwordController,
                      obscureText: true,
                      prefixIcon: Icons.lock_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumTextField(
                      label: 'License number',
                      hint: 'DL-123456789',
                      controller: _licenseNumberController,
                      prefixIcon: Icons.badge_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PremiumTextField(
                      label: 'City',
                      hint: 'Your operating city',
                      controller: _cityController,
                      prefixIcon: Icons.location_city_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Vehicle type',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      children: ['Motorcycle', 'Scooter', 'Bicycle'].map((type) {
                        final selected = _vehicleType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _vehicleType = type),
                          selectedColor:
                              AppColors.riderPrimary.withValues(alpha: 0.14),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label:
                          _submitting ? 'Creating account...' : 'Sign up',
                      icon: Icons.arrow_forward_rounded,
                      expanded: true,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final password = _passwordController.text.trim();
    final licenseNumber = _licenseNumberController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final city = _cityController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        password.isEmpty ||
        licenseNumber.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        city.isEmpty) {
      showLuxurySnackBar(context, 'Please fill in all required fields.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(sessionControllerProvider.notifier).signup(
        firstName: firstName,
        lastName: lastName,
        password: password,
        licenseNumber: licenseNumber,
        phone: phone,
        email: email,
        city: city,
        vehicleType: _vehicleType.toLowerCase(),
      );
      if (!mounted) return;
      context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      showLuxurySnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
