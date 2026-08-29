import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/app_providers.dart';
import '../../../shared/widgets/feedback_widgets.dart';
import '../../../shared/widgets/navigation_widgets.dart';
import '../../../shared/widgets/premium_controls.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _showReset = false;
  bool _loading = false;

  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 72),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sign in to start your shift.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // ── Login field ────────────────────────────
                PremiumTextField(
                  label: 'Email address',
                  hint: 'rider@example.com',
                  controller: _loginController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_rounded,
                ),

                const SizedBox(height: AppSpacing.lg),
                PremiumTextField(
                  label: 'Password',
                  hint: 'Enter password',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_rounded,
                ),

                // ── Reset flow ─────────────────────────────
                if (_showReset) ...[
                  const SizedBox(height: AppSpacing.lg),
                  PremiumTextField(
                    label: 'Reset OTP',
                    hint: 'OTP sent to your contact',
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.pin_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PremiumTextField(
                    label: 'New password',
                    hint: 'Create new password',
                    controller: _newPasswordController,
                    obscureText: true,
                    prefixIcon: Icons.lock_reset_rounded,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),

                // ── Primary action ─────────────────────────
                PrimaryButton(
                  label: _actionLabel,
                  icon: Icons.arrow_forward_rounded,
                  expanded: true,
                  onPressed: _loading ? null : _handleAction,
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Forgot password link ───────────────────
                if (!_showReset)
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            final login = _loginController.text.trim();
                            if (login.isEmpty) {
                              showLuxurySnackBar(
                                context,
                                'Enter your email to request a reset.',
                              );
                              return;
                            }
                            setState(() => _loading = true);
                            try {
                              await ref
                                  .read(sessionControllerProvider.notifier)
                                  .requestPasswordReset(login: login);
                              if (!context.mounted) return;
                              setState(() => _showReset = true);
                              showLuxurySnackBar(
                                context,
                                'Reset OTP sent to $login.',
                              );
                            } on ApiException catch (e) {
                              if (!context.mounted) return;
                              _showAuthError(e.message);
                            } catch (e) {
                              if (!context.mounted) return;
                              _showAuthError(_fallbackErrorMessage(e));
                            } finally {
                              if (context.mounted) {
                                setState(() => _loading = false);
                              }
                            }
                          },
                    child: const Text('Forgot password?'),
                  ),
                const SizedBox(height: AppSpacing.lg),

                // ── Signup link ────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New to Mangaale?',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.signup),
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _actionLabel {
    if (_loading) return 'Please wait...';
    if (_showReset) return 'Reset password';
    return 'Sign in';
  }

  Future<void> _handleAction() async {
    final login = _loginController.text.trim();
    if (login.isEmpty) {
      _showAuthError('Enter your phone or email.');
      return;
    }
    if (_showReset) {
      if (_otpController.text.trim().isEmpty) {
        _showAuthError('Enter the reset OTP.');
        return;
      }
      if (_newPasswordController.text.trim().isEmpty) {
        _showAuthError('Enter a new password.');
        return;
      }
    } else if (_passwordController.text.trim().isEmpty) {
      _showAuthError('Enter your password.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_showReset) {
        await ref
            .read(sessionControllerProvider.notifier)
            .resetPassword(
              login: login,
              otp: _otpController.text.trim(),
              newPassword: _newPasswordController.text.trim(),
            );
        if (!mounted) return;
        showLuxurySnackBar(context, 'Password reset successful. Sign in now.');
        setState(() {
          _showReset = false;
          _loading = false;
        });
        return;
      }

      await ref
          .read(sessionControllerProvider.notifier)
          .loginWithPassword(
            login: login,
            password: _passwordController.text.trim(),
          );

      if (!mounted) return;
      final session = ref.read(sessionControllerProvider);
      if (session.status != AuthStatus.authenticated) {
        throw const ApiException(
          message: 'Login did not complete. Please try again.',
          errorCode: 'AUTH_STATE_NOT_READY',
        );
      }
      final role = session.role;
      final route = AppRoutes.resolvePostAuthRoute(role: role);
      AppRoutes.debugLogPostAuthRoute(
        source: 'login',
        role: role,
        route: route,
      );
      setState(() => _loading = false);
      context.go(route);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showAuthError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showAuthError(_fallbackErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAuthError(String message) {
    showLuxurySnackBar(context, message, isError: true);
  }

  String _fallbackErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    if (kDebugMode) {
      return 'Login failed: $error';
    }
    return 'Login failed. Please try again.';
  }
}


