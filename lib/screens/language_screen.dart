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
  late AnimationController _fadeIn;
  final FluidController    _fluidCtrl = FluidController();

  // Header proximity tracking
  final GlobalKey _headerKey = GlobalKey();
  double _headerProximity = 0.0;
  int    _headerFrameSkip = 0;

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    // Start tracking after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fluidCtrl.repaint?.addListener(_onFrame);
    });
  }

  @override
  void dispose() {
    _fluidCtrl.repaint?.removeListener(_onFrame);
    _fadeIn.dispose();
    super.dispose();
  }

  void _onFrame() {
    _headerFrameSkip++;
    if (_headerFrameSkip % 3 != 0) return;
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
    final pos = box.localToGlobal(Offset.zero);
    final sz  = box.size;
    final cdx = orbSx - (pos.dx + sz.width / 2);
    final cdy = orbSy - (pos.dy + sz.height / 2);
    final dist = sqrt(cdx * cdx + cdy * cdy);
    final prox = (1.0 - dist / (sz.width * 0.9)).clamp(0.0, 1.0);
    if ((prox - _headerProximity).abs() < 0.01) return;
    setState(() => _headerProximity = prox);
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
    // FIX: header text darkens when orb is bright and close
    final t = ((_headerProximity - 0.45) / 0.40).clamp(0.0, 1.0);
    final headerColor = Color.lerp(AppTheme.textPrimary, const Color(0xFF1a0a2e), t)!;
    final hintColor   = Color.lerp(AppTheme.textHint,   const Color(0x991a0a2e), t)!;

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
                _maybeOrb(Text('EYE',
                    style: AppTheme.appNameStyle.copyWith(color: headerColor))),
                const SizedBox(height: 6),
                // FIX: header reacts to orb brightness
                SizedBox(
                  key: _headerKey,
                  child: _maybeOrb(Text(
                    'CHOOSE YOUR LANGUAGE',
                    style: AppTheme.labelStyle.copyWith(
                      color: hintColor,
                      letterSpacing: 2.2,
                    ),
                  )),
                ),
                const Spacer(),
                Column(
                  children: [
                    _LangCard(
                      label:        'ENGLISH',
                      sublabel:     'speak to me clearly',
                      icon:         const _USFlagIcon(),
                      selected:     _selected == AppLanguage.english,
                      onTap:        () => _onSelect(AppLanguage.english),
                      fluidCtrl:    _fluidCtrl,
                      entranceDelay: 0,
                    ),
                    const SizedBox(height: 12),
                    _LangCard(
                      label:        'FRANKO',
                      sublabel:     'kalam 3adi zayak',
                      icon:         const _FrankoIcon(),
                      selected:     _selected == AppLanguage.franko,
                      onTap:        () => _onSelect(AppLanguage.franko),
                      fluidCtrl:    _fluidCtrl,
                      entranceDelay: 120,
                      isFranko:     true,
                    ),
                    const SizedBox(height: 12),
                    _LangCard(
                      label:        'عربي',
                      sublabel:     'بالكلام الصريح',
                      icon:         const _ArabicIcon(),
                      selected:     _selected == AppLanguage.arabic,
                      onTap:        () => _onSelect(AppLanguage.arabic),
                      isArabic:     true,
                      fluidCtrl:    _fluidCtrl,
                      entranceDelay: 240,
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

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 110), lowerBound: 0, upperBound: 1);
    _entrance = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));
    _entranceFade  = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _entranceSlide = Tween<double>(begin: 18.0, end: 0.0).animate(
        CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.entranceDelay), () {
      if (mounted) _entrance.forward();
    });
    widget.fluidCtrl.repaint?.addListener(_onFrame);
  }

  @override
  void dispose() {
    widget.fluidCtrl.repaint?.removeListener(_onFrame);
    _press.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _onFrame() {
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
    final pos   = box.localToGlobal(Offset.zero);
    final sz    = box.size;
    final lx    = orbSx - pos.dx;
    final ly    = orbSy - pos.dy;
    final cdx   = lx - sz.width  / 2;
    final cdy   = ly - sz.height / 2;
    final dist  = sqrt(cdx * cdx + cdy * cdy);
    final prox  = (1.0 - dist / (sz.width * 1.2)).clamp(0.0, 1.0);
    final newOrb = Offset(lx / sz.width, ly / sz.height);
    if ((prox - _proximity).abs() < 0.01 &&
        (newOrb.dx - _localOrb.dx).abs() < 0.01 &&
        (newOrb.dy - _localOrb.dy).abs() < 0.01) return;
    setState(() { _localOrb = newOrb; _proximity = prox; });
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
      child: GestureDetector(
        onTapDown:   (_) { _press.forward();  widget.fluidCtrl.lockOrb(); },
        onTapUp:     (_) { _press.reverse();  widget.fluidCtrl.unlockOrb(); widget.onTap(); },
        onTapCancel: ()  { _press.reverse();  widget.fluidCtrl.unlockOrb(); },
        child: AnimatedBuilder(
          animation: _press,
          builder: (_, child) => Transform.scale(
              scale: 1.0 - _press.value * 0.03, child: child),
          child: _buildCard(),
        ),
      ),
    );
  }

  Widget _buildCard() {
    // Text darkens when orb is bright
    final t = ((_proximity - 0.55) / 0.35).clamp(0.0, 1.0);
    final labelColor    = Color.lerp(AppTheme.textPrimary, const Color(0xFF1a0a2e), t)!;
    final sublabelColor = Color.lerp(AppTheme.textHint,    const Color(0x99200040), t)!;

    return SizedBox(
      key:    _key,
      height: 84,
      child: LiquidGlassCard(
        selected:  widget.selected,
        orbOffset: _localOrb,
        proximity: _proximity,
        height:    84,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              SizedBox(width: 28, height: 28,
                child: widget.isFranko
                    ? ColorFiltered(
                        colorFilter: ColorFilter.matrix([
                          1.0-t*0.85, 0, 0, 0, 0,
                          0, 1.0-t*0.85, 0, 0, 0,
                          0, 0, 1.0-t*0.85, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                        child: widget.icon,
                      )
                    : widget.icon,
              ),
              const SizedBox(width: 14),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _orb(Text(widget.label,
                      style: AppTheme.cardLabelStyle.copyWith(
                        color: labelColor,
                        fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: widget.isArabic ? 0.5 : 2.4,
                      ))),
                  const SizedBox(height: 3),
                  _orb(Text(widget.sublabel,
                      style: AppTheme.cardSublabelStyle.copyWith(
                        color: sublabelColor,
                        letterSpacing: widget.isArabic ? 0.3 : 0.6,
                      ))),
                ],
              ),
              const Spacer(),
              // FIX: Better selection indicator — animated circle checkmark
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                width:  widget.selected ? 28 : 0,
                height: widget.selected ? 28 : 0,
                child: widget.selected
                    ? Container(
                        decoration: BoxDecoration(
                          color: AppTheme.midPurple.withOpacity(0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.midPurple.withOpacity(0.5),
                              width: 0.8),
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
        ),
      ),
    );
  }
}

// ── Icons ─────────────────────────────────────────────────────────────────────

class _USFlagIcon extends StatelessWidget {
  const _USFlagIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 32, height: 22,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: CustomPaint(painter: _USFlagPainter()),
    ),
  );
}

class _USFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    final sh = h / 13;
    for (int i = 0; i < 13; i++) {
      canvas.drawRect(Rect.fromLTWH(0, i * sh, w, sh),
          Paint()..color = i.isEven ? const Color(0xFFB22234) : Colors.white);
    }
    final cW = w * 0.385; final cH = sh * 7;
    canvas.drawRect(Rect.fromLTWH(0, 0, cW, cH),
        Paint()..color = const Color(0xFF3C3B6E));
    final starPaint = Paint()..color = Colors.white;
    const rows = 9;
    final rowH = cH / rows;
    for (int r = 0; r < rows; r++) {
      final isEvenRow = r.isEven;
      final cols = isEvenRow ? 6 : 5;
      final colW = cW / (isEvenRow ? 6 : 5);
      final offsetX = isEvenRow ? colW / 2 : colW;
      for (int c = 0; c < cols; c++) {
        _drawStar(canvas,
            Offset(offsetX + c * colW, rowH / 2 + r * rowH), 1.1, starPaint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 4 * pi / 5) - pi / 2;
      final inner = radius * 0.4;
      final innerAngle = angle + 2 * pi / 5;
      final pt = Offset(center.dx + cos(angle) * radius,
                        center.dy + sin(angle) * radius);
      final ip = Offset(center.dx + cos(innerAngle) * inner,
                        center.dy + sin(innerAngle) * inner);
      if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
      path.lineTo(ip.dx, ip.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override bool shouldRepaint(_) => false;
}

class _FrankoIcon extends StatelessWidget {
  const _FrankoIcon();
  @override Widget build(BuildContext context) =>
      SizedBox(width:26,height:26,child:CustomPaint(painter:_FrankoGlyphPainter()));
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
      SizedBox(width:30,height:26,child:CustomPaint(painter:_SimplePyramidPainter()));
}
class _SimplePyramidPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size s) {
    final w=s.width; final h=s.height;
    canvas.drawLine(Offset(0,h*0.85),Offset(w,h*0.85),Paint()..color=const Color(0x55FFD700)..strokeWidth=0.8);
    final left=Path()..moveTo(w*0.02,h*0.85)..lineTo(w*0.22,h*0.52)..lineTo(w*0.42,h*0.85)..close();
    canvas.drawPath(left,Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
        colors:const[Color(0xFFD4A017),Color(0xFF8B6914)]).createShader(Rect.fromLTWH(w*0.02,h*0.52,w*0.40,h*0.33)));
    canvas.drawPath(left,Paint()..color=const Color(0xAAFFD700)..style=PaintingStyle.stroke..strokeWidth=0.7);
    final cL=Path()..moveTo(w*0.20,h*0.85)..lineTo(w*0.50,h*0.06)..lineTo(w*0.50,h*0.85)..close();
    canvas.drawPath(cL,Paint()..shader=LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
        colors:const[Color(0xFFFFD700),Color(0xFFB8860B)]).createShader(Rect.fromLTWH(w*0.20,h*0.06,w*0.60,h*0.79)));
    final cS=Path()..moveTo(w*0.50,h*0.06)..lineTo(w*0.80,h*0.85)..lineTo(w*0.50,h*0.85)..close();
    canvas.drawPath(cS,Paint()..shader=LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,
        colors:const[Color(0xFF8B6914),Color(0xFF5C440A)]).createShader(Rect.fromLTWH(w*0.50,h*0.06,w*0.30,h*0.79)));
    final outline=Path()..moveTo(w*0.20,h*0.85)..lineTo(w*0.50,h*0.06)..lineTo(w*0.80,h*0.85)..close();
    canvas.drawPath(outline,Paint()..color=const Color(0xCCFFD700)..style=PaintingStyle.stroke..strokeWidth=1.0..strokeJoin=StrokeJoin.miter);
    canvas.drawCircle(Offset(w*0.50,h*0.06),2.0,Paint()..color=const Color(0xAAFFFFAA)..maskFilter=const MaskFilter.blur(BlurStyle.normal,2.0));
    canvas.drawCircle(Offset(w*0.50,h*0.06),1.0,Paint()..color=Colors.white);
  }
  @override bool shouldRepaint(_) => false;
}

PageRoute _smoothRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_,__,___) => page,
  transitionDuration: const Duration(milliseconds: 500),
  transitionsBuilder: (_,anim,__,child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut), child: child));