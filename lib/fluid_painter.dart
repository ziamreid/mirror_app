import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'velocity_field.dart';

class TrailPoint {
  double x, y, age;
  TrailPoint(this.x, this.y) : age = 0.0;
}

class FluidEngine {
  static const int    _kTrailLen   = 30;
  static const double _kTrailDecay = 0.12; // fast decay — trail gone in ~2 sec

  Offset _touch      = const Offset(0.5, 0.5);
  Offset _velocity   = Offset.zero;
  double _touchForce = 0.0;
  double _touchBurst = 0.0;
  bool   _touching   = false;

  final List<TrailPoint> trail = List.generate(
      _kTrailLen, (_) => TrailPoint(0.5, 0.5)..age = 1.0);
  int _trailHead = 0;

  final VelocityField velocityField = VelocityField();

  void tick(double dt) {
    _touchForce = (_touchForce - dt * 2.0).clamp(0.0, 1.0);
    _touchBurst = (_touchBurst - dt * 4.0).clamp(0.0, 1.0);
    _velocity   = _velocity * 0.88;

    // When not touching, decay 4x faster so trail disappears quickly
    final decayRate = _touching ? _kTrailDecay : _kTrailDecay * 4.0;
    for (final p in trail) {
      p.age = (p.age + dt * decayRate).clamp(0.0, 1.0);
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
  void setTouching(bool v)     => _touching = v;

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
    for (int i = 0; i < FluidEngine._kTrailLen; i++) {
      final idx = (engine._trailHead - 1 - i + FluidEngine._kTrailLen)
          % FluidEngine._kTrailLen;
      final p = engine.trail[idx];
      if (p.age >= 0.98) continue;

      // Smooth cubic fade — fully transparent well before age=1
      final t   = p.age.clamp(0.0, 1.0);
      final op  = pow(1.0 - t, 2.0) as double; // 0..1, reaches 0 at age=1
      if (op < 0.01) continue;

      final cx  = p.x * fw;
      final cy  = p.y * fh;

      // ── Outer aura: large soft blob ───────────────────────────────────────
      // This is the main "plasma" look — very wide, very transparent
      final auraR = fh * 0.18 * op;
      canvas.drawCircle(
        Offset(cx, cy),
        auraR,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy), auraR,
            [
              Color.fromARGB((op * 60).clamp(0,255).toInt(),  90, 10, 200),
              Color.fromARGB((op * 20).clamp(0,255).toInt(),  60,  5, 150),
              const Color(0x00000000),
            ],
            [0.0, 0.5, 1.0],
          ),
      );

      // ── Mid glow: medium violet ───────────────────────────────────────────
      final midR = fh * 0.08 * op;
      canvas.drawCircle(
        Offset(cx, cy),
        midR,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy), midR,
            [
              Color.fromARGB((op * 180).clamp(0,255).toInt(), 170, 50, 255),
              Color.fromARGB((op * 60).clamp(0,255).toInt(),  110, 20, 220),
              const Color(0x00000000),
            ],
            [0.0, 0.6, 1.0],
          ),
      );

      // ── Bright core: small white-violet dot ───────────────────────────────
      final coreR = fh * 0.025 * op;
      canvas.drawCircle(
        Offset(cx, cy),
        coreR,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy), coreR,
            [
              Color.fromARGB((op * 240).clamp(0,255).toInt(), 240, 190, 255),
              const Color(0x00000000),
            ],
          ),
      );
    }
  }

  void _drawFinger(Canvas canvas, double fw, double fh) {
    final tf = engine.touchForce;
    if (tf < 0.01) return;

    final fx = engine.touch.dx * fw;
    final fy = engine.touch.dy * fh;

    // ── Large outer plasma aura (the big glow you want) ───────────────────
    final bigR = fh * 0.22 * tf;
    canvas.drawCircle(
      Offset(fx, fy), bigR,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader    = ui.Gradient.radial(
          Offset(fx, fy), bigR,
          [
            Color.fromARGB((tf * 70).clamp(0,255).toInt(),  90, 10, 210),
            Color.fromARGB((tf * 30).clamp(0,255).toInt(),  60,  5, 150),
            const Color(0x00000000),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // ── Mid violet glow ───────────────────────────────────────────────────
    final midR = fh * 0.10 * tf;
    canvas.drawCircle(
      Offset(fx, fy), midR,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader    = ui.Gradient.radial(
          Offset(fx, fy), midR,
          [
            Color.fromARGB((tf * 220).clamp(0,255).toInt(), 190, 70, 255),
            Color.fromARGB((tf * 80).clamp(0,255).toInt(),  120, 20, 230),
            const Color(0x00000000),
          ],
          [0.0, 0.55, 1.0],
        ),
    );

    // ── Bright hot core ───────────────────────────────────────────────────
    final coreR = fh * 0.032 * tf;
    canvas.drawCircle(
      Offset(fx, fy), coreR,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader    = ui.Gradient.radial(
          Offset(fx, fy), coreR,
          [
            Color.fromARGB((tf * 255).clamp(0,255).toInt(), 252, 215, 255),
            const Color(0x00000000),
          ],
        ),
    );

    // ── Velocity streak ───────────────────────────────────────────────────
    final vel    = engine.velocity;
    final velMag = sqrt(vel.dx * vel.dx + vel.dy * vel.dy);
    if (velMag > 0.0005) {
      final nx        = vel.dx / velMag;
      final ny        = vel.dy / velMag;
      final streakLen = (velMag * fw * 6.0).clamp(0.0, fh * 0.20);
      canvas.drawLine(
        Offset(fx, fy),
        Offset(fx + nx * streakLen, fy + ny * streakLen),
        Paint()
          ..blendMode  = BlendMode.screen
          ..strokeWidth = midR * 1.6
          ..strokeCap  = StrokeCap.round
          ..style      = PaintingStyle.stroke
          ..shader     = ui.Gradient.linear(
            Offset(fx, fy),
            Offset(fx + nx * streakLen, fy + ny * streakLen),
            [
              Color.fromARGB((tf * 50).clamp(0,255).toInt(), 150, 40, 255),
              const Color(0x00000000),
            ],
          ),
      );
    }

    // ── Touch burst ───────────────────────────────────────────────────────
    final tb = engine.touchBurst;
    if (tb > 0.02) {
      final br = fh * 0.18 * tb;
      canvas.drawCircle(
        Offset(fx, fy), br,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), br,
            [
              Color.fromARGB((tb * tb * 90).clamp(0,255).toInt(), 210, 160, 255),
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