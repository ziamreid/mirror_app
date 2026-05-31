import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../fluid_painter.dart';
import '../models/app_theme.dart';
import '../models/onboarding_data.dart';
import '../widgets/fluid_background.dart';
import '../widgets/orb_aware_text.dart';
import '../widgets/liquid_glass_card.dart';
import 'onboarding_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen>
    with SingleTickerProviderStateMixin {
  AppLanguage?             _selected;
  late AnimationController _introCtrl;
  late Animation<double>   _introBlur;
  late Animation<double>   _introOpacity;
  final FluidController    _fluidCtrl = FluidController();

  final GlobalKey _headerKey  = GlobalKey();
  double          _headerProx = 0.0;
  int             _headerSkip = 0;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _introBlur    = Tween<double>(begin: 20, end: 0)
        .animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut));
    _introOpacity = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fluidCtrl.repaint?.addListener(_onFrame);
    });
  }

  @override
  void dispose() {
    _fluidCtrl.repaint?.removeListener(_onFrame);
    _introCtrl.dispose();
    super.dispose();
  }

  void _onFrame() {
    _headerSkip++;
    if (_headerSkip % 3 != 0) return;
    if (!mounted) return;
    final engine = _fluidCtrl.engine;
    if (engine == null) return;
    final ctx = _headerKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final screenSize = MediaQuery.of(context).size;
    final orbSx = engine.orbX * screenSize.width;
    final orbSy = engine.orbY * screenSize.height;
    final pos   = box.localToGlobal(Offset.zero);
    final sz    = box.size;
    final cdx   = orbSx - (pos.dx + sz.width  / 2);
    final cdy   = orbSy - (pos.dy + sz.height / 2);
    final dist  = sqrt(cdx * cdx + cdy * cdy);
    final prox  = (1.0 - dist / (sz.width * 0.9)).clamp(0.0, 1.0);
    if ((prox - _headerProx).abs() < 0.01) return;
    setState(() => _headerProx = prox);
  }

  void _onSelect(AppLanguage lang) {
    if (_selected != null) return;
    setState(() => _selected = lang);
    _fluidCtrl.setSpeed(1.6);
    _fluidCtrl.setMood(0.5);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      _fluidCtrl.setSpeed(1.0);
      // ── Pass current orb position so OnboardingScreen starts seamlessly ──
      final engine = _fluidCtrl.engine;
      final orbX   = engine?.orbX ?? 0.5;
      final orbY   = engine?.orbY ?? 0.5;
      Navigator.of(context).push(
        _blurDissolveRoute(OnboardingScreen(
          language:    lang,
          initialOrbX: orbX,
          initialOrbY: orbY,
        )),
      );
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
    final t           = ((_headerProx - 0.45) / 0.40).clamp(0.0, 1.0);
    final headerColor = Color.lerp(AppTheme.textPrimary, const Color(0xFF1a0a2e), t)!;
    final hintColor   = Color.lerp(AppTheme.textHint,   const Color(0x991a0a2e), t)!;

    final body = FluidBackground(
      controller: _fluidCtrl,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),
              _maybeOrb(Text('EYE',
                  style: AppTheme.appNameStyle.copyWith(color: headerColor))),
              const SizedBox(height: 6),
              SizedBox(
                key: _headerKey,
                child: _maybeOrb(Text(
                  'CHOOSE YOUR LANGUAGE',
                  style: AppTheme.labelStyle.copyWith(
                      color: hintColor, letterSpacing: 2.2),
                )),
              ),
              const Spacer(),
              Column(
                children: [
                  _LangCard(
                    label:         'ENGLISH',
                    sublabel:      'speak to me clearly',
                    icon:          const _EmojiIcon('🗽'),
                    selected:      _selected == AppLanguage.english,
                    onTap:         () => _onSelect(AppLanguage.english),
                    fluidCtrl:     _fluidCtrl,
                    entranceDelay: 0,
                  ),
                  const SizedBox(height: 12),
                  _LangCard(
                    label:         'FRANKO',
                    sublabel:      'kalam 3adi zayak',
                    icon:          const _FrankoIcon(),
                    selected:      _selected == AppLanguage.franko,
                    onTap:         () => _onSelect(AppLanguage.franko),
                    fluidCtrl:     _fluidCtrl,
                    entranceDelay: 120,
                    isFranko:      true,
                  ),
                  const SizedBox(height: 12),
                  _LangCard(
                    label:         'مصري',
                    sublabel:      'بالكلام الصريح',
                    icon:          const _ArabicIcon(),
                    selected:      _selected == AppLanguage.arabic,
                    onTap:         () => _onSelect(AppLanguage.arabic),
                    isArabic:      true,
                    fluidCtrl:     _fluidCtrl,
                    entranceDelay: 240,
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: _maybeOrb(Text(
                  'you can change this later',
                  style: AppTheme.labelStyle.copyWith(
                      color: AppTheme.textHint, letterSpacing: 0.8),
                )),
              ),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _introCtrl,
      builder: (_, child) {
        if (_introCtrl.isCompleted) return child!;
        final blurV = _introBlur.value;
        return blurV > 0.3
            ? ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: blurV, sigmaY: blurV),
                child: Opacity(opacity: _introOpacity.value, child: child),
              )
            : child!;
      },
      child: body,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _LangCard extends StatefulWidget {
  final String          label;
  final String          sublabel;
  final Widget          icon;
  final bool            selected;
  final bool            isArabic;
  final bool            isFranko;
  final VoidCallback    onTap;
  final FluidController fluidCtrl;
  final int             entranceDelay;

  const _LangCard({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.fluidCtrl,
    required this.entranceDelay,
    this.isArabic = false,
    this.isFranko = false,
  });

  @override
  State<_LangCard> createState() => _LangCardState();
}

class _LangCardState extends State<_LangCard> with TickerProviderStateMixin {
  late AnimationController _press;
  late AnimationController _entrance;
  late Animation<double>   _entranceFade;
  late Animation<double>   _entranceSlide;

  final GlobalKey _key = GlobalKey();
  Offset _localOrb  = const Offset(0.5, 0.5);
  double _proximity = 0.0;
  int    _frameSkip = 0;

  // Wall-clock shimmer for FRANKO — fixed timing
  static const double _shineCycleMs = 8000.0;
  static const double _shineHalfMs  = 900.0;
  double    _shineElapsed  = 0.0;
  DateTime? _lastFrameTime;
  bool      _shineActive   = false; // true after first delay completes
  double    _shineValue    = 0.0;

  @override
  void initState() {
    super.initState();

    _press = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 110),
        lowerBound: 0, upperBound: 1);

    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entranceFade  = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _entranceSlide = Tween<double>(begin: 18.0, end: 0.0).animate(
        CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.entranceDelay), () {
      if (mounted) _entrance.forward();
    });

    if (widget.isFranko) {
      // First shine: entrance delay + animation (700ms) + 2s pause
      final firstDelay = widget.entranceDelay + 700 + 2000;
      Future.delayed(Duration(milliseconds: firstDelay), () {
        if (!mounted) return;
        setState(() {
          _shineActive   = true;
          _lastFrameTime = DateTime.now();
          _shineElapsed  = 0.0; // start fresh at the shine peak
        });
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.fluidCtrl.repaint?.addListener(_onFrame);
    });
  }

  @override
  void dispose() {
    widget.fluidCtrl.repaint?.removeListener(_onFrame);
    _press.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _onFrame() {
    if (!mounted) return;

    bool needsRebuild = false;

    // ── Shimmer tick (wall-clock driven, not frame-rate) ──────────────────────
    if (widget.isFranko && _shineActive) {
      final now  = DateTime.now();
      final dtMs = _lastFrameTime != null
          ? now.difference(_lastFrameTime!).inMicroseconds / 1000.0
          : 16.0;
      _lastFrameTime = now;
      _shineElapsed  = (_shineElapsed + dtMs) % _shineCycleMs;

      // Shine window: first _shineHalfMs*2 of every cycle; dark otherwise
      final newShine = _shineElapsed < _shineHalfMs
          ? _shineElapsed / _shineHalfMs                          // 0→1
          : _shineElapsed < _shineHalfMs * 2
              ? 1.0 - ((_shineElapsed - _shineHalfMs) / _shineHalfMs) // 1→0
              : 0.0;                                               // dark

      if ((newShine - _shineValue).abs() > 0.005) {
        _shineValue  = newShine;
        needsRebuild = true;
      }
    }

    // ── Proximity (every 3rd frame) ───────────────────────────────────────────
    _frameSkip++;
    if (_frameSkip % 3 == 0) {
      final engine = widget.fluidCtrl.engine;
      if (engine != null) {
        final ctx = _key.currentContext;
        if (ctx != null) {
          final box = ctx.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            final screenSize = MediaQuery.of(context).size;
            final orbSx = engine.orbX * screenSize.width;
            final orbSy = engine.orbY * screenSize.height;
            final pos   = box.localToGlobal(Offset.zero);
            final sz    = box.size;
            final lx    = orbSx - pos.dx;
            final ly    = orbSy - pos.dy;
            final cdx   = lx - sz.width  / 2;
            final cdy   = ly - sz.height / 2;
            final dist  = sqrt(cdx * cdx + cdy * cdy);
            final prox  = (1.0 - dist / (sz.width * 1.2)).clamp(0.0, 1.0);
            final newOrb = Offset(lx / sz.width, ly / sz.height);

            if ((newOrb.dx - _localOrb.dx).abs() > 0.01 ||
                (newOrb.dy - _localOrb.dy).abs() > 0.01 ||
                (prox - _proximity).abs() >= 0.01) {
              _localOrb  = newOrb;
              _proximity = prox;
              needsRebuild = true;
            }
          }
        }
      }
    }

    if (needsRebuild) setState(() {});
  }

  Widget _orb(Widget child) {
    final e = widget.fluidCtrl.engine;
    final r = widget.fluidCtrl.repaint;
    if (e == null || r == null) return child;
    return OrbAwareText(engine: e, repaint: r, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (_, child) => Opacity(
        opacity: _entranceFade.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, _entranceSlide.value),
          child: child,
        ),
      ),
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
            child: _buildCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final t             = ((_proximity - 0.55) / 0.35).clamp(0.0, 1.0);
    final labelColor    = Color.lerp(AppTheme.textPrimary, const Color(0xFF1a0a2e), t)!;
    final sublabelColor = Color.lerp(AppTheme.textHint,    const Color(0x99200040), t)!;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          SizedBox(
            width: 28, height: 28,
            child: widget.isFranko
                ? ColorFiltered(
                    colorFilter: ColorFilter.matrix([
                      1.0 - t * 0.85, 0, 0, 0, 0,
                      0, 1.0 - t * 0.85, 0, 0, 0,
                      0, 0, 1.0 - t * 0.85, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
                    child: widget.icon,
                  )
                : widget.icon,
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment:  MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _orb(Text(widget.label,
                  style: AppTheme.cardLabelStyle.copyWith(
                    color:       labelColor,
                    fontWeight:  widget.selected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: widget.isArabic ? 0.5 : 2.4,
                  ))),
              const SizedBox(height: 3),
              _orb(Text(widget.sublabel,
                  style: AppTheme.cardSublabelStyle.copyWith(
                    color:       sublabelColor,
                    letterSpacing: widget.isArabic ? 0.3 : 0.6,
                  ))),
            ],
          ),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve:    Curves.easeOutBack,
            width:    widget.selected ? 28 : 0,
            height:   widget.selected ? 28 : 0,
            child: widget.selected
                ? Container(
                    decoration: BoxDecoration(
                      color:  AppTheme.midPurple.withOpacity(0.18),
                      shape:  BoxShape.circle,
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
        ],
      ),
    );

    if (widget.isFranko) {
      return SizedBox(
        key: _key, height: 84,
        child: _ShimmerGlassCard(
          selected:  widget.selected,
          shimmer:   _shineValue,
          proximity: _proximity,
          orbOffset: _localOrb,
          child:     content,
        ),
      );
    }

    return SizedBox(
      key: _key, height: 84,
      child: LiquidGlassCard(
        selected:  widget.selected,
        orbOffset: _localOrb,
        proximity: _proximity,
        height:    84,
        child:     content,
      ),
    );
  }
}

// ── Shimmer glass card (FRANKO only) ──────────────────────────────────────────
class _ShimmerGlassCard extends StatelessWidget {
  final bool   selected;
  final double shimmer, proximity;
  final Offset orbOffset;
  final Widget child;

  const _ShimmerGlassCard({
    required this.selected,
    required this.shimmer,
    required this.proximity,
    required this.orbOffset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final orbTint     = Color.fromARGB(
        (proximity * 38).round().clamp(0, 255), 168, 85, 247);
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
        CustomPaint(
          painter: _ShimmerPainter(
            selected: selected, shimmer: shimmer,
            proximity: proximity, orbOffset: orbOffset,
            borderAlpha: borderAlpha,
          ),
        ),
        child,
      ]),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final bool   selected;
  final double shimmer, proximity;
  final Offset orbOffset;
  final int    borderAlpha;

  const _ShimmerPainter({
    required this.selected, required this.shimmer,
    required this.proximity, required this.orbOffset,
    required this.borderAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    if (shimmer > 0.001) {
      final cx = size.width * (-0.3 + shimmer * 1.6);
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(rect, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: const [
            Color(0x00FFFFFF), Color(0x00FFFFFF),
            Color(0x28FFFFFF), Color(0x40FFFFFF),
            Color(0x28FFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.28, 0.42, 0.50, 0.58, 0.72, 1.0],
        ).createShader(Rect.fromCenter(
            center: Offset(cx, size.height / 2),
            width: 200, height: size.height)));
      canvas.restore();
    }

    if (proximity > 0.05) {
      final ox    = orbOffset.dx * size.width;
      final oy    = orbOffset.dy * size.height;
      final glowR = size.width * 0.55;
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawCircle(Offset(ox, oy), glowR, Paint()
        ..shader = RadialGradient(colors: [
          Color.fromARGB((proximity * 40).round().clamp(0, 255), 200, 100, 255),
          Color.fromARGB((proximity * 18).round().clamp(0, 255), 168, 85,  247),
          const Color(0x00000000),
        ], stops: const [0.0, 0.45, 1.0]).createShader(
            Rect.fromCircle(center: Offset(ox, oy), radius: glowR)));
      canvas.restore();
    }

    final dirX = (orbOffset.dx - 0.5) * 2.0;
    final dirY = (orbOffset.dy - 0.5) * 2.0;
    final dimA = (borderAlpha * 0.12).round().clamp(0, 255);
    canvas.drawRRect(rrect, Paint()
      ..shader = LinearGradient(
          begin: Alignment(dirX.clamp(-1.0, 1.0), dirY.clamp(-1.0, 1.0)),
          end:   Alignment(-dirX.clamp(-1.0, 1.0), -dirY.clamp(-1.0, 1.0)),
          colors: selected
              ? [Color.fromARGB(borderAlpha, 168, 85, 247),
                 Color.fromARGB(dimA,         168, 85, 247)]
              : [Color.fromARGB(borderAlpha, 220, 200, 255),
                 Color.fromARGB(dimA,         220, 200, 255)])
          .createShader(rect)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = proximity > 0.15 ? 1.1 : 0.7);

    if (proximity > 0.05) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
            const Radius.circular(17)),
        Paint()
          ..color       = Color.fromARGB(
              (proximity * 22).round().clamp(0, 255), 255, 255, 255)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 0.5);
    }
  }

  @override
  bool shouldRepaint(_ShimmerPainter o) =>
      o.shimmer != shimmer || o.selected != selected ||
      o.proximity != proximity || o.orbOffset != orbOffset ||
      o.borderAlpha != borderAlpha;
}

// ── Icons ─────────────────────────────────────────────────────────────────────
class _EmojiIcon extends StatelessWidget {
  final String emoji;
  const _EmojiIcon(this.emoji);
  @override Widget build(BuildContext context) =>
      Text(emoji, style: const TextStyle(fontSize: 24, height: 1.0));
}

class _FrankoIcon extends StatelessWidget {
  const _FrankoIcon();
  @override Widget build(BuildContext context) =>
      SizedBox(width: 26, height: 26,
          child: CustomPaint(painter: _FrankoGlyphPainter()));
}
class _FrankoGlyphPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final cx = s.width / 2; final cy = s.height / 2;
    canvas.drawCircle(Offset(cx, cy), s.width / 2 - 1,
        Paint()..color = const Color(0x33FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    final p = Paint()..color = const Color(0x99FFFFFF)..style = PaintingStyle.stroke
      ..strokeWidth = 1.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
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
  @override Widget build(BuildContext context) =>
      SizedBox(width: 30, height: 26,
          child: CustomPaint(painter: _SimplePyramidPainter()));
}
class _SimplePyramidPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    canvas.drawLine(Offset(0, h * 0.85), Offset(w, h * 0.85),
        Paint()..color = const Color(0x55FFD700)..strokeWidth = 0.8);
    final left = Path()..moveTo(w * 0.02, h * 0.85)..lineTo(w * 0.22, h * 0.52)
      ..lineTo(w * 0.42, h * 0.85)..close();
    canvas.drawPath(left, Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: const [Color(0xFFD4A017), Color(0xFF8B6914)])
        .createShader(Rect.fromLTWH(w * 0.02, h * 0.52, w * 0.40, h * 0.33)));
    canvas.drawPath(left, Paint()..color = const Color(0xAAFFD700)
      ..style = PaintingStyle.stroke..strokeWidth = 0.7);
    final cL = Path()..moveTo(w * 0.20, h * 0.85)..lineTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.50, h * 0.85)..close();
    canvas.drawPath(cL, Paint()..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: const [Color(0xFFFFD700), Color(0xFFB8860B)])
        .createShader(Rect.fromLTWH(w * 0.20, h * 0.06, w * 0.60, h * 0.79)));
    final cS = Path()..moveTo(w * 0.50, h * 0.06)..lineTo(w * 0.80, h * 0.85)
      ..lineTo(w * 0.50, h * 0.85)..close();
    canvas.drawPath(cS, Paint()..shader = LinearGradient(
        begin: Alignment.topRight, end: Alignment.bottomLeft,
        colors: const [Color(0xFF8B6914), Color(0xFF5C440A)])
        .createShader(Rect.fromLTWH(w * 0.50, h * 0.06, w * 0.30, h * 0.79)));
    final outline = Path()..moveTo(w * 0.20, h * 0.85)..lineTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.80, h * 0.85)..close();
    canvas.drawPath(outline, Paint()..color = const Color(0xCCFFD700)
      ..style = PaintingStyle.stroke..strokeWidth = 1.0..strokeJoin = StrokeJoin.miter);
    canvas.drawCircle(Offset(w * 0.50, h * 0.06), 2.0,
        Paint()..color = const Color(0xAAFFFFAA)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0));
    canvas.drawCircle(Offset(w * 0.50, h * 0.06), 1.0, Paint()..color = Colors.white);
  }
  @override bool shouldRepaint(_) => false;
}

// ─── Blur dissolve route ──────────────────────────────────────────────────────
PageRoute _blurDissolveRoute(Widget page) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionDuration:        const Duration(milliseconds: 700),
      reverseTransitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, anim, __, child) {
        final blur = Tween<double>(begin: 14, end: 0)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
        final opacity = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) => blur.value > 0.3
              ? ImageFiltered(
                  imageFilter: ImageFilter.blur(
                      sigmaX: blur.value, sigmaY: blur.value),
                  child: Opacity(opacity: opacity.value, child: child),
                )
              : child,
        );
      },
    );