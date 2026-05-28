import 'dart:math';
import 'package:flutter/material.dart';
import '../models/app_theme.dart';
import '../models/onboarding_data.dart';
import '../widgets/fluid_background.dart';
import 'login_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final AppLanguage language;
  final Map<String, dynamic> answers;

  const ProcessingScreen({
    super.key,
    required this.language,
    required this.answers,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  final FluidController _fluidCtrl = FluidController();

  // Pulsing orb overlay
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Text fade sequence
  late AnimationController _textCtrl;
  late Animation<double> _text1Opacity;
  late Animation<double> _text2Opacity;
  late Animation<double> _text3Opacity;

  // Final fade out
  late AnimationController _exitCtrl;

  @override
  void initState() {
    super.initState();

    // Pulse — gentle slow breathing
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Text sequence — 3 lines fade in one by one
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();

    _text1Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _text2Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );
    _text3Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.6, 0.9, curve: Curves.easeOut),
      ),
    );

    // Exit after 3.5 seconds
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      _exitCtrl.forward().then((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          _smoothRoute(LoginScreen(language: widget.language)),
        );
      });
    });

    // Fluid: slow and moody during processing
    Future.delayed(const Duration(milliseconds: 100), () {
      _fluidCtrl.setSpeed(0.5);
      _fluidCtrl.setMood(-0.2);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  String get _line1 {
    switch (widget.language) {
      case AppLanguage.franko:  return 'tayeb.';
      case AppLanguage.arabic:  return 'تمام.';
      case AppLanguage.english: return 'got it.';
    }
  }

  String get _line2 {
    switch (widget.language) {
      case AppLanguage.franko:  return 'benbda n2ra elly 2olto.';
      case AppLanguage.arabic:  return 'بنبدأ نقرأ اللي قلته.';
      case AppLanguage.english: return 'reading what you shared.';
    }
  }

  String get _line3 {
    switch (widget.language) {
      case AppLanguage.franko:  return 'el ba2y hayban ma3ak.';
      case AppLanguage.arabic:  return 'الباقي هيبان معاك.';
      case AppLanguage.english: return 'the rest will show with time.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (_, child) => Opacity(
        opacity: 1.0 - _exitCtrl.value,
        child: child,
      ),
      child: FluidBackground(
        controller: _fluidCtrl,
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseAnim, _textCtrl]),
            builder: (_, __) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing orb glow (decorative — fluid bg is the real orb)
                Opacity(
                  opacity: _pulseAnim.value * 0.15,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.midPurple,
                          blurRadius: 80 + _pulseAnim.value * 40,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Text sequence
                FadeTransition(
                  opacity: _text1Opacity,
                  child: Text(_line1, style: _textStyle(22, FontWeight.w200)),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _text2Opacity,
                  child: Text(_line2, style: _textStyle(15, FontWeight.w300)),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _text3Opacity,
                  child: Text(_line3, style: _textStyle(15, FontWeight.w300)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _textStyle(double size, FontWeight weight) => TextStyle(
        color: AppTheme.textSecondary,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0.5,
        height: 1.5,
      );
}

PageRoute _smoothRoute(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 800),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );