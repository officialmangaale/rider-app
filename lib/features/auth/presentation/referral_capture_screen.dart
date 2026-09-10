import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/core_providers.dart';
import '../../../shared/widgets/premium_controls.dart';
import '../../../shared/widgets/premium_surfaces.dart';
import '../domain/pending_referral.dart';

/// Landing point for a referral deep link.
///
/// Reached from `mangaale-rider://referral/<code>` and from
/// `https://mangaale.com/r/<code>` once the App Link is verified. It stores
/// the code and sends the rider on; nothing is attributed here, because
/// attribution is authenticated and this rider has no account yet.
class ReferralCaptureScreen extends ConsumerStatefulWidget {
  const ReferralCaptureScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<ReferralCaptureScreen> createState() =>
      _ReferralCaptureScreenState();
}

class _ReferralCaptureScreenState extends ConsumerState<ReferralCaptureScreen> {
  String? _message;
  bool _canSignUp = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // Deferred so the first frame renders before any navigation decision.
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    if (_handled) return;
    _handled = true;

    final normalized = normalizeReferralCode(widget.code);
    final prefs = ref.read(appPreferencesProvider);
    final session = ref.read(sessionControllerProvider);

    if (!isRiderReferralCode(normalized)) {
      _show('That referral link is not valid for the rider app.', canSignUp: false);
      return;
    }

    // Referral codes are for new accounts. Saying so plainly is better than
    // storing a code that would be refused later.
    if (session.status == AuthStatus.authenticated) {
      _show(referralForNewAccountsMessage, canSignUp: false);
      return;
    }

    final stored = prefs.pendingReferral;
    if (shouldStoreReferral(
      incoming: normalized,
      stored: stored,
      now: DateTime.now(),
    )) {
      await prefs.setPendingReferral(normalized);
    }

    if (!mounted) return;
    _show(
      'Referral code $normalized saved. It will be applied when you create '
      'your account.',
      canSignUp: true,
    );
  }

  void _show(String message, {required bool canSignUp}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _canSignUp = canSignUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return PremiumScaffold(
      title: 'Referral invite',
      subtitle: 'Join Mangaale as a delivery rider.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  eyebrow: 'REFERRAL CODE',
                  title: normalizeReferralCode(widget.code),
                  subtitle: message ?? 'Checking this invite…',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (message != null) ...[
                  if (_canSignUp)
                    PrimaryButton(
                      label: 'Create my rider account',
                      icon: Icons.arrow_forward_rounded,
                      expanded: true,
                      onPressed: () => context.go(AppRoutes.signup),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: _canSignUp ? 'Not now' : 'Continue',
                    expanded: true,
                    onPressed: () => context.go(
                      ref.read(sessionControllerProvider).status ==
                              AuthStatus.authenticated
                          ? AppRoutes.home
                          : AppRoutes.login,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
