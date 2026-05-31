import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/fluid_background.dart';
import '../fluid_painter.dart';
import '../models/app_theme.dart';
import '../models/onboarding_data.dart';
import '../widgets/orb_aware_text.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final FluidController _fluidCtrl = FluidController();

  late AnimationController _bloomCtrl;
  late AnimationController _cardsCtrl;
  late AnimationController _maskCtrl;
  late Animation<double>   _maskAnim;

  late Animation<double> _card0, _card1, _card2, _headerAnim, _subtext;

  bool         _showCards = false;
  AppLanguage? _selected;

  final GlobalKey _headerKey       = GlobalKey();
  final GlobalKey _footerKey       = GlobalKey();
  double          _headerProximity = 0.0;
  double          _footerProximity = 0.0;
  int             _headerFrameSkip = 0;

  @override
  void initState() {
    super.initState();
    _bloomCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1300));
    _cardsCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2000));
    _maskCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _maskAnim = CurvedAnimation(parent: _maskCtrl, curve: Curves.easeInOut);

    _headerAnim = CurvedAnimation(parent: _cardsCtrl,
        curve: const Interval(0.00, 0.35, curve: Curves.easeOut));
    _card0 = CurvedAnimation(parent: _cardsCtrl,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic));
    _card1 = CurvedAnimation(parent: _cardsCtrl,
        curve: const Interval(0.28, 0.68, curve: Curves.easeOutCubic));
    _card2 = CurvedAnimation(parent: _cardsCtrl,
        curve: const Interval(0.42, 0.82, curve: Curves.easeOutCubic));
    _subtext = CurvedAnimation(parent: _cardsCtrl,
        curve: const Interval(0.75, 1.00, curve: Curves.easeOut));
    _runSequence();
  }

  Future<void> _runSequence() async {
    await _bloomCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _fluidCtrl.setSpeed(1.5);
    _maskCtrl.forward();
    setState(() => _showCards = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _maskCtrl.reverse();
    await _cardsCtrl.forward();
    if (!mounted) return;
    _fluidCtrl.setSpeed(1.0);
    _fluidCtrl.repaint?.addListener(_onFrame);
  }

  void _onFrame() {
    _headerFrameSkip++;
    if (_headerFrameSkip % 3 != 0) return;
    if (!mounted) return;
    final engine = _fluidCtrl.engine;
    if (engine == null) return;
    final screenSize = MediaQuery.of(context).size;
    final orbSx = engine.orbX * screenSize.width;
    final orbSy = engine.orbY * screenSize.height;

    final hctx = _headerKey.currentContext;
    if (hctx != null) {
      final box = hctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final pos = box.localToGlobal(Offset.zero);
        final sz  = box.size;
        final cdx = orbSx - (pos.dx + sz.width / 2);
        final cdy = orbSy - (pos.dy + sz.height / 2);
        final dist = sqrt(cdx * cdx + cdy * cdy);
        final prox = (1.0 - dist / (sz.width * 0.9)).clamp(0.0, 1.0);
        if ((prox - _headerProximity).abs() >= 0.01) {
          setState(() => _headerProximity = prox);
        }
      }
    }

    final fctx = _footerKey.currentContext;
    if (fctx != null) {
      final box = fctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final pos = box.localToGlobal(Offset.zero);
        final sz  = box.size;
        final cdx = orbSx - (pos.dx + sz.width / 2);
        final cdy = orbSy - (pos.dy + sz.height / 2);
        final dist = sqrt(cdx * cdx + cdy * cdy);
        final prox = (1.0 - dist / (sz.width * 0.8)).clamp(0.0, 1.0);
        if ((prox - _footerProximity).abs() >= 0.01) {
          setState(() => _footerProximity = prox);
        }
      }
    }
  }

  @override
  void dispose() {
    _fluidCtrl.repaint?.removeListener(_onFrame);
    _bloomCtrl.dispose();
    _cardsCtrl.dispose();
    _maskCtrl.dispose();
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
      Navigator.of(context)
          .pushReplacement(_smoothRoute(OnboardingScreen(language: lang)));
    });
  }

  FluidEngine?        get _engine  => _fluidCtrl.engine;
  ValueNotifier<int>? get _repaint => _fluidCtrl.repaint;

  @override
  Widget build(BuildContext context) {
    final ht = ((_headerProximity - 0.45) / 0.40).clamp(0.0, 1.0);
    final ft = ((_footerProximity - 0.40) / 0.40).clamp(0.0, 1.0);
    final headerColor    = Color.lerp(AppTheme.textPrimary,   const Color(0xFF1a0a2e), ht)!;
    final subheaderColor = Color.lerp(AppTheme.textSecondary, const Color(0x991a0a2e), ht)!;
    final footerColor    = Color.lerp(AppTheme.textHint,      const Color(0xFF1a0a2e), ft)!;

    return FluidBackground(
      controller: _fluidCtrl,
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  if (_showCards) ...[
                    AnimatedBuilder(
                      animation: _headerAnim,
                      builder: (_, __) => Opacity(
                        opacity: _headerAnim.value,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - _headerAnim.value)),
                          child: Column(
                            key: _headerKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Choose your language',
                                  style: AppTheme.headlineStyle.copyWith(
                                    fontSize: 22, color: headerColor)),
                              const SizedBox(height: 6),
                              Text('this shapes how Eye speaks to you',
                                  style: AppTheme.labelStyle.copyWith(
                                    color: subheaderColor, fontSize: 12,
                                    letterSpacing: 0.2, fontWeight: FontWeight.w400)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _MaterialCard(
                      progress: _card0, label: 'ENGLISH',
                      sublabel: 'speak to me clearly',
                      icon: const _EmojiIcon('🗽'),
                      selected: _selected == AppLanguage.english,
                      onTap: () => _onSelect(AppLanguage.english),
                      hasShimmer: false, engine: _engine, repaint: _repaint,
                      fluidCtrl: _fluidCtrl,
                    ),
                    const SizedBox(height: 12),
                    _MaterialCard(
                      progress: _card1, label: 'FRANKO',
                      sublabel: 'kalam 3adi zayak',
                      icon: const _FrankoIcon(),
                      selected: _selected == AppLanguage.franko,
                      onTap: () => _onSelect(AppLanguage.franko),
                      hasShimmer: true, engine: _engine, repaint: _repaint,
                      fluidCtrl: _fluidCtrl, isFranko: true,
                      slideFromRight: true,
                    ),
                    const SizedBox(height: 12),
                    _MaterialCard(
                      progress: _card2, label: 'مصري',
                      sublabel: 'بالكلام الصريح',
                      icon: const _ArabicIcon(),
                      selected: _selected == AppLanguage.arabic,
                      onTap: () => _onSelect(AppLanguage.arabic),
                      hasShimmer: false, isArabic: true,
                      engine: _engine, repaint: _repaint,
                      fluidCtrl: _fluidCtrl,
                    ),
                    const SizedBox(height: 24),
                    AnimatedBuilder(
                      animation: _subtext,
                      builder: (_, __) => Opacity(
                        opacity: _subtext.value,
                        child: Center(
                          child: Text('you can change this later',
                            key: _footerKey,
                            style: AppTheme.labelStyle.copyWith(
                                color: footerColor, letterSpacing: 0.8,
                                fontWeight: FontWeight.w400)),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(flex: 2),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _maskAnim,
              builder: (_, __) {
                final o = _maskAnim.value * 0.55;
                if (o <= 0.01) return const SizedBox.shrink();
                return Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.fromARGB((o * 255).round().clamp(0, 255), 0, 0, 0),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card widget ───────────────────────────────────────────────────────────────
class _MaterialCard extends StatefulWidget {
  final Animation<double>   progress;
  final String              label, sublabel;
  final Widget              icon;
  final bool                selected, isArabic, hasShimmer, isFranko;
  final bool                slideFromRight;
  final VoidCallback        onTap;
  final FluidEngine?        engine;
  final ValueNotifier<int>? repaint;
  final FluidController     fluidCtrl;

  const _MaterialCard({
    required this.progress, required this.label, required this.sublabel,
    required this.icon, required this.selected, required this.onTap,
    required this.hasShimmer, required this.fluidCtrl,
    this.engine, this.repaint, this.isArabic = false, this.isFranko = false,
    this.slideFromRight = false,
  });

  @override
  State<_MaterialCard> createState() => _MaterialCardState();
}

class _MaterialCardState extends State<_MaterialCard>
    with TickerProviderStateMixin {
  late AnimationController _press, _sweep;
  late AnimationController _badgeCtrl;
  late AnimationController _periodicShine;
  late Animation<double>   _sweepAnim;
  late Animation<double>   _badgeScale;
  late Animation<double>   _periodicShineAnim;
  bool   _sweptOnce    = false;
  bool   _shineForward = true;
  bool   _badgeDone  = false;
  Timer? _shineTimer;
  final  GlobalKey _key = GlobalKey();
  Offset _localOrb  = const Offset(0.5, 0.5);
  double _proximity = 0.0;
  int    _frameSkip = 0;

  // Shimmer animation duration — used to compute the idle gap so that
  // forward + reverse + gap = exactly 8 seconds total cycle.
  static const _shineDuration  = Duration(milliseconds: 900);
  static const _shineGap       = Duration(milliseconds: 6200); // 900+900+6200 = 8000ms

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 110), lowerBound: 0, upperBound: 1);
    _sweep = AnimationController(vsync: this, duration: _shineDuration);
    _sweepAnim = CurvedAnimation(parent: _sweep, curve: Curves.easeInOut);

    _badgeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _badgeScale = CurvedAnimation(parent: _badgeCtrl, curve: Curves.elasticOut);

    _periodicShine = AnimationController(vsync: this, duration: _shineDuration);
    _periodicShine.addStatusListener(_onShineStatus);
    _periodicShineAnim = CurvedAnimation(
        parent: _periodicShine, curve: Curves.easeInOut);

    if (widget.hasShimmer) widget.progress.addListener(_onProgressChange);
    widget.repaint?.addListener(_onFrame);

    if (widget.isFranko) {
      // First shine fires 2s after the card appears, then every 8s thereafter.
      _shineTimer = Timer(const Duration(seconds: 2), _startPeriodicShine);
    }
  }

  /// Runs one full shine sweep (forward → reverse) then schedules the next
  void _startPeriodicShine() {
    if (!mounted) return;
    _shineForward = true;
    _periodicShine.forward(from: 0);
  }

  void _onShineStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed && _shineForward) {
      _shineForward = false;
      _periodicShine.reverse();
    } else if (status == AnimationStatus.dismissed && !_shineForward) {
      _shineTimer = Timer(_shineGap, _startPeriodicShine);
    }
  }

  void _onProgressChange() {
    if (!_sweptOnce && widget.progress.value > 0.5) {
      _sweptOnce = true;
      _sweep.forward();
    }
    if (!_badgeDone && widget.isFranko && widget.progress.value > 0.92) {
      _badgeDone = true;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _badgeCtrl.forward();
      });
    }
  }

  void _onFrame() {
    _frameSkip++;
    if (_frameSkip % 3 != 0) return;
    if (!mounted) return;
    final engine = widget.engine; if (engine == null) return;
    final ctx = _key.currentContext; if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final screenSize = MediaQuery.of(context).size;
    final orbSx = engine.orbX * screenSize.width;
    final orbSy = engine.orbY * screenSize.height;
    final pos   = box.localToGlobal(Offset.zero);
    final sz    = box.size;
    final lx    = orbSx - pos.dx;
    final ly    = orbSy - pos.dy;
    final cdx   = lx - sz.width / 2;
    final cdy   = ly - sz.height / 2;
    final dist  = sqrt(cdx * cdx + cdy * cdy);
    final prox  = (1.0 - dist / (sz.width * 1.2)).clamp(0.0, 1.0);
    final newOrb = Offset(lx / sz.width, ly / sz.height);
    if ((prox - _proximity).abs() < 0.01 &&
        (newOrb.dx - _localOrb.dx).abs() < 0.01 &&
        (newOrb.dy - _localOrb.dy).abs() < 0.01) return;
    setState(() { _localOrb = newOrb; _proximity = prox; });
  }

  @override
  void dispose() {
    _shineTimer?.cancel();
    _periodicShine.removeStatusListener(_onShineStatus);
    widget.repaint?.removeListener(_onFrame);
    if (widget.hasShimmer) widget.progress.removeListener(_onProgressChange);
    _press.dispose();
    _sweep.dispose();
    _badgeCtrl.dispose();
    _periodicShine.dispose();
    super.dispose();
  }

  Widget _orb(Widget child) {
    final e = widget.engine; final r = widget.repaint;
    if (e == null || r == null) return child;
    return OrbAwareText(engine: e, repaint: r, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.progress,
      builder: (_, child) {
        final t    = widget.progress.value;
        final blur = (1.0 - t) * 12.0;
        final slideX = widget.slideFromRight ? (1.0 - t) * 40.0 : 0.0;
        final slideY = widget.slideFromRight ? 0.0 : (1.0 - t) * 16.0;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(slideX, slideY),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                  sigmaX: blur, sigmaY: blur, tileMode: TileMode.decal),
              child: child,
            ),
          ),
        );
      },
      child: Listener(
        onPointerDown:   (_) { _press.forward();  widget.fluidCtrl.lockOrb(); },
        onPointerUp:     (_) { _press.reverse();  widget.fluidCtrl.unlockOrb(); },
        onPointerCancel: (_) { _press.reverse();  widget.fluidCtrl.unlockOrb(); },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _press,
            builder: (_, child) =>
                Transform.scale(scale: 1.0 - _press.value * 0.03, child: child),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  key: _key,
                  child: widget.isFranko
                      ? AnimatedBuilder(
                          animation: Listenable.merge([_sweepAnim, _periodicShineAnim]),
                          builder: (_, child) {
                            // Use whichever shimmer value is larger at any moment
                            final shimmerVal = _sweepAnim.value > _periodicShineAnim.value
                                ? _sweepAnim.value
                                : _periodicShineAnim.value;
                            return _LiquidGlassCard(
                              selected: widget.selected,
                              shimmer: shimmerVal,
                              proximity: _proximity,
                              orbOffset: _localOrb,
                              child: child!,
                            );
                          },
                          child: _buildContent(),
                        )
                      : widget.hasShimmer
                          ? AnimatedBuilder(
                              animation: _sweepAnim,
                              builder: (_, child) => _LiquidGlassCard(
                                selected: widget.selected,
                                shimmer: _sweepAnim.value,
                                proximity: _proximity,
                                orbOffset: _localOrb,
                                child: child!,
                              ),
                              child: _buildContent(),
                            )
                          : _LiquidGlassCard(
                              selected: widget.selected,
                              shimmer: 0,
                              proximity: _proximity,
                              orbOffset: _localOrb,
                              child: _buildContent(),
                            ),
                ),
                if (widget.isFranko)
                  Positioned(
                    top: -14,
                    right: 8,
                    child: AnimatedBuilder(
                      animation: _badgeScale,
                      builder: (_, __) => Transform.scale(
                        scale: _badgeScale.value,
                        alignment: Alignment.topRight,
                        child: const _FlameBadge(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() => _CardContent(
    label: widget.label, sublabel: widget.sublabel, icon: widget.icon,
    selected: widget.selected, isArabic: widget.isArabic,
    isFranko: widget.isFranko, proximity: _proximity, orbWidget: _orb,
  );
}

// ── Flame badge ───────────────────────────────────────────────────────────────
class _FlameBadge extends StatelessWidget {
  const _FlameBadge();
  @override
  Widget build(BuildContext context) {
    return const Text('🔥', style: TextStyle(fontSize: 22, height: 1.0));
  }
}

// ── Glass card ────────────────────────────────────────────────────────────────
class _LiquidGlassCard extends StatelessWidget {
  final bool selected; final double shimmer, proximity;
  final Offset orbOffset; final Widget child;
  const _LiquidGlassCard({required this.selected, required this.shimmer,
      required this.child, this.proximity = 0.0,
      this.orbOffset = const Offset(0.5, 0.5)});

  @override
  Widget build(BuildContext context) {
    final orbTint    = Color.fromARGB((proximity * 38).round().clamp(0, 255), 168, 85, 247);
    final borderAlpha = selected
        ? (20 + proximity * 140).round().clamp(0, 255)
        : (8  + proximity * 160).round().clamp(0, 255);
    return SizedBox(
      height: 84,
      child: Stack(fit: StackFit.expand, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: selected
                  ? Color.lerp(const Color(0x33a855f7), const Color(0x50a855f7), proximity)
                  : Color.lerp(const Color(0x22000000), orbTint.withOpacity(0.18), proximity),
            ),
          ),
        ),
        CustomPaint(painter: _LiquidGlassPainter(
            selected: selected, shimmer: shimmer, proximity: proximity,
            orbOffset: orbOffset, borderAlpha: borderAlpha)),
        child,
      ]),
    );
  }
}

class _LiquidGlassPainter extends CustomPainter {
  final bool selected; final double shimmer, proximity;
  final Offset orbOffset; final int borderAlpha;
  const _LiquidGlassPainter({required this.selected, required this.shimmer,
      required this.proximity, required this.orbOffset, required this.borderAlpha});

  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    if (shimmer > 0.0 && shimmer < 1.0) {
      final cx = size.width * (-0.3 + shimmer * 1.6);
      canvas.save(); canvas.clipRRect(rrect);
      canvas.drawRRect(rrect, Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: const [
          Color(0x00FFFFFF), Color(0x00FFFFFF),
          Color(0x28FFFFFF), Color(0x40FFFFFF),
          Color(0x28FFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.28, 0.42, 0.50, 0.58, 0.72, 1.0],
      ).createShader(Rect.fromCenter(
          center: Offset(cx, size.height / 2), width: 200, height: size.height)));
      canvas.restore();
    }

    if (proximity > 0.05) {
      final ox = orbOffset.dx * size.width;
      final oy = orbOffset.dy * size.height;
      final glowR = size.width * 0.55;
      canvas.save(); canvas.clipRRect(rrect);
      canvas.drawCircle(Offset(ox, oy), glowR, Paint()..shader = RadialGradient(
        colors: [
          Color.fromARGB((proximity * 40).round().clamp(0, 255), 200, 100, 255),
          Color.fromARGB((proximity * 18).round().clamp(0, 255), 168, 85,  247),
          const Color(0x00000000),
        ], stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(ox, oy), radius: glowR)));
      canvas.restore();
    }

    final dirX = (orbOffset.dx - 0.5) * 2.0;
    final dirY = (orbOffset.dy - 0.5) * 2.0;
    final gB = Alignment(dirX.clamp(-1.0, 1.0), dirY.clamp(-1.0, 1.0));
    final gE = Alignment(-dirX.clamp(-1.0, 1.0), -dirY.clamp(-1.0, 1.0));
    final dimA = (borderAlpha * 0.12).round().clamp(0, 255);
    canvas.drawRRect(rrect, Paint()
      ..shader = LinearGradient(begin: gB, end: gE,
          colors: selected
              ? [Color.fromARGB(borderAlpha, 168, 85, 247), Color.fromARGB(dimA, 168, 85, 247)]
              : [Color.fromARGB(borderAlpha, 220, 200, 255), Color.fromARGB(dimA, 220, 200, 255)])
          .createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = proximity > 0.15 ? 1.1 : 0.7);

    if (proximity > 0.05) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
            const Radius.circular(17)),
        Paint()
          ..color = Color.fromARGB((proximity * 22).round().clamp(0, 255), 255, 255, 255)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
    }
  }

  @override
  bool shouldRepaint(_LiquidGlassPainter o) =>
      o.selected != selected || o.shimmer != shimmer ||
      o.proximity != proximity || o.orbOffset != orbOffset ||
      o.borderAlpha != borderAlpha;
}

// ── Card content ──────────────────────────────────────────────────────────────
class _CardContent extends StatelessWidget {
  final String label, sublabel; final Widget icon;
  final bool selected, isArabic, isFranko; final double proximity;
  final Widget Function(Widget) orbWidget;

  const _CardContent({required this.label, required this.sublabel,
      required this.icon, required this.selected, required this.orbWidget,
      required this.proximity, this.isArabic = false, this.isFranko = false});

  @override
  Widget build(BuildContext context) {
    final t = ((proximity - 0.55) / 0.35).clamp(0.0, 1.0);
    final labelColor    = Color.lerp(AppTheme.textPrimary, const Color(0xFF1a0a2e), t)!;
    final sublabelColor = Color.lerp(AppTheme.textHint,    const Color(0x99200040), t)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(children: [
        SizedBox(width: 30, height: 30,
          child: isFranko
              ? ColorFiltered(
                  colorFilter: ColorFilter.matrix([
                    1.0-t*0.85, 0, 0, 0, 0,
                    0, 1.0-t*0.85, 0, 0, 0,
                    0, 0, 1.0-t*0.85, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: icon,
                )
              : icon,
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            orbWidget(Text(label, style: AppTheme.cardLabelStyle.copyWith(
              color: labelColor,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: isArabic ? 0.5 : 2.4,
            ))),
            const SizedBox(height: 3),
            orbWidget(Text(sublabel, style: AppTheme.cardSublabelStyle.copyWith(
              color: sublabelColor,
              letterSpacing: isArabic ? 0.3 : 0.6,
            ))),
          ],
        ),
        const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          width:  selected ? 28 : 0,
          height: selected ? 28 : 0,
          child: selected
              ? Container(
                  decoration: BoxDecoration(
                    color: AppTheme.midPurple.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.midPurple.withOpacity(0.5), width: 0.8),
                  ),
                  child: const Center(
                    child: Icon(Icons.check_rounded,
                        color: AppTheme.midPurple, size: 15),
                  ),
                )
              : null,
        ),
      ]),
    );
  }
}

// ── Icons ─────────────────────────────────────────────────────────────────────
class _EmojiIcon extends StatelessWidget {
  final String emoji;
  const _EmojiIcon(this.emoji);
  @override
  Widget build(BuildContext context) =>
      Text(emoji, style: const TextStyle(fontSize: 24, height: 1.0));
}

class _FrankoIcon extends StatelessWidget {
  const _FrankoIcon();
  @override Widget build(BuildContext context) =>
      SizedBox(width:26, height:26, child:CustomPaint(painter:_FrankoGlyphPainter()));
}
class _FrankoGlyphPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final cx=s.width/2; final cy=s.height/2;
    canvas.drawCircle(Offset(cx,cy),s.width/2-1,
        Paint()..color=const Color(0x33FFFFFF)..style=PaintingStyle.stroke..strokeWidth=0.8);
    final p=Paint()..color=const Color(0x99FFFFFF)..style=PaintingStyle.stroke
      ..strokeWidth=1.5..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round;
    final path=Path();
    path.moveTo(cx-4.5,cy-6.0);
    path.quadraticBezierTo(cx+6.0,cy-6.0,cx+5.0,cy-0.5);
    path.quadraticBezierTo(cx+6.0,cy+0.5,cx+0.5,cy+0.5);
    path.quadraticBezierTo(cx+7.0,cy+0.5,cx+5.5,cy+5.5);
    path.quadraticBezierTo(cx+1.5,cy+9.0,cx-3.5,cy+6.5);
    path.quadraticBezierTo(cx-7.0,cy+3.5,cx-5.0,cy+0.5);
    canvas.drawPath(path,p);
  }
  @override bool shouldRepaint(_) => false;
}

class _ArabicIcon extends StatelessWidget {
  const _ArabicIcon();
  @override Widget build(BuildContext context) =>
      SizedBox(width:30, height:26, child:CustomPaint(painter:_SimplePyramidPainter()));
}
class _SimplePyramidPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final w=s.width; final h=s.height;
    canvas.drawLine(Offset(0,h*0.85),Offset(w,h*0.85),
        Paint()..color=const Color(0x55FFD700)..strokeWidth=0.8);
    final left=Path()..moveTo(w*0.02,h*0.85)..lineTo(w*0.22,h*0.52)..lineTo(w*0.42,h*0.85)..close();
    canvas.drawPath(left,Paint()..shader=LinearGradient(
        begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:const[Color(0xFFD4A017),Color(0xFF8B6914)])
        .createShader(Rect.fromLTWH(w*0.02,h*0.52,w*0.40,h*0.33)));
    canvas.drawPath(left,Paint()..color=const Color(0xAAFFD700)..style=PaintingStyle.stroke..strokeWidth=0.7);
    final cL=Path()..moveTo(w*0.20,h*0.85)..lineTo(w*0.50,h*0.06)..lineTo(w*0.50,h*0.85)..close();
    canvas.drawPath(cL,Paint()..shader=LinearGradient(
        begin:Alignment.topLeft,end:Alignment.bottomRight,
        colors:const[Color(0xFFFFD700),Color(0xFFB8860B)])
        .createShader(Rect.fromLTWH(w*0.20,h*0.06,w*0.60,h*0.79)));
    final cS=Path()..moveTo(w*0.50,h*0.06)..lineTo(w*0.80,h*0.85)..lineTo(w*0.50,h*0.85)..close();
    canvas.drawPath(cS,Paint()..shader=LinearGradient(
        begin:Alignment.topRight,end:Alignment.bottomLeft,
        colors:const[Color(0xFF8B6914),Color(0xFF5C440A)])
        .createShader(Rect.fromLTWH(w*0.50,h*0.06,w*0.30,h*0.79)));
    final outline=Path()..moveTo(w*0.20,h*0.85)..lineTo(w*0.50,h*0.06)..lineTo(w*0.80,h*0.85)..close();
    canvas.drawPath(outline,Paint()..color=const Color(0xCCFFD700)
        ..style=PaintingStyle.stroke..strokeWidth=1.0..strokeJoin=StrokeJoin.miter);
    canvas.drawCircle(Offset(w*0.50,h*0.06),2.0,Paint()
        ..color=const Color(0xAAFFFFAA)
        ..maskFilter=const MaskFilter.blur(BlurStyle.normal,2.0));
    canvas.drawCircle(Offset(w*0.50,h*0.06),1.0,Paint()..color=Colors.white);
  }
  @override bool shouldRepaint(_) => false;
}

PageRoute _smoothRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_,__,___) => page,
  transitionDuration: const Duration(milliseconds: 500),
  transitionsBuilder: (_,anim,__,child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child));