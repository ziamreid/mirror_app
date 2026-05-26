import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'velocity_field.dart';

// ── Trail point ───────────────────────────────────────────────────────────────
class TrailPoint {
  double x, y, age;
  TrailPoint(this.x, this.y) : age = 0.0;
}

// ── Engine: pure Dart state, no offscreen buffers ─────────────────────────────
class FluidEngine {
  static const int    _kTrailLen   = 48;   // more points = smoother tube
  static const double _kTrailDecay = 0.04; // very slow fade

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

// ── Painter: draws directly on screen, zero offscreen buffers ────────────────
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

    // Black background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, fw, fh),
      Paint()..color = const Color(0xFF000000),
    );

    _drawTrail(canvas, fw, fh);
    _drawFinger(canvas, fw, fh);
  }

  // ── Trail: one filled Path per layer, no per-point draw calls ───────────────
  // This avoids the accumulation problem of overlapping srcOver circles.
  // We build a single smooth stroke path through all trail points and draw
  // it as a tapered stroke — one draw call, no overlap artifacts.
  void _drawTrail(Canvas canvas, double fw, double fh) {
    // Collect active points in order (newest first from ring buffer)
    final pts = <TrailPoint>[];
    for (int i = 0; i < FluidEngine._kTrailLen; i++) {
      final idx = (engine._trailHead - 1 - i + FluidEngine._kTrailLen) % FluidEngine._kTrailLen;
      final p = engine.trail[idx];
      if (p.age >= 0.99) break;
      pts.add(p);
    }
    if (pts.length < 2) return;

    // Draw 3 layers: outer aura, main body, bright core
    // Each layer is a single Path with varying stroke width at each segment
    _drawTubeLayer(canvas, pts, fw, fh,
      radiusFactor:  2.2,
      colorNew: const Color(0x1A5A0FC8),
      colorOld: const Color(0x003C0A80),
    );
    _drawTubeLayer(canvas, pts, fw, fh,
      radiusFactor:  1.0,
      colorNew: const Color(0xCCB43CFF),
      colorOld: const Color(0x00500ACC),
    );
    _drawTubeLayer(canvas, pts, fw, fh,
      radiusFactor:  0.35,
      colorNew: const Color(0xFFEBBEFF),
      colorOld: const Color(0x00C040FF),
    );
  }

  void _drawTubeLayer(
    Canvas canvas,
    List<TrailPoint> pts,
    double fw,
    double fh, {
    required double radiusFactor,
    required Color  colorNew,
    required Color  colorOld,
  }) {
    // Draw each segment as a rounded line with width tapering by age.
    // Using individual segments (not one Path) so width can vary.
    // No overlap artifacts because each segment is drawn once.
    for (int i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];

      final ageA = a.age;
      final ageB = b.age;

      // Skip fully faded
      if (ageA >= 0.99 && ageB >= 0.99) continue;

      final opA = pow(1.0 - ageA.clamp(0.0, 1.0), 1.5) as double;
      final opB = pow(1.0 - ageB.clamp(0.0, 1.0), 1.5) as double;
      final opAvg = (opA + opB) * 0.5;

      if (opAvg < 0.005) continue;

      // Radius tapers from large (new) to small (old)
      final rA = fh * mix(0.09, 0.012, ageA) * radiusFactor;
      final rB = fh * mix(0.09, 0.012, ageB) * radiusFactor;
      final rAvg = (rA + rB) * 0.5;

      final ax = a.x * fw;
      final ay = a.y * fh;
      final bx = b.x * fw;
      final by = b.y * fh;

      // Interpolate color opacity
      final col = Color.lerp(colorOld, colorNew, opAvg)!
          .withOpacity((Color.lerp(colorOld, colorNew, opAvg)!.opacity * opAvg).clamp(0.0, 1.0));

      canvas.drawLine(
        Offset(ax, ay),
        Offset(bx, by),
        Paint()
          ..color      = col
          ..strokeWidth = rAvg * 2.0
          ..strokeCap  = StrokeCap.round
          ..style      = PaintingStyle.stroke
          ..blendMode  = BlendMode.screen, // screen = bright on black, no blowout
      );
    }
  }

  // ── Live finger blob ─────────────────────────────────────────────────────────
  void _drawFinger(Canvas canvas, double fw, double fh) {
    final tf = engine.touchForce;
    if (tf < 0.01) return;

    final fx = engine.touch.dx * fw;
    final fy = engine.touch.dy * fh;
    final r  = fh * 0.075 * tf;

    // Outer soft aura — one circle, screen blend
    canvas.drawCircle(
      Offset(fx, fy),
      r * 2.8,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader    = ui.Gradient.radial(
          Offset(fx, fy), r * 2.8,
          [
            Color.fromARGB((tf * 22).clamp(0, 255).toInt(), 100, 20, 220),
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
            Color.fromARGB((tf * 200).clamp(0, 255).toInt(), 190, 80, 255),
            Color.fromARGB((tf * 90).clamp(0, 255).toInt(),  120, 25, 230),
            const Color(0x00000000),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // White-violet hot core
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
      final streakLen = (velMag * fw * 7.0).clamp(0.0, fh * 0.25);

      canvas.drawLine(
        Offset(fx, fy),
        Offset(fx + nx * streakLen, fy + ny * streakLen),
        Paint()
          ..blendMode  = BlendMode.screen
          ..strokeWidth = r * 1.6
          ..strokeCap  = StrokeCap.round
          ..style      = PaintingStyle.stroke
          ..shader     = ui.Gradient.linear(
            Offset(fx, fy),
            Offset(fx + nx * streakLen, fy + ny * streakLen),
            [
              Color.fromARGB((tf * 40).clamp(0, 255).toInt(), 160, 55, 255),
              const Color(0x00000000),
            ],
          ),
      );

      canvas.drawLine(
        Offset(fx, fy),
        Offset(fx + nx * streakLen, fy + ny * streakLen),
        Paint()
          ..blendMode  = BlendMode.screen
          ..strokeWidth = r * 0.4
          ..strokeCap  = StrokeCap.round
          ..style      = PaintingStyle.stroke
          ..shader     = ui.Gradient.linear(
            Offset(fx, fy),
            Offset(fx + nx * streakLen, fy + ny * streakLen),
            [
              Color.fromARGB((tf * 210).clamp(0, 255).toInt(), 238, 192, 255),
              const Color(0x00000000),
            ],
          ),
      );
    }

    // Touch burst
    final tb = engine.touchBurst;
    if (tb > 0.02) {
      final br = fh * 0.14 * tb;
      canvas.drawCircle(
        Offset(fx, fy),
        br,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), br,
            [
              Color.fromARGB((tb * tb * 75).clamp(0, 255).toInt(), 215, 165, 255),
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