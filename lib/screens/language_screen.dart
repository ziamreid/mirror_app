import 'dart:ui';
import 'package:flutter/material.dart';
import '../fluid_painter.dart';
import '../models/app_theme.dart';
import '../models/onboarding_data.dart';
import '../widgets/fluid_background.dart';
import '../widgets/orb_aware_text.dart';
import 'onboarding_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen>
    with SingleTickerProviderStateMixin {
  AppLanguage?          _selected;
  late AnimationController _fadeIn;
  final FluidController    _fluidCtrl  = FluidController();
  // GlobalKey for the cards column — touches inside here won't move the orb

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    super.dispose();
  }

  void _onSelect(AppLanguage lang) {
    if (_selected != null) return;
    setState(() => _selected = lang);
    _fluidCtrl.setSpeed(1.6);
    _fluidCtrl.setMood(0.5);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      _fluidCtrl.setSpeed(1.0);
      Navigator.of(context).push(_smoothRoute(OnboardingScreen(language: lang)));
    });
  }

  FluidEngine?        get _engine  => _fluidCtrl.engine;
  ValueNotifier<int>? get _repaint => _fluidCtrl.repaint;

  Widget _maybeOrb(Widget child) {
    final e = _engine;
    final r = _repaint;
    if (e == null || r == null) return child;
    return OrbAwareText(engine: e, repaint: r, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return FluidBackground(
      controller: _fluidCtrl,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeIn, curve: Curves.easeOut),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 52),
                _maybeOrb(const Text('EYE', style: AppTheme.appNameStyle)),
                const SizedBox(height: 6),
                _maybeOrb(Text(
                  'CHOOSE YOUR LANGUAGE',
                  style: AppTheme.labelStyle.copyWith(
                    color: AppTheme.textHint,
                    letterSpacing: 2.2,
                  ),
                )),
                const Spacer(),
                // Wrap cards in a keyed container — touches here are blocked
                Column(
                  children: [
                    _LangCard(
                      label: 'ENGLISH',
                      sublabel: 'speak to me clearly',
                      emoji: '🌐',
                      selected: _selected == AppLanguage.english,
                      onTap: () => _onSelect(AppLanguage.english),
                      fluidCtrl: _fluidCtrl,
                    ),
                    const SizedBox(height: 12),
                    _LangCard(
                      label: 'FRANKO',
                      sublabel: 'kalam 3adi zayak',
                      emoji: '💬',
                      selected: _selected == AppLanguage.franko,
                      onTap: () => _onSelect(AppLanguage.franko),
                      fluidCtrl: _fluidCtrl,
                    ),
                    const SizedBox(height: 12),
                    _LangCard(
                      label: 'عربي',
                      sublabel: 'بالكلام الصريح',
                      emoji: '✦',
                      selected: _selected == AppLanguage.arabic,
                      onTap: () => _onSelect(AppLanguage.arabic),
                      isArabic: true,
                      fluidCtrl: _fluidCtrl,
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: _maybeOrb(Text(
                    'you can change this later',
                    style: AppTheme.labelStyle.copyWith(
                      color: AppTheme.textHint,
                      letterSpacing: 0.8,
                    ),
                  )),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Language card ────────────────────────────────────────────────────────────
class _LangCard extends StatefulWidget {
  final String          label;
  final String          sublabel;
  final String          emoji;
  final bool            selected;
  final bool            isArabic;
  final VoidCallback    onTap;
  final FluidController fluidCtrl;

  const _LangCard({
    required this.label,
    required this.sublabel,
    required this.emoji,
    required this.selected,
    required this.onTap,
    required this.fluidCtrl,
    this.isArabic = false,
  });

  @override
  State<_LangCard> createState() => _LangCardState();
}

class _LangCardState extends State<_LangCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0, upperBound: 1,
    );
  }

  @override
  void dispose() { _press.dispose(); super.dispose(); }

  Widget _orb(Widget child) {
    final e = widget.fluidCtrl.engine;
    final r = widget.fluidCtrl.repaint;
    if (e == null || r == null) return child;
    return OrbAwareText(engine: e, repaint: r, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _press.forward(),
      onTapUp:     (_) { _press.reverse(); widget.onTap(); },
      onTapCancel: ()  => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - _press.value * 0.03,
          child: child,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 84,
              decoration: BoxDecoration(
                color: widget.selected
                    ? const Color(0x22a855f7)
                    : const Color(0x18000000),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.selected
                      ? AppTheme.midPurple
                      : AppTheme.glassBorder,
                  width: widget.selected ? 1.2 : 0.7,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  _orb(Text(
                    widget.emoji,
                    style: TextStyle(
                      fontSize: 20,
                      color: widget.selected
                          ? AppTheme.midPurple
                          : AppTheme.textSecondary,
                    ),
                  )),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _orb(Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: '.SF Pro Rounded',
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: widget.selected
                              ? FontWeight.w500
                              : FontWeight.w300,
                          letterSpacing: widget.isArabic ? 0.5 : 2.8,
                        ),
                      )),
                      const SizedBox(height: 4),
                      _orb(Text(
                        widget.sublabel,
                        style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.textHint,
                          letterSpacing: widget.isArabic ? 0.3 : 0.7,
                          fontSize: 10,
                        ),
                      )),
                    ],
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: widget.selected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.midPurple,
                        shape: BoxShape.circle,
                      ),
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

PageRoute _smoothRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 500),
  transitionsBuilder: (_, anim, __, child) => FadeTransition(
    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
    child: child,
  ),
);