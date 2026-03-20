import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_models.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _usePhone = true;
  bool _submitting = false;
  bool _otpSent = false;
  AuthOtpChallenge? _otpChallenge;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final form = _usePhone
        ? _phoneFormKey.currentState
        : _emailFormKey.currentState;
    if (!(form?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final session = ref.read(sessionControllerProvider.notifier);
      if (_usePhone) {
        if (!_otpSent) {
          final challenge = await session.sendLoginOtp(
            login: _phoneController.text.trim(),
          );
          if (!mounted) {
            return;
          }
          setState(() {
            _otpSent = true;
            _otpChallenge = challenge;
          });
          showLuxurySnackBar(
            context,
            'OTP sent via ${challenge.channel}. It expires in ${_minutesLabel(challenge.expiresInSeconds)}.',
          );
          return;
        }

        await session.verifyLoginOtp(
          login: _phoneController.text.trim(),
          otp: _otpController.text.trim(),
        );
        if (!mounted) {
          return;
        }
        showLuxurySnackBar(context, 'Phone login verified. Welcome back.');
        context.go('/home');
        return;
      }

      await session.loginWithPassword(
        login: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      showLuxurySnackBar(context, 'Signed in to the rider command deck.');
      context.go('/home');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      showLuxurySnackBar(context, _authErrorMessage(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      showLuxurySnackBar(context, 'We could not complete sign in right now.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _showForgotPasswordSheet() {
    final initialLogin = _usePhone
        ? _phoneController.text.trim()
        : _emailController.text.trim();
    return showPremiumBottomSheet(
      context: context,
      title: 'Reset access',
      subtitle:
          'Request a reset OTP, then set a fresh password without leaving the app.',
      child: _ForgotPasswordSheet(initialLogin: initialLogin),
    );
  }

  void _switchMode(bool usePhone) {
    if (_usePhone == usePhone) {
      return;
    }
    setState(() {
      _usePhone = usePhone;
      _otpSent = false;
      _otpChallenge = null;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandMark().animate().fadeIn(duration: 500.ms),
                const SizedBox(height: AppSpacing.xxxl),
                Text(
                  'Enter the rider command deck.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Use mobile OTP or your rider password to access dispatch, delivery flow, earnings, and wallet controls.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _AuthModeChip(
                              label: 'Phone + OTP',
                              active: _usePhone,
                              onTap: () => _switchMode(true),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _AuthModeChip(
                              label: 'Email login',
                              active: !_usePhone,
                              onTap: () => _switchMode(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: _usePhone
                            ? Form(
                                key: _phoneFormKey,
                                child: Column(
                                  key: const ValueKey('phone'),
                                  children: [
                                    PremiumTextField(
                                      label: 'Phone number',
                                      hint: '+91 98765 43210',
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      prefixIcon: Icons.phone_rounded,
                                      validator: (value) {
                                        final digits = (value ?? '').replaceAll(
                                          RegExp(r'\D'),
                                          '',
                                        );
                                        if (digits.length < 10) {
                                          return 'Enter a valid phone number';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_otpSent) ...[
                                      const SizedBox(height: AppSpacing.lg),
                                      PremiumTextField(
                                        label: 'OTP code',
                                        hint: '6-digit rider OTP',
                                        controller: _otpController,
                                        keyboardType: TextInputType.number,
                                        prefixIcon: Icons.password_rounded,
                                        validator: (value) =>
                                            (value == null || value.trim().length < 4)
                                            ? 'Enter the OTP code'
                                            : null,
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : Form(
                                key: _emailFormKey,
                                child: Column(
                                  key: const ValueKey('email'),
                                  children: [
                                    PremiumTextField(
                                      label: 'Email address',
                                      hint: 'dispatch@rydexrider.com',
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: Icons.mail_outline_rounded,
                                      validator: (value) =>
                                          value == null || !value.contains('@')
                                          ? 'Enter a valid email'
                                          : null,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    PremiumTextField(
                                      label: 'Password',
                                      hint: 'Secure rider password',
                                      controller: _passwordController,
                                      obscureText: true,
                                      prefixIcon: Icons.lock_outline_rounded,
                                      validator: (value) =>
                                          value == null || value.length < 6
                                          ? 'Use at least 6 characters'
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      if (_usePhone && _otpSent && _otpChallenge != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'OTP sent via ${_otpChallenge!.channel}. Expires in ${_minutesLabel(_otpChallenge!.expiresInSeconds)}.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _submitting ? null : _showForgotPasswordSheet,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PrimaryButton(
                        label: _primaryActionLabel,
                        icon: _usePhone && _otpSent
                            ? Icons.verified_user_rounded
                            : Icons.arrow_forward_rounded,
                        expanded: true,
                        onPressed: _submitting ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.xs,
                          children: [
                            Text(
                              'New rider to Rydex?',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => context.push('/signup'),
                              child: const Text('Create account'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                GlassCard(
                  accent: AppColors.ember,
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: AppColors.ember.withValues(alpha: 0.14),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.ember,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Live backend authentication is connected. Token refresh and rider session persistence now run through the API client.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _primaryActionLabel {
    if (_submitting) {
      return _usePhone
          ? (_otpSent ? 'Verifying...' : 'Sending OTP...')
          : 'Signing in...';
    }
    if (_usePhone) {
      return _otpSent ? 'Verify OTP' : 'Send OTP';
    }
    return 'Enter App';
  }

  String _minutesLabel(int seconds) {
    final minutes = (seconds / 60).ceil();
    return '$minutes min';
  }

  String _authErrorMessage(ApiException error) {
    if (error.isValidationError && error.errors.isNotEmpty) {
      final firstEntry = error.errors.entries.first;
      return '${firstEntry.key}: ${firstEntry.value}';
    }
    return error.message;
  }
}

class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  const _ForgotPasswordSheet({required this.initialLogin});

  final String initialLogin;

  @override
  ConsumerState<_ForgotPasswordSheet> createState() =>
      _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _loginController;
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _requesting = false;
  bool _resetting = false;
  bool _otpSent = false;
  AuthOtpChallenge? _challenge;

  @override
  void initState() {
    super.initState();
    _loginController = TextEditingController(text: widget.initialLogin);
  }

  @override
  void dispose() {
    _loginController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetOtp() async {
    if ((_loginController.text).trim().isEmpty) {
      showLuxurySnackBar(context, 'Enter your phone or email first.');
      return;
    }
    setState(() => _requesting = true);
    try {
      final challenge = await ref
          .read(sessionControllerProvider.notifier)
          .requestPasswordReset(login: _loginController.text.trim());
      if (!mounted) {
        return;
      }
      setState(() {
        _otpSent = true;
        _challenge = challenge;
      });
      showLuxurySnackBar(
        context,
        'Reset OTP sent via ${challenge.channel}.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      showLuxurySnackBar(context, error.message);
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _resetting = true);
    try {
      await ref.read(sessionControllerProvider.notifier).resetPassword(
        login: _loginController.text.trim(),
        otp: _otpController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      showLuxurySnackBar(
        context,
        'Password updated. You can sign in with the new password now.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      showLuxurySnackBar(context, error.message);
    } finally {
      if (mounted) {
        setState(() => _resetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumTextField(
            label: 'Phone or email',
            hint: 'rider@example.com',
            controller: _loginController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.person_outline_rounded,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter your phone or email'
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _requesting ? 'Sending reset OTP...' : 'Send reset OTP',
            expanded: true,
            icon: Icons.mark_email_read_rounded,
            onPressed: _requesting || _resetting ? null : _sendResetOtp,
          ),
          if (_otpSent) ...[
            const SizedBox(height: AppSpacing.lg),
            PremiumTextField(
              label: 'Reset OTP',
              hint: '6-digit OTP',
              controller: _otpController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.password_rounded,
              validator: (value) => value == null || value.trim().length < 4
                  ? 'Enter the reset OTP'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            PremiumTextField(
              label: 'New password',
              hint: 'Create a new secure password',
              controller: _passwordController,
              obscureText: true,
              prefixIcon: Icons.lock_reset_rounded,
              validator: (value) => value == null || value.length < 6
                  ? 'Use at least 6 characters'
                  : null,
            ),
            if (_challenge != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'OTP expires in ${(_challenge!.expiresInSeconds / 60).ceil()} min.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: _resetting ? 'Resetting password...' : 'Reset password',
              expanded: true,
              icon: Icons.check_circle_outline_rounded,
              onPressed: _requesting || _resetting ? null : _resetPassword,
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthModeChip extends StatelessWidget {
  const _AuthModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: active
              ? const LinearGradient(colors: [AppColors.gold, AppColors.amber])
              : null,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: active ? AppColors.obsidian : null,
            ),
          ),
        ),
      ),
    );
  }
}



