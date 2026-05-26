import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'velocity_field.dart';

// ── Trail point ───────────────────────────────────────────────────────────────
class TrailPoint {
  double x, y, age;
  TrailPoint(this.x, this.y) : age = 0.0;
}

// ── Engine ────────────────────────────────────────────────────────────────────
class FluidEngine {
  static const int    _kTrailLen   = 60;   // more points = smoother tube
  static const double _kTrailDecay = 0.055; // slightly faster decay so tail disappears cleanly

  Offset _touch      = const Offset(0.5, 0.5);
  Offset _velocity   = Offset.zero;
  double _touchForce = 0.0;
  double _touchBurst = 0.0;

  final List<TrailPoint> trail = List.generate(
      _kTrailLen, (_) => TrailPoint(0.5, 0.5)..age = 1.0);
  int _trailHead = 0;

  final VelocityField velocityField = VelocityField();

  void tick(double dt) {
    _touchForce = (_touchForce - dt * 1.5).clamp(0.0, 1.0);
    _touchBurst = (_touchBurst - dt * 4.0).clamp(0.0, 1.0);
    _velocity   = _velocity * 0.88;
    for (final p in trail) {
      p.age = (p.age + dt * _kTrailDecay).clamp(0.0, 1.0);
    }
  }

  void resetTrail(double nx, double ny) {
    for (final p in trail) { p.x = nx; p.y = ny; p.age = 1.0; }
    _trailHead = 0;
  }

  void pushTrail(double nx, double ny) {
    trail[_trailHead] = TrailPoint(nx, ny);
    _trailHead = (_trailHead + 1) % _kTrailLen;
  }

  void setTouch(Offset t)      => _touch = t;
  void setVelocity(Offset v)   => _velocity = v;
  void setTouchForce(double f) => _touchForce = f;
  void setTouchBurst(double b) => _touchBurst = b;

  Offset get touch      => _touch;
  Offset get velocity   => _velocity;
  double get touchForce => _touchForce;
  double get touchBurst => _touchBurst;
}

// ── Painter ───────────────────────────────────────────────────────────────────
class FluidPainter extends CustomPainter {
  final FluidEngine engine;
  final Size        screenSize;

  FluidPainter({
    required this.engine,
    required this.screenSize,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final fw = size.width;
    final fh = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, fw, fh),
      Paint()..color = const Color(0xFF000000),
    );

    _drawTrail(canvas, fw, fh);
    _drawFinger(canvas, fw, fh);
  }

  void _drawTrail(Canvas canvas, double fw, double fh) {
    // Collect active points newest-first
    final pts = <TrailPoint>[];
    for (int i = 0; i < FluidEngine._kTrailLen; i++) {
      final idx = (engine._trailHead - 1 - i + FluidEngine._kTrailLen) % FluidEngine._kTrailLen;
      final p = engine.trail[idx];
      if (p.age >= 0.98) break;
      pts.add(p);
    }
    if (pts.length < 2) return;

    // ── Draw each segment as a circle-pair sandwich inside saveLayer ──────────
    // saveLayer isolates all blending — no visible layer rings escape to screen.
    // We draw from OLDEST to NEWEST so newer (brighter) segments paint on top.
    final screenRect = Rect.fromLTWH(0, 0, fw, fh);

    // ── AURA layer (outermost soft glow) ──────────────────────────────────────
    canvas.saveLayer(screenRect, Paint()..blendMode = BlendMode.screen);
    for (int i = pts.length - 2; i >= 0; i--) {
      _drawSegmentCircle(canvas, pts[i], pts[i + 1], fw, fh,
        radiusFactor: 2.6,
        alphaNew: 0.10,
        alphaOld: 0.0,
        colorNew: const Color(0xFF5A10C8),
        colorOld: const Color(0xFF000000),
      );
    }
    canvas.restore();

    // ── BODY layer (main tube) ────────────────────────────────────────────────
    canvas.saveLayer(screenRect, Paint()..blendMode = BlendMode.screen);
    for (int i = pts.length - 2; i >= 0; i--) {
      _drawSegmentCircle(canvas, pts[i], pts[i + 1], fw, fh,
        radiusFactor: 1.0,
        alphaNew: 0.85,
        alphaOld: 0.0,
        colorNew: const Color(0xFFB43CFF),
        colorOld: const Color(0xFF000000),
      );
    }
    canvas.restore();

    // ── CORE layer (bright white-violet center) ───────────────────────────────
    canvas.saveLayer(screenRect, Paint()..blendMode = BlendMode.screen);
    for (int i = pts.length - 2; i >= 0; i--) {
      _drawSegmentCircle(canvas, pts[i], pts[i + 1], fw, fh,
        radiusFactor: 0.38,
        alphaNew: 1.0,
        alphaOld: 0.0,
        colorNew: const Color(0xFFEFD0FF),
        colorOld: const Color(0xFF000000),
      );
    }
    canvas.restore();
  }

  /// Draws one segment as a filled rounded stroke using drawLine with strokeCap.round.
  /// Opacity AND radius both go to zero at the tail — no ball artifact.
  void _drawSegmentCircle(
    Canvas canvas,
    TrailPoint a,
    TrailPoint b,
    double fw,
    double fh, {
    required double radiusFactor,
    required double alphaNew,
    required double alphaOld,
    required Color  colorNew,
    required Color  colorOld,
  }) {
    final ageA = a.age.clamp(0.0, 1.0);
    final ageB = b.age.clamp(0.0, 1.0);

    // Cubic ease-out: opacity drops steeply near tail
    // Both opacity AND radius reach 0 at age=1 — no residual ball
    final opA = pow(1.0 - ageA, 2.2) as double;
    final opB = pow(1.0 - ageB, 2.2) as double;
    final opAvg = (opA + opB) * 0.5;
    if (opAvg < 0.004) return;

    // Radius: large near finger, tapers to exactly 0 at tail
    // 0.042 * fh at newest, 0 at oldest — gives a pointed tail, no ball
    final rA = fh * 0.042 * opA * radiusFactor;
    final rB = fh * 0.042 * opB * radiusFactor;
    final rAvg = (rA + rB) * 0.5;
    if (rAvg < 0.5) return;

    final col = Color.lerp(colorOld, colorNew, opAvg)!;
    final alpha = (opAvg * (ageA < ageB ? alphaNew : alphaOld) +
                   opAvg * (ageA < ageB ? alphaOld : alphaNew)) * 0.5;
    // Simpler: just use opAvg-scaled colorNew alpha
    final paint = Paint()
      ..color      = col.withOpacity((opAvg * alphaNew).clamp(0.0, 1.0))
      ..strokeWidth = rAvg * 2.0
      ..strokeCap  = StrokeCap.round
      ..style      = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(a.x * fw, a.y * fh),
      Offset(b.x * fw, b.y * fh),
      paint,
    );
  }

  // ── Live finger blob ──────────────────────────────────────────────────────
  void _drawFinger(Canvas canvas, double fw, double fh) {
    final tf = engine.touchForce;
    if (tf < 0.01) return;

    final fx = engine.touch.dx * fw;
    final fy = engine.touch.dy * fh;
    final r  = fh * 0.055 * tf; // slightly smaller than before

    // Outer aura
    canvas.drawCircle(
      Offset(fx, fy),
      r * 2.6,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader    = ui.Gradient.radial(
          Offset(fx, fy), r * 2.6,
          [
            Color.fromARGB((tf * 25).clamp(0, 255).toInt(), 100, 20, 220),
            const Color(0x00000000),
          ],
        ),
    );

    // Main body
    canvas.drawCircle(
      Offset(fx, fy),
      r,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader    = ui.Gradient.radial(
          Offset(fx, fy), r,
          [
            Color.fromARGB((tf * 210).clamp(0, 255).toInt(), 190, 80, 255),
            Color.fromARGB((tf * 90).clamp(0, 255).toInt(),  120, 25, 230),
            const Color(0x00000000),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Hot core
    canvas.drawCircle(
      Offset(fx, fy),
      r * 0.28,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader    = ui.Gradient.radial(
          Offset(fx, fy), r * 0.28,
          [
            Color.fromARGB((tf * 255).clamp(0, 255).toInt(), 252, 215, 255),
            const Color(0x00000000),
          ],
        ),
    );

    // Velocity streak
    final vel    = engine.velocity;
    final velMag = sqrt(vel.dx * vel.dx + vel.dy * vel.dy);
    if (velMag > 0.0005) {
      final nx        = vel.dx / velMag;
      final ny        = vel.dy / velMag;
      final streakLen = (velMag * fw * 7.0).clamp(0.0, fh * 0.22);

      canvas.drawLine(
        Offset(fx, fy),
        Offset(fx + nx * streakLen, fy + ny * streakLen),
        Paint()
          ..blendMode  = BlendMode.screen
          ..strokeWidth = r * 1.4
          ..strokeCap  = StrokeCap.round
          ..style      = PaintingStyle.stroke
          ..shader     = ui.Gradient.linear(
            Offset(fx, fy),
            Offset(fx + nx * streakLen, fy + ny * streakLen),
            [
              Color.fromARGB((tf * 45).clamp(0, 255).toInt(), 160, 55, 255),
              const Color(0x00000000),
            ],
          ),
      );

      canvas.drawLine(
        Offset(fx, fy),
        Offset(fx + nx * streakLen, fy + ny * streakLen),
        Paint()
          ..blendMode  = BlendMode.screen
          ..strokeWidth = r * 0.35
          ..strokeCap  = StrokeCap.round
          ..style      = PaintingStyle.stroke
          ..shader     = ui.Gradient.linear(
            Offset(fx, fy),
            Offset(fx + nx * streakLen, fy + ny * streakLen),
            [
              Color.fromARGB((tf * 220).clamp(0, 255).toInt(), 238, 192, 255),
              const Color(0x00000000),
            ],
          ),
      );
    }

    // Touch burst
    final tb = engine.touchBurst;
    if (tb > 0.02) {
      final br = fh * 0.12 * tb;
      canvas.drawCircle(
        Offset(fx, fy),
        br,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), br,
            [
              Color.fromARGB((tb * tb * 80).clamp(0, 255).toInt(), 215, 165, 255),
              const Color(0x00000000),
            ],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(FluidPainter old) => true;
}

double mix(double a, double b, double t) => a + (b - a) * t;