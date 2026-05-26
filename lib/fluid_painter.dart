import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'velocity_field.dart';

class TrailPoint {
  double x, y, age;
  TrailPoint(this.x, this.y) : age = 0.0;
}

class FluidEngine {
  static const int    _kTrailLen   = 60;
  static const double _kTrailDecay = 0.05;

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
    final pts = <TrailPoint>[];
    for (int i = 0; i < FluidEngine._kTrailLen; i++) {
      final idx = (engine._trailHead - 1 - i + FluidEngine._kTrailLen) % FluidEngine._kTrailLen;
      final p = engine.trail[idx];
      if (p.age >= 0.97) break;
      pts.add(p);
    }
    if (pts.length < 2) return;

    // Draw oldest → newest so newer segments paint on top
    for (int i = pts.length - 2; i >= 0; i--) {
      final a = pts[i];
      final b = pts[i + 1];

      // Use the OLDER point's age to drive everything — the older end controls fade
      final age = b.age.clamp(0.0, 1.0); // b is older (further from head)

      // Cubic: reaches 0 well before age=1, so tail completely vanishes — no ball
      final op = pow(1.0 - age, 2.5) as double;
      if (op < 0.006) continue;

      final ax = a.x * fw;
      final ay = a.y * fh;
      final bx = b.x * fw;
      final by = b.y * fh;

      // ── Soft outer aura — very transparent, tight to tube (no separate oval) ──
      final auraR = fh * 0.028 * op;
      if (auraR > 0.5) {
        canvas.drawLine(
          Offset(ax, ay), Offset(bx, by),
          Paint()
            ..blendMode  = BlendMode.screen
            ..strokeWidth = auraR * 2.0
            ..strokeCap  = StrokeCap.round
            ..style      = PaintingStyle.stroke
            ..color      = Color.fromARGB(
                (op * 38).clamp(0, 255).toInt(), 110, 20, 240),
        );
      }

      // ── Main body — semi-transparent violet glow ──────────────────────────
      final bodyR = fh * 0.016 * op;
      if (bodyR > 0.5) {
        canvas.drawLine(
          Offset(ax, ay), Offset(bx, by),
          Paint()
            ..blendMode  = BlendMode.screen
            ..strokeWidth = bodyR * 2.0
            ..strokeCap  = StrokeCap.round
            ..style      = PaintingStyle.stroke
            ..color      = Color.fromARGB(
                (op * 180).clamp(0, 255).toInt(), 190, 60, 255),
        );
      }

      // ── Bright core — white-violet, thinnest ─────────────────────────────
      final coreR = fh * 0.006 * op;
      if (coreR > 0.3) {
        canvas.drawLine(
          Offset(ax, ay), Offset(bx, by),
          Paint()
            ..blendMode  = BlendMode.screen
            ..strokeWidth = coreR * 2.0
            ..strokeCap  = StrokeCap.round
            ..style      = PaintingStyle.stroke
            ..color      = Color.fromARGB(
                (op * 230).clamp(0, 255).toInt(), 240, 200, 255),
        );
      }
    }
  }

  void _drawFinger(Canvas canvas, double fw, double fh) {
    final tf = engine.touchForce;
    if (tf < 0.01) return;

    final fx = engine.touch.dx * fw;
    final fy = engine.touch.dy * fh;
    final r  = fh * 0.055 * tf;

    // Outer soft aura
    canvas.drawCircle(
      Offset(fx, fy), r * 2.4,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader    = ui.Gradient.radial(
          Offset(fx, fy), r * 2.4,
          [
            Color.fromARGB((tf * 30).clamp(0, 255).toInt(), 100, 20, 220),
            const Color(0x00000000),
          ],
        ),
    );

    // Main body
    canvas.drawCircle(
      Offset(fx, fy), r,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader    = ui.Gradient.radial(
          Offset(fx, fy), r,
          [
            Color.fromARGB((tf * 200).clamp(0, 255).toInt(), 190, 80, 255),
            Color.fromARGB((tf * 80).clamp(0, 255).toInt(),  120, 25, 230),
            const Color(0x00000000),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Hot core
    canvas.drawCircle(
      Offset(fx, fy), r * 0.28,
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
        Offset(fx, fy), br,
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