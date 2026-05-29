import 'dart:math';
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
  AppLanguage?         _selected;
  late AnimationController _fadeIn;
  final FluidController    _fluidCtrl = FluidController();

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

  Widget _maybeOrb(Widget child) {
    final e = _fluidCtrl.engine;
    final r = _fluidCtrl.repaint;
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

// ─── Card ─────────────────────────────────────────────────────────────────────
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
  final GlobalKey _key = GlobalKey();

  // Orb state — updated from listener, never during build
  Offset _localOrb     = const Offset(0.5, 0.5);
  double _proximity    = 0.0;
  int    _frameSkip    = 0;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0,
      upperBound: 1,
    );
    widget.fluidCtrl.repaint?.addListener(_onFrame);
  }

  @override
  void dispose() {
    widget.fluidCtrl.repaint?.removeListener(_onFrame);
    _press.dispose();
    super.dispose();
  }

  void _onFrame() {
    // Only update every 3rd frame — 60fps → 20fps for glass effect, plenty smooth
    _frameSkip++;
    if (_frameSkip % 3 != 0) return;
    if (!mounted) return;

    final engine = widget.fluidCtrl.engine;
    if (engine == null) return;

    final ctx = _key.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final screenSize = MediaQuery.of(context).size;
    final orbSx = engine.orbX * screenSize.width;
    final orbSy = engine.orbY * screenSize.height;
    final pos  = box.localToGlobal(Offset.zero);
    final sz   = box.size;

    final lx = orbSx - pos.dx;
    final ly = orbSy - pos.dy;
    final cdx = lx - sz.width  / 2;
    final cdy = ly - sz.height / 2;
    final dist    = sqrt(cdx * cdx + cdy * cdy);
    final maxDist = sz.width * 1.2;
    final prox    = (1.0 - dist / maxDist).clamp(0.0, 1.0);

    // Only call setState when values actually changed meaningfully
    final newOrb = Offset(lx / sz.width, ly / sz.height);
    if ((prox - _proximity).abs() < 0.01 &&
        (newOrb.dx - _localOrb.dx).abs() < 0.01 &&
        (newOrb.dy - _localOrb.dy).abs() < 0.01) return;

    setState(() {
      _localOrb  = newOrb;
      _proximity = prox;
    });
  }

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
        child: _buildCard(),
      ),
    );
  }

  Widget _buildCard() {
    const orbColor   = Color(0xFFc026d3);
    final prox       = _proximity;
    final glowAlpha  = prox * 0.35;
    final rimAlpha   = prox * 0.55;
    final rx         = (_localOrb.dx - 0.5) * 2.0;
    final ry         = (_localOrb.dy - 0.5) * 2.0;

    return SizedBox(
      key: _key,
      height: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Base glass (no BackdropFilter — works on all platforms) ──────
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: widget.selected
                  ? const Color(0x2Aa855f7)
                  : Color.lerp(
                      const Color(0x22ffffff),
                      orbColor.withOpacity(0.18),
                      prox,
                    ),
            ),
          ),

          // ── Orb glow bleed ───────────────────────────────────────────────
          if (prox > 0.02)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        rx.clamp(-1.2, 1.2),
                        ry.clamp(-1.2, 1.2),
                      ),
                      radius: 1.0,
                      colors: [
                        orbColor.withOpacity(glowAlpha),
                        orbColor.withOpacity(glowAlpha * 0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // ── Specular highlight ───────────────────────────────────────────
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(
                      (-0.6 + rx * 0.4).clamp(-1.0, 1.0),
                      (-1.0 + ry * 0.3).clamp(-1.0, 1.0),
                    ),
                    end: const Alignment(0.6, 1.0),
                    colors: [
                      Colors.white.withOpacity(0.10 + rimAlpha * 0.15),
                      Colors.white.withOpacity(0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Border ───────────────────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.selected
                      ? AppTheme.midPurple
                      : Color.lerp(
                          AppTheme.glassBorder,
                          orbColor.withOpacity(0.9),
                          prox * 0.7,
                        )!,
                  width: widget.selected ? 1.2 : (0.7 + prox * 0.6),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          Padding(
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
                  opacity:  widget.selected ? 1.0 : 0.0,
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
        ],
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