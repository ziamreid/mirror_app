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

  late Animation<double> _card0;
  late Animation<double> _card1;
  late Animation<double> _card2;
  late Animation<double> _headerAnim;
  late Animation<double> _subtext;

  bool _showCards = false;
  AppLanguage? _selected;

  @override
  void initState() {
    super.initState();
    _bloomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _cardsCtrl = AnimationController(
      vsync: this,
      // FIX #4 — longer total duration so cards have time to glide in
      // smoothly rather than cutting hard over the orb
      duration: const Duration(milliseconds: 1600),
    );
    _headerAnim = CurvedAnimation(
      parent: _cardsCtrl,
      curve: const Interval(0.00, 0.40, curve: Curves.easeOut),
    );
    // FIX #4 — use easeOutCubic for each card so they decelerate
    // smoothly as they settle into position over the orb
    _card0 = CurvedAnimation(
      parent: _cardsCtrl,
      curve: const Interval(0.12, 0.55, curve: Curves.easeOutCubic),
    );
    _card1 = CurvedAnimation(
      parent: _cardsCtrl,
      curve: const Interval(0.26, 0.70, curve: Curves.easeOutCubic),
    );
    _card2 = CurvedAnimation(
      parent: _cardsCtrl,
      curve: const Interval(0.40, 0.85, curve: Curves.easeOutCubic),
    );
    _subtext = CurvedAnimation(
      parent: _cardsCtrl,
      curve: const Interval(0.72, 1.00, curve: Curves.easeOut),
    );
    _runSequence();
  }

  Future<void> _runSequence() async {
    await _bloomCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    _fluidCtrl.setSpeed(1.5);
    setState(() => _showCards = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await _cardsCtrl.forward();
    if (!mounted) return;
    _fluidCtrl.setSpeed(1.0);
  }

  @override
  void dispose() {
    _bloomCtrl.dispose();
    _cardsCtrl.dispose();
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

  FluidEngine? get _engine => _fluidCtrl.engine;
  ValueNotifier<int>? get _repaint => _fluidCtrl.repaint;

  @override
  Widget build(BuildContext context) {
    return FluidBackground(
      controller: _fluidCtrl,
      child: SafeArea(
        child: Padding(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // FIX #1 — use headlineStyle (w600) to match app font
                          Text(
                            'Choose your language',
                            style: AppTheme.headlineStyle.copyWith(fontSize: 22),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'this shapes how Eye speaks to you',
                            style: AppTheme.labelStyle.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              letterSpacing: 0.2,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _MaterialCard(
                  progress:  _card0,
                  label:     'ENGLISH',
                  sublabel:  'speak to me clearly',
                  icon:      const _USFlagIcon(),
                  selected:  _selected == AppLanguage.english,
                  onTap:     () => _onSelect(AppLanguage.english),
                  hasShimmer: false,
                  engine:    _engine,
                  repaint:   _repaint,
                ),
                const SizedBox(height: 12),
                _MaterialCard(
                  progress:  _card1,
                  label:     'FRANKO',
                  sublabel:  'kalam 3adi zayak',
                  icon:      const _FrankoIcon(),
                  selected:  _selected == AppLanguage.franko,
                  onTap:     () => _onSelect(AppLanguage.franko),
                  hasShimmer: true,
                  engine:    _engine,
                  repaint:   _repaint,
                ),
                const SizedBox(height: 12),
                _MaterialCard(
                  progress:  _card2,
                  label:     'عربي',
                  sublabel:  'بالكلام الصريح',
                  icon:      const _ArabicIcon(),
                  selected:  _selected == AppLanguage.arabic,
                  onTap:     () => _onSelect(AppLanguage.arabic),
                  hasShimmer: false,
                  isArabic:  true,
                  engine:    _engine,
                  repaint:   _repaint,
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _subtext,
                  builder: (_, __) => Opacity(
                    opacity: _subtext.value,
                    child: Center(
                      child: Text(
                        'you can change this later',
                        style: AppTheme.labelStyle.copyWith(
                          color: AppTheme.textHint,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MaterialCard extends StatefulWidget {
  final Animation<double> progress;
  final String            label;
  final String            sublabel;
  final Widget            icon;
  final bool              selected;
  final bool              isArabic;
  final bool              hasShimmer;
  final VoidCallback      onTap;
  final FluidEngine?      engine;
  final ValueNotifier<int>? repaint;

  const _MaterialCard({
    required this.progress,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.hasShimmer,
    this.engine,
    this.repaint,
    this.isArabic = false,
  });

  @override
  State<_MaterialCard> createState() => _MaterialCardState();
}

class _MaterialCardState extends State<_MaterialCard>
    with TickerProviderStateMixin {
  late AnimationController _press;
  late AnimationController _sweep;
  late Animation<double>   _sweepAnim;
  bool _sweptOnce = false;

  final GlobalKey _key       = GlobalKey();
  Offset          _localOrb  = const Offset(0.5, 0.5);
  double          _proximity = 0.0;
  int             _frameSkip = 0;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0,
      upperBound: 1,
    );
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _sweepAnim = CurvedAnimation(parent: _sweep, curve: Curves.easeInOut);
    if (widget.hasShimmer) {
      widget.progress.addListener(_onProgressChange);
    }
    widget.repaint?.addListener(_onFrame);
  }

  void _onProgressChange() {
    if (!_sweptOnce && widget.progress.value > 0.5) {
      _sweptOnce = true;
      _sweep.forward();
    }
  }

  void _onFrame() {
    _frameSkip++;
    if (_frameSkip % 3 != 0) return;
    if (!mounted) return;

    final engine = widget.engine;
    if (engine == null) return;

    final ctx = _key.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final screenSize = MediaQuery.of(context).size;
    final orbSx = engine.orbX * screenSize.width;
    final orbSy = engine.orbY * screenSize.height;
    final pos   = box.localToGlobal(Offset.zero);
    final sz    = box.size;

    final lx  = orbSx - pos.dx;
    final ly  = orbSy - pos.dy;
    final cdx = lx - sz.width  / 2;
    final cdy = ly - sz.height / 2;

    final dist    = sqrt(cdx * cdx + cdy * cdy);
    final maxDist = sz.width * 1.2;
    final prox    = (1.0 - dist / maxDist).clamp(0.0, 1.0);

    final newOrb = Offset(lx / sz.width, ly / sz.height);
    if ((prox - _proximity).abs() < 0.01 &&
        (newOrb.dx - _localOrb.dx).abs() < 0.01 &&
        (newOrb.dy - _localOrb.dy).abs() < 0.01) return;

    setState(() {
      _localOrb  = newOrb;
      _proximity = prox;
    });
  }

  @override
  void dispose() {
    widget.repaint?.removeListener(_onFrame);
    if (widget.hasShimmer) widget.progress.removeListener(_onProgressChange);
    _press.dispose();
    _sweep.dispose();
    super.dispose();
  }

  Widget _orb(Widget child) {
    final e = widget.engine;
    final r = widget.repaint;
    if (e == null || r == null) return child;
    return OrbAwareText(engine: e, repaint: r, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.progress,
      builder: (_, child) {
        final t     = widget.progress.value;
        // FIX #4 — use a blur-only entrance (no scale) so the card
        // materialises cleanly through the orb rather than scaling
        // over it. Combine with a gentle vertical slide for elegance.
        final blur  = (1.0 - t) * 12.0;
        final slide = (1.0 - t) * 16.0;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, slide),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: TileMode.decal,
              ),
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTapDown:   (_) => _press.forward(),
        onTapUp:     (_) { _press.reverse(); widget.onTap(); },
        onTapCancel: ()  => _press.reverse(),
        child: AnimatedBuilder(
          animation: _press,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - _press.value * 0.03, child: child),
          child: SizedBox(
            key: _key,
            child: widget.hasShimmer
                ? AnimatedBuilder(
                    animation: _sweepAnim,
                    builder: (_, child) => _LiquidGlassCard(
                      selected:  widget.selected,
                      shimmer:   _sweepAnim.value,
                      proximity: _proximity,
                      orbOffset: _localOrb,
                      child:     child!,
                    ),
                    child: _buildContent(),
                  )
                : _LiquidGlassCard(
                    selected:  widget.selected,
                    shimmer:   0,
                    proximity: _proximity,
                    orbOffset: _localOrb,
                    child:     _buildContent(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() => _CardContent(
        label:     widget.label,
        sublabel:  widget.sublabel,
        icon:      widget.icon,
        selected:  widget.selected,
        isArabic:  widget.isArabic,
        orbWidget: _orb,
      );
}

// ── The glass card ────────────────────────────────────────────────────────────
class _LiquidGlassCard extends StatelessWidget {
  final bool   selected;
  final double shimmer;
  final double proximity;
  final Offset orbOffset;
  final Widget child;

  const _LiquidGlassCard({
    required this.selected,
    required this.shimmer,
    required this.child,
    this.proximity = 0.0,
    this.orbOffset = const Offset(0.5, 0.5),
  });

  @override
  Widget build(BuildContext context) {
    // FIX #3 — base fill starts near-invisible, reacts to proximity
    final orbTint = Color.fromARGB(
      (proximity * 38).round().clamp(0, 255),
      168, 85, 247,
    );

    // FIX #3 — border alpha starts near-zero (alpha 8) so there's
    // no visible white ring when the orb is far away
    final borderAlpha = selected
        ? (20 + proximity * 140).round().clamp(0, 255)
        : (8  + proximity * 160).round().clamp(0, 255);

    return SizedBox(
      height: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: selected
                    ? Color.lerp(
                        const Color(0x1Aa855f7),
                        const Color(0x38a855f7),
                        proximity,
                      )
                    : Color.lerp(
                        const Color(0x0AFFFFFF),   // near-zero at distance
                        orbTint,
                        proximity,
                      ),
              ),
            ),
          ),
          CustomPaint(
            painter: _LiquidGlassPainter(
              selected:    selected,
              shimmer:     shimmer,
              proximity:   proximity,
              orbOffset:   orbOffset,
              borderAlpha: borderAlpha,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────
class _LiquidGlassPainter extends CustomPainter {
  final bool   selected;
  final double shimmer;
  final double proximity;
  final Offset orbOffset;
  final int    borderAlpha;

  const _LiquidGlassPainter({
    required this.selected,
    required this.shimmer,
    required this.proximity,
    required this.orbOffset,
    required this.borderAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    // ── Shimmer sweep (Franko card only) ──────────────────────────────────
    if (shimmer > 0.0 && shimmer < 1.0) {
      final cx = size.width * (-0.3 + shimmer * 1.6);
      canvas.save();
      canvas.clipRRect(rrect);
      final shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0x00FFFFFF), Color(0x00FFFFFF),
          Color(0x20FFFFFF), Color(0x30FFFFFF),
          Color(0x20FFFFFF), Color(0x00FFFFFF),
          Color(0x00FFFFFF),
        ],
        stops: const [0.0, 0.28, 0.42, 0.50, 0.58, 0.72, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, size.height / 2),
        width: 180,
        height: size.height,
      ));
      canvas.drawRRect(rrect, Paint()..shader = shader);
      canvas.restore();
    }

    // ── Orb specular: radial highlight where orb sits behind card ─────────
    if (proximity > 0.05) {
      final ox = orbOffset.dx * size.width;
      final oy = orbOffset.dy * size.height;
      final glowR = size.width * 0.55;
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawCircle(
        Offset(ox, oy),
        glowR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromARGB((proximity * 40).round().clamp(0, 255), 200, 100, 255),
              Color.fromARGB((proximity * 18).round().clamp(0, 255), 168, 85,  247),
              const Color(0x00000000),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(ox, oy), radius: glowR)),
      );
      canvas.restore();
    }

    // ── FIX #2 — directional border: bright on orb-side, dim on far side ──
    // Gradient direction tracks the orb position dynamically
    final dirX = (orbOffset.dx - 0.5) * 2.0;
    final dirY = (orbOffset.dy - 0.5) * 2.0;
    final gBegin = Alignment(dirX.clamp(-1.0, 1.0), dirY.clamp(-1.0, 1.0));
    final gEnd   = Alignment(-dirX.clamp(-1.0, 1.0), -dirY.clamp(-1.0, 1.0));

    final dimAlpha = (borderAlpha * 0.12).round().clamp(0, 255);

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: gBegin,
          end:   gEnd,
          colors: selected
              ? [
                  Color.fromARGB(borderAlpha, 168, 85,  247),
                  Color.fromARGB(dimAlpha,    168, 85,  247),
                ]
              : [
                  Color.fromARGB(borderAlpha, 220, 200, 255),
                  Color.fromARGB(dimAlpha,    220, 200, 255),
                ],
        ).createShader(rect)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = proximity > 0.15 ? 1.1 : 0.7,
    );

    // ── Inner inset border ────────────────────────────────────────────────
    if (proximity > 0.05) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          const Radius.circular(17),
        ),
        Paint()
          ..color       = Color.fromARGB(
              (proximity * 22).round().clamp(0, 255), 255, 255, 255)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(_LiquidGlassPainter old) =>
      old.selected    != selected    ||
      old.shimmer     != shimmer     ||
      old.proximity   != proximity   ||
      old.orbOffset   != orbOffset   ||
      old.borderAlpha != borderAlpha;
}

// ── Card content ──────────────────────────────────────────────────────────────
class _CardContent extends StatelessWidget {
  final String label;
  final String sublabel;
  final Widget icon;
  final bool   selected;
  final bool   isArabic;
  final Widget Function(Widget) orbWidget;

  const _CardContent({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.selected,
    required this.orbWidget,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          SizedBox(width: 28, height: 28, child: icon),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIX #1 — use cardLabelStyle (w600) to match heading font
              orbWidget(Text(
                label,
                style: AppTheme.cardLabelStyle.copyWith(
                  fontWeight:    selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: isArabic ? 0.5 : 2.4,
                ),
              )),
              const SizedBox(height: 3),
              orbWidget(Text(
                sublabel,
                style: AppTheme.cardSublabelStyle.copyWith(
                  letterSpacing: isArabic ? 0.3 : 0.6,
                ),
              )),
            ],
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity:  selected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width:  6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppTheme.midPurple,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icons (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _USFlagIcon extends StatelessWidget {
  const _USFlagIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 30, height: 20,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: CustomPaint(painter: _USFlagPainter()),
        ),
      );
}

class _USFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Rect.fromLTWH(0, 0, s.width, s.height),
        Paint()..color = const Color(0xFFB22234));
    final stripeH = s.height / 13;
    final white = Paint()..color = Colors.white;
    for (int i = 1; i < 13; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * stripeH, s.width, stripeH), white);
    }
    final cantonW = s.width * 0.40;
    final cantonH = stripeH * 7;
    canvas.drawRect(Rect.fromLTWH(0, 0, cantonW, cantonH),
        Paint()..color = const Color(0xFF3C3B6E));
    final star = Paint()..color = Colors.white;
    const cols = 6; const rows = 5;
    final sx = cantonW / (cols + 0.5);
    final sy = cantonH / (rows + 0.5);
    for (int r = 0; r < rows; r++)
      for (int c = 0; c < cols; c++)
        canvas.drawCircle(Offset((c + 0.75) * sx, (r + 0.75) * sy), 0.9, star);
  }
  @override bool shouldRepaint(_) => false;
}

class _FrankoIcon extends StatelessWidget {
  const _FrankoIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 26, height: 26,
      child: CustomPaint(painter: _FrankoGlyphPainter()));
}

class _FrankoGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    canvas.drawCircle(Offset(cx, cy), s.width / 2 - 1,
        Paint()..color = const Color(0x33FFFFFF)
               ..style = PaintingStyle.stroke ..strokeWidth = 0.8);
    final p = Paint()..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(cx - 4.5, cy - 6.0);
    path.quadraticBezierTo(cx + 6.0, cy - 6.0, cx + 5.0, cy - 0.5);
    path.quadraticBezierTo(cx + 6.0, cy + 0.5, cx + 0.5, cy + 0.5);
    path.quadraticBezierTo(cx + 7.0, cy + 0.5, cx + 5.5, cy + 5.5);
    path.quadraticBezierTo(cx + 1.5, cy + 9.0, cx - 3.5, cy + 6.5);
    path.quadraticBezierTo(cx - 7.0, cy + 3.5, cx - 5.0, cy + 0.5);
    canvas.drawPath(path, p);
  }
  @override bool shouldRepaint(_) => false;
}

class _ArabicIcon extends StatelessWidget {
  const _ArabicIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 30, height: 26,
      child: CustomPaint(painter: _SimplePyramidPainter()));
}

class _SimplePyramidPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    canvas.drawLine(Offset(0, h * 0.85), Offset(w, h * 0.85),
        Paint()..color = const Color(0x55FFD700)..strokeWidth = 0.8);
    final left = Path()
      ..moveTo(w * 0.02, h * 0.85)..lineTo(w * 0.22, h * 0.52)
      ..lineTo(w * 0.42, h * 0.85)..close();
    canvas.drawPath(left, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: const [Color(0xFFD4A017), Color(0xFF8B6914)])
          .createShader(Rect.fromLTWH(w*0.02, h*0.52, w*0.40, h*0.33)));
    canvas.drawPath(left, Paint()..color = const Color(0xAAFFD700)
      ..style = PaintingStyle.stroke..strokeWidth = 0.7);
    final cL = Path()..moveTo(w*0.20,h*0.85)..lineTo(w*0.50,h*0.06)..lineTo(w*0.50,h*0.85)..close();
    canvas.drawPath(cL, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: const [Color(0xFFFFD700), Color(0xFFB8860B)])
        .createShader(Rect.fromLTWH(w*0.20,h*0.06,w*0.60,h*0.79)));
    final cS = Path()..moveTo(w*0.50,h*0.06)..lineTo(w*0.80,h*0.85)..lineTo(w*0.50,h*0.85)..close();
    canvas.drawPath(cS, Paint()..shader = LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
        colors: const [Color(0xFF8B6914), Color(0xFF5C440A)])
        .createShader(Rect.fromLTWH(w*0.50,h*0.06,w*0.30,h*0.79)));
    final outline = Path()..moveTo(w*0.20,h*0.85)..lineTo(w*0.50,h*0.06)..lineTo(w*0.80,h*0.85)..close();
    canvas.drawPath(outline, Paint()..color = const Color(0xCCFFD700)
      ..style = PaintingStyle.stroke..strokeWidth = 1.0..strokeJoin = StrokeJoin.miter);
    canvas.drawCircle(Offset(w*0.50,h*0.06), 2.0,
        Paint()..color = const Color(0xAAFFFFAA)
               ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0));
    canvas.drawCircle(Offset(w*0.50,h*0.06), 1.0, Paint()..color = Colors.white);
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
PageRoute _smoothRoute(Widget page) => PageRouteBuilder(
      pageBuilder:        (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );