import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_theme.dart';
import '../models/onboarding_data.dart';
import '../widgets/fluid_background.dart';

class LoginScreen extends StatefulWidget {
  final AppLanguage language;
  const LoginScreen({super.key, required this.language});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final FluidController _fluidCtrl = FluidController();
  late AnimationController _fadeIn;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    // Fluid: calm and trusting
    Future.delayed(const Duration(milliseconds: 100), () {
      _fluidCtrl.setSpeed(0.7);
      _fluidCtrl.setMood(0.1);
    });
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    super.dispose();
  }

  // ── Labels ─────────────────────────────────────────────────────────────────
  String get _headline {
    switch (widget.language) {
      case AppLanguage.franko:  return 'save your journey.';
      case AppLanguage.arabic:  return 'احفظ رحلتك.';
      case AppLanguage.english: return 'save your journey.';
    }
  }

  String get _subline {
    switch (widget.language) {
      case AppLanguage.franko:
        return 'elly 2olto mesh haye\'d3 —\nbass lazem account.';
      case AppLanguage.arabic:
        return 'اللي قلته مش هيضيع —\nبس محتاج حساب.';
      case AppLanguage.english:
        return 'what you shared won\'t be lost —\nbut you need an account.';
    }
  }

  String get _appleLabel {
    switch (widget.language) {
      case AppLanguage.franko:  return 'Continue with Apple';
      case AppLanguage.arabic:  return 'متابعة مع Apple';
      case AppLanguage.english: return 'Continue with Apple';
    }
  }

  String get _googleLabel {
    switch (widget.language) {
      case AppLanguage.franko:  return 'Continue with Google';
      case AppLanguage.arabic:  return 'متابعة مع Google';
      case AppLanguage.english: return 'Continue with Google';
    }
  }

  String get _privacyNote {
    switch (widget.language) {
      case AppLanguage.franko:
        return 'kolha private. ma7adesh shayef gheirak.';
      case AppLanguage.arabic:
        return 'كلها private. محدش شايف غيرك.';
      case AppLanguage.english:
        return 'everything is private. only you can see this.';
    }
  }

  TextDirection get _dir => widget.language == AppLanguage.arabic
      ? TextDirection.rtl
      : TextDirection.ltr;

  void _mockLogin(String provider) async {
    setState(() => _loading = true);
    // TODO Phase 2: real Apple/Google auth via Supabase
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    // Navigate to home (placeholder)
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const _PlaceholderHome(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FluidBackground(
      controller: _fluidCtrl,
      child: FadeTransition(
        opacity: _fadeIn,
        child: SafeArea(
          child: Directionality(
            textDirection: _dir,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),

                  // Headline
                  Text(
                    _headline,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w200,
                      letterSpacing: -0.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _subline,
                    style: AppTheme.choiceStyle.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Auth buttons
                  _AuthButton(
                    label: _appleLabel,
                    icon: Icons.apple,
                    onTap: _loading ? null : () => _mockLogin('apple'),
                    primary: true,
                  ),
                  const SizedBox(height: 12),
                  _AuthButton(
                    label: _googleLabel,
                    icon: Icons.g_mobiledata_rounded,
                    onTap: _loading ? null : () => _mockLogin('google'),
                    primary: false,
                  ),

                  const SizedBox(height: 28),

                  // Privacy note — the trust moment
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          color: AppTheme.textHint,
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _privacyNote,
                          style: AppTheme.labelStyle.copyWith(
                            color: AppTheme.textHint,
                            letterSpacing: 0.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Auth button ──────────────────────────────────────────────────────────────
class _AuthButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: widget.primary
                    ? const Color(0xEEFFFFFF)
                    : const Color(0x12FFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.primary
                      ? Colors.transparent
                      : AppTheme.glassBorder,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: widget.primary ? Colors.black : AppTheme.textPrimary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.primary
                          ? Colors.black
                          : AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Placeholder home (Phase 1 stub) ─────────────────────────────────────────
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'home screen\ncoming soon',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0x55FFFFFF),
            fontSize: 14,
            letterSpacing: 2,
            height: 2,
          ),
        ),
      ),
    );
  }
}