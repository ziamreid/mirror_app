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
      duration: const Duration(milliseconds: 1400),
    );

    _headerAnim = CurvedAnimation(
      parent: _cardsCtrl,
      curve: const Interval(0.00, 0.45, curve: Curves.easeOut),
    );
    _card0 = CurvedAnimation(
      parent: _cardsCtrl,
      curve: const Interval(0.15, 0.60, curve: Curves.easeOutCubic),
    );
    _card1 = CurvedAnimation(
      parent: _cardsCtrl,
      curve: const Interval(0.28, 0.74, curve: Curves.easeOutCubic),
    );
    _card2 = CurvedAnimation(
      parent: _cardsCtrl,
      curve: const Interval(0.42, 0.88, curve: Curves.easeOutCubic),
    );
    _subtext = CurvedAnimation(
      parent: _cardsCtrl,
      curve: const Interval(0.70, 1.00, curve: Curves.easeOut),
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
      Navigator.of(
        context,
      ).pushReplacement(_smoothRoute(OnboardingScreen(language: lang)));
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
                // ── Header ──────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _headerAnim,
                  builder: (_, __) => Opacity(
                    opacity: _headerAnim.value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - _headerAnim.value)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose your language',
                            style: TextStyle(
                              fontFamily: '.SF Pro Rounded',
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'this shapes how Eye speaks to you',
                            style: AppTheme.labelStyle.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // ── Cards ───────────────────────────────────────────────────
                _MaterialCard(
                  progress: _card0,
                  label: 'ENGLISH',
                  sublabel: 'speak to me clearly',
                  icon: const _USFlagIcon(),
                  selected: _selected == AppLanguage.english,
                  onTap: () => _onSelect(AppLanguage.english),
                  hasShimmer: false,
                  engine: _engine,
                  repaint: _repaint,
                ),
                const SizedBox(height: 12),
                _MaterialCard(
                  progress: _card1,
                  label: 'FRANKO',
                  sublabel: 'kalam 3adi zayak',
                  icon: const _FrankoIcon(),
                  selected: _selected == AppLanguage.franko,
                  onTap: () => _onSelect(AppLanguage.franko),
                  hasShimmer: true,
                  engine: _engine,
                  repaint: _repaint,
                ),
                const SizedBox(height: 12),
                _MaterialCard(
                  progress: _card2,
                  label: 'عربي',
                  sublabel: 'بالكلام الصريح',
                  icon: const _ArabicIcon(),
                  selected: _selected == AppLanguage.arabic,
                  onTap: () => _onSelect(AppLanguage.arabic),
                  hasShimmer: false,
                  isArabic: true,
                  engine: _engine,
                  repaint: _repaint,
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
// Materialising card — orb follows finger EVERYWHERE (no blocked region)
// ─────────────────────────────────────────────────────────────────────────────
class _MaterialCard extends StatefulWidget {
  final Animation<double> progress;
  final String label;
  final String sublabel;
  final Widget icon;
  final bool selected;
  final bool isArabic;
  final bool hasShimmer;
  final VoidCallback onTap;
  final FluidEngine? engine;
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
  late Animation<double> _sweepAnim;
  bool _sweptOnce = false;

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
  }

  void _onProgressChange() {
    if (!_sweptOnce && widget.progress.value > 0.5) {
      _sweptOnce = true;
      _sweep.forward();
    }
  }

  @override
  void dispose() {
    if (widget.hasShimmer) {
      widget.progress.removeListener(_onProgressChange);
    }
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
        final t = widget.progress.value;
        final blur = (1.0 - t) * 10.0;
        final scale = 1.0 + (1.0 - t) * 0.055;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
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
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          widget.onTap();
        },
        onTapCancel: () => _press.reverse(),
        child: AnimatedBuilder(
          animation: _press,
          builder: (_, child) =>
              Transform.scale(scale: 1.0 - _press.value * 0.03, child: child),
          child: widget.hasShimmer
              ? AnimatedBuilder(
                  animation: _sweepAnim,
                  builder: (_, child) => _LiquidGlassCard(
                    selected: widget.selected,
                    shimmer: _sweepAnim.value,
                    child: child!,
                  ),
                  child: _buildContent(),
                )
              : _LiquidGlassCard(
                  selected: widget.selected,
                  shimmer: 0,
                  child: _buildContent(),
                ),
        ),
      ),
    );
  }

  Widget _buildContent() => _CardContent(
    label: widget.label,
    sublabel: widget.sublabel,
    icon: widget.icon,
    selected: widget.selected,
    isArabic: widget.isArabic,
    orbWidget: _orb,
  );
}

// ── iOS 26 Liquid Glass card ─────────────────────────────────────────────────
class _LiquidGlassCard extends StatelessWidget {
  final bool selected;
  final double shimmer; // 0→1 sweep progress (Franko only)
  final Widget child;

  const _LiquidGlassCard({
    required this.selected,
    required this.shimmer,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: blur what's behind ──────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(color: const Color(0x22ffffff)),
          ),
          // ── Layer 2: liquid glass body ────────────────────────────────────
          CustomPaint(
            painter: _LiquidGlassPainter(selected: selected, shimmer: shimmer),
          ),
          // ── Layer 3: content ──────────────────────────────────────────────
          child,
        ],
      ),
    );
  }
}

// ── Liquid glass painter ──────────────────────────────────────────────────────
class _LiquidGlassPainter extends CustomPainter {
  final bool selected;
  final double shimmer;

  const _LiquidGlassPainter({required this.selected, required this.shimmer});

  @override
  void paint(Canvas canvas, Size size) {
    final r = 18.0;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // ── Body: near-zero fill so orb bleeds through ────────────────────────
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = selected ? const Color(0x14a855f7) : const Color(0x08FFFFFF),
    );

    // ── Shimmer sweep (Franko only) ───────────────────────────────────────
    if (shimmer > 0.0 && shimmer < 1.0) {
      final cx = size.width * (-0.3 + shimmer * 1.6);
      canvas.save();
      canvas.clipRRect(rrect);
      final shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0x00FFFFFF),
              Color(0x00FFFFFF),
              Color(0x20FFFFFF),
              Color(0x30FFFFFF),
              Color(0x20FFFFFF),
              Color(0x00FFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: const [0.0, 0.28, 0.42, 0.50, 0.58, 0.72, 1.0],
          ).createShader(
            Rect.fromCenter(
              center: Offset(cx, size.height / 2),
              width: 180,
              height: size.height,
            ),
          );
      canvas.drawRRect(rrect, Paint()..shader = shader);
      canvas.restore();
    }

    // ── Top specular highlight (iOS 26 glass edge) ────────────────────────
    final topHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x55FFFFFF), Color(0x00FFFFFF)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 28));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, 26),
        const Radius.circular(17),
      ),
      topHighlight,
    );

    // ── Outer border: gradient — bright top, fading bottom ────────────────
    final borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: selected
            ? const [Color(0x88a855f7), Color(0x33a855f7), Color(0x11a855f7)]
            : const [Color(0x66FFFFFF), Color(0x22FFFFFF), Color(0x08FFFFFF)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawRRect(rrect, borderPaint);

    // ── Inner border: subtle white inset (gives depth) ────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        const Radius.circular(17),
      ),
      Paint()
        ..color = const Color(0x0CFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(_LiquidGlassPainter old) =>
      old.selected != selected || old.shimmer != shimmer;
}

// ── Shimmer painter — Franko only ─────────────────────────────────────────────
class _ShimmerPainter extends CustomPainter {
  final double progress;
  final bool selected;
  const _ShimmerPainter({required this.progress, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final cx = size.width * (-0.3 + progress * 1.6);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.save();
    canvas.clipRRect(rrect);
    final shader =
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x16FFFFFF),
            Color(0x26FFFFFF),
            Color(0x16FFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.28, 0.42, 0.50, 0.58, 0.72, 1.0],
        ).createShader(
          Rect.fromCenter(
            center: Offset(cx, size.height / 2),
            width: 180,
            height: size.height,
          ),
        );
    canvas.drawRRect(rrect, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) =>
      old.progress != progress || old.selected != selected;
}

// ── Card content ──────────────────────────────────────────────────────────────
class _CardContent extends StatelessWidget {
  final String label;
  final String sublabel;
  final Widget icon;
  final bool selected;
  final bool isArabic;
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
          SizedBox(
            width: 28,
            height: 28,
            child: icon,
          ), // no orb inversion on icons
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              orbWidget(
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: '.SF Pro Rounded',
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
                    letterSpacing: isArabic ? 0.5 : 2.4,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              orbWidget(
                Text(
                  sublabel,
                  style: AppTheme.labelStyle.copyWith(
                    color: AppTheme.textHint,
                    letterSpacing: isArabic ? 0.3 : 0.6,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: selected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 6,
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
// Icons
// ─────────────────────────────────────────────────────────────────────────────

// US Flag — custom painter, unchanged from original
class _USFlagIcon extends StatelessWidget {
  const _USFlagIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 20,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: CustomPaint(painter: _USFlagPainter()),
    ),
  );
}

class _USFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.width, s.height),
      Paint()..color = const Color(0xFFB22234),
    );
    final stripeH = s.height / 13;
    final white = Paint()..color = Colors.white;
    for (int i = 1; i < 13; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * stripeH, s.width, stripeH), white);
    }
    final cantonW = s.width * 0.40;
    final cantonH = stripeH * 7;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cantonW, cantonH),
      Paint()..color = const Color(0xFF3C3B6E),
    );
    final star = Paint()..color = Colors.white;
    const cols = 6;
    const rows = 5;
    final sx = cantonW / (cols + 0.5);
    final sy = cantonH / (rows + 0.5);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        canvas.drawCircle(Offset((c + 0.75) * sx, (r + 0.75) * sy), 0.9, star);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// Franko — merged 3/ع glyph inside ring
class _FrankoIcon extends StatelessWidget {
  const _FrankoIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26,
    height: 26,
    child: CustomPaint(painter: _FrankoGlyphPainter()),
  );
}

class _FrankoGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final cy = s.height / 2;
    canvas.drawCircle(
      Offset(cx, cy),
      s.width / 2 - 1,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    final p = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    path.moveTo(cx - 4.5, cy - 6.0);
    path.quadraticBezierTo(cx + 6.0, cy - 6.0, cx + 5.0, cy - 0.5);
    path.quadraticBezierTo(cx + 6.0, cy + 0.5, cx + 0.5, cy + 0.5);
    path.quadraticBezierTo(cx + 7.0, cy + 0.5, cx + 5.5, cy + 5.5);
    path.quadraticBezierTo(cx + 1.5, cy + 9.0, cx - 3.5, cy + 6.5);
    path.quadraticBezierTo(cx - 7.0, cy + 3.5, cx - 5.0, cy + 0.5);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_) => false;
}

// Arabic — simple clean pyramid, colorful golden tones
class _ArabicIcon extends StatelessWidget {
  const _ArabicIcon();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 26,
    child: CustomPaint(painter: _SimplePyramidPainter()),
  );
}

class _SimplePyramidPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Ground line
    canvas.drawLine(
      Offset(0, h * 0.85),
      Offset(w, h * 0.85),
      Paint()
        ..color = const Color(0x55FFD700)
        ..strokeWidth = 0.8,
    );

    // Small left pyramid
    final left = Path()
      ..moveTo(w * 0.02, h * 0.85)
      ..lineTo(w * 0.22, h * 0.52)
      ..lineTo(w * 0.42, h * 0.85)
      ..close();
    canvas.drawPath(
      left,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFD4A017), Color(0xFF8B6914)],
        ).createShader(Rect.fromLTWH(w * 0.02, h * 0.52, w * 0.40, h * 0.33)),
    );
    canvas.drawPath(
      left,
      Paint()
        ..color = const Color(0xAAFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    // Large center pyramid
    final center = Path()
      ..moveTo(w * 0.20, h * 0.85)
      ..lineTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.80, h * 0.85)
      ..close();

    // Light face (left)
    final centerClipLight = Path()
      ..moveTo(w * 0.20, h * 0.85)
      ..lineTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.50, h * 0.85)
      ..close();
    canvas.drawPath(
      centerClipLight,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFFFFD700), Color(0xFFB8860B)],
        ).createShader(Rect.fromLTWH(w * 0.20, h * 0.06, w * 0.60, h * 0.79)),
    );

    // Shadow face (right)
    final centerClipShadow = Path()
      ..moveTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.80, h * 0.85)
      ..lineTo(w * 0.50, h * 0.85)
      ..close();
    canvas.drawPath(
      centerClipShadow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: const [Color(0xFF8B6914), Color(0xFF5C440A)],
        ).createShader(Rect.fromLTWH(w * 0.50, h * 0.06, w * 0.30, h * 0.79)),
    );

    canvas.drawPath(
      center,
      Paint()
        ..color = const Color(0xCCFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.miter,
    );

    // Glowing capstone
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.06),
      2.0,
      Paint()
        ..color = const Color(0xAAFFFFAA)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.06),
      1.0,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
PageRoute _smoothRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 500),
  transitionsBuilder: (_, anim, __, child) => FadeTransition(
    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
    child: child,
  ),
);
