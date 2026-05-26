import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'velocity_field.dart';

class TrailPoint {
  double x, y, age;
  TrailPoint(this.x, this.y) : age = 0.0;
}

class FluidEngine {
  static const int    _kTrailLen   = 80;
  static const double _kTrailDecay = 0.045;

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
    // Collect active points newest-first
    final pts = <TrailPoint>[];
    for (int i = 0; i < FluidEngine._kTrailLen; i++) {
      final idx = (engine._trailHead - 1 - i + FluidEngine._kTrailLen) % FluidEngine._kTrailLen;
      final p = engine.trail[idx];
      if (p.age >= 0.97) break;
      pts.add(p);
    }
    if (pts.length < 3) return;

    // Build one smooth catmull-rom path through all points
    // then draw it 3 times (aura, body, core) with different widths
    final path = _buildSmoothPath(pts, fw, fh);

    // How much of the trail is visible — drives the gradient
    final newestAge = pts.first.age.clamp(0.0, 1.0);
    final oldestAge = pts.last.age.clamp(0.0, 1.0);

    // ── Aura — wide, very soft ────────────────────────────────────────────────
    canvas.drawPath(path, Paint()
      ..blendMode  = BlendMode.screen
      ..strokeWidth = fh * 0.038
      ..strokeCap  = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style      = PaintingStyle.stroke
      ..shader     = _trailShader(pts, fw, fh,
          colorNew: const Color(0x286020E0),
          colorOld: const Color(0x00000000))
    );

    // ── Body — medium, glowing violet ─────────────────────────────────────────
    canvas.drawPath(path, Paint()
      ..blendMode  = BlendMode.screen
      ..strokeWidth = fh * 0.018
      ..strokeCap  = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style      = PaintingStyle.stroke
      ..shader     = _trailShader(pts, fw, fh,
          colorNew: const Color(0xCCB040FF),
          colorOld: const Color(0x00000000))
    );

    // ── Core — thin, bright white-violet ─────────────────────────────────────
    canvas.drawPath(path, Paint()
      ..blendMode  = BlendMode.screen
      ..strokeWidth = fh * 0.007
      ..strokeCap  = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style      = PaintingStyle.stroke
      ..shader     = _trailShader(pts, fw, fh,
          colorNew: const Color(0xFFEEC8FF),
          colorOld: const Color(0x00000000))
    );
  }

  // Build a smooth path using Catmull-Rom → Bezier conversion
  Path _buildSmoothPath(List<TrailPoint> pts, double fw, double fh) {
    final path = Path();
    // pts[0] = newest (finger), pts.last = oldest (tail)
    // Draw from tail to finger so newest is the "end" with full opacity
    final n = pts.length;

    path.moveTo(pts[n - 1].x * fw, pts[n - 1].y * fh);

    for (int i = n - 1; i >= 1; i--) {
      // Catmull-Rom control points
      final p0 = pts[(i + 1).clamp(0, n - 1)];
      final p1 = pts[i];
      final p2 = pts[i - 1];
      final p3 = pts[(i - 2).clamp(0, n - 1)];

      // Convert to cubic bezier
      final cp1x = p1.x + (p2.x - p0.x) / 6.0;
      final cp1y = p1.y + (p2.y - p0.y) / 6.0;
      final cp2x = p2.x - (p3.x - p1.x) / 6.0;
      final cp2y = p2.y - (p3.y - p1.y) / 6.0;

      path.cubicTo(
        cp1x * fw, cp1y * fh,
        cp2x * fw, cp2y * fh,
        p2.x * fw, p2.y * fh,
      );
    }

    return path;
  }

  // Linear gradient along the trail: new=colorNew (bright), old=colorOld (transparent)
  // Uses the bounding box of the path endpoints as gradient direction
  ui.Shader _trailShader(
    List<TrailPoint> pts,
    double fw,
    double fh, {
    required Color colorNew,
    required Color colorOld,
  }) {
    final newest = pts.first;
    final oldest = pts.last;
    return ui.Gradient.linear(
      Offset(newest.x * fw, newest.y * fh), // finger end = bright
      Offset(oldest.x * fw, oldest.y * fh), // tail end   = transparent
      [colorNew, colorOld],
    );
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