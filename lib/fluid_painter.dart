import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'velocity_field.dart';

final _rng = Random();

class TrailPoint {
  double x, y, age;
  double driftX = 0.0;
  double driftY = 0.0;
  TrailPoint(this.x, this.y) : age = 0.0;
}

class FluidEngine {
  static const int    _kTrailLen   = 80;
  static const double _kTrailDecay = 0.050;
  static const double _kMinDist    = 0.007;

  Offset _touch      = const Offset(0.5, 0.5);
  Offset _lastPush   = const Offset(-1, -1);
  Offset _velocity   = Offset.zero;
  double _touchForce = 0.0;
  double _touchBurst = 0.0;
  bool   _touching   = false;

  final List<TrailPoint> trail = List.generate(
      _kTrailLen, (_) => TrailPoint(0.5, 0.5)..age = 1.0);
  int _trailHead = 0;

  final VelocityField velocityField = VelocityField();

  void tick(double dt) {
    if (_touching) {
      _touchForce = 1.0;
    } else {
      _touchForce = (_touchForce - dt * 2.0).clamp(0.0, 1.0);
    }

    _touchBurst = (_touchBurst - dt * 4.0).clamp(0.0, 1.0);
    _velocity   = _velocity * 0.88;

    if (!_touching) {
      for (final p in trail) {
        if (p.age < 0.98) {
          p.x = (p.x + p.driftX * dt).clamp(0.0, 1.0);
          p.y = (p.y + p.driftY * dt).clamp(0.0, 1.0);
          p.driftX *= 0.82;
          p.driftY *= 0.82;
        }
      }
    }

    if (_touching) {
      for (final p in trail) {
        p.age = (p.age + dt * _kTrailDecay).clamp(0.0, 1.0);
      }
    } else {
      for (int i = 0; i < _kTrailLen; i++) {
        final idx = (_trailHead - 1 - i + _kTrailLen) % _kTrailLen;
        final p   = trail[idx];
        if (p.age >= 1.0) continue;
        final trailPos   = i / (_kTrailLen - 1).toDouble();
        final pointDecay = _kTrailDecay * 10.0 * (1.0 + trailPos * 5.0);
        p.age = (p.age + dt * pointDecay).clamp(0.0, 1.0);
      }
    }
  }

  void resetTrail(double nx, double ny) {
    // Age all points out first
    for (final p in trail) {
      p.x = nx; p.y = ny; p.age = 1.0;
      p.driftX = 0.0; p.driftY = 0.0;
    }
    _trailHead = 0;
    _lastPush  = Offset(nx, ny);

    // Pre-stamp several overlapping points at age=0 so the glow is
    // immediately full-bright the moment the thumb touches — no build-up delay.
    for (int i = 0; i < 18; i++) {
      trail[i] = TrailPoint(nx, ny)..age = 0.0;
    }
    _trailHead = 18;
  }

  void pushTrailDense(double nx, double ny) {
    final lx = _lastPush.dx;
    final ly = _lastPush.dy;
    if (lx < 0) { _writePt(nx, ny); _lastPush = Offset(nx, ny); return; }
    final dx = nx - lx, dy = ny - ly;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < _kMinDist) return;
    final steps = (dist / _kMinDist).ceil().clamp(1, 20);
    for (int s = 1; s <= steps; s++) {
      final t = s / steps;
      _writePt(lx + dx * t, ly + dy * t);
    }
    _lastPush = Offset(nx, ny);
  }

  void _writePt(double x, double y) {
    trail[_trailHead] = TrailPoint(x, y);
    _trailHead = (_trailHead + 1) % _kTrailLen;
  }

  void assignDriftOnRelease(Offset pixelVelocity, Size screenSize) {
    final flingX   = pixelVelocity.dx / screenSize.width;
    final flingY   = pixelVelocity.dy / screenSize.height;
    final flingMag = sqrt(flingX * flingX + flingY * flingY);
    if (flingMag < 0.04) return;
    final normX     = flingX / flingMag;
    final normY     = flingY / flingMag;
    final cappedMag = flingMag.clamp(0.0, 0.6);
    for (int i = 0; i < _kTrailLen; i++) {
      final idx = (_trailHead - 1 - i + _kTrailLen) % _kTrailLen;
      final p   = trail[idx];
      if (p.age >= 0.98) continue;
      final headness = 0.30 + 0.70 * (1.0 - (i / _kTrailLen));
      final fwdStr   = headness * cappedMag * 1.2;
      p.driftX = normX * fwdStr;
      p.driftY = normY * fwdStr;
    }
  }

  int    get trailHead  => _trailHead;
  bool   get touching   => _touching;
  Offset get touch      => _touch;
  Offset get velocity   => _velocity;
  double get touchForce => _touchForce;
  double get touchBurst => _touchBurst;

  void setTouch(Offset t)      => _touch = t;
  void setVelocity(Offset v)   => _velocity = v;
  void setTouchForce(double f) => _touchForce = f;
  void setTouchBurst(double b) => _touchBurst = b;
  void setTouching(bool v)     => _touching = v;
  void setLastPush(double x, double y) => _lastPush = Offset(x, y);
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
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF000000));
    _drawTrail(canvas, size.width, size.height);
  }

  void _drawTrail(Canvas canvas, double fw, double fh) {
    // Bigger: 0.14 → 0.19
    final auraR      = fh * 0.19;
    final touching   = engine.touching;
    final touchForce = engine.touchForce;

    const double kSkipPx = 16.0;
    double lastDrawX = -9999, lastDrawY = -9999;

    for (int i = FluidEngine._kTrailLen - 1; i >= 0; i--) {
      final idx = (engine.trailHead - 1 - i + FluidEngine._kTrailLen)
          % FluidEngine._kTrailLen;
      final p = engine.trail[idx];
      if (p.age >= 0.97) continue;

      final op = pow(1.0 - p.age, 2.2) as double;
      if (op < 0.01) continue;

      final cx = p.x * fw;
      final cy = p.y * fh;

      if (touching) {
        final ddx = cx - lastDrawX, ddy = cy - lastDrawY;
        if (ddx * ddx + ddy * ddy < kSkipPx * kSkipPx) continue;
      }
      lastDrawX = cx; lastDrawY = cy;

      final trailPos = i / FluidEngine._kTrailLen.toDouble();

      // Use touchForce directly (no touching gate) so size shrinks
      // smoothly after release instead of snapping off instantly.
      final forceSizeLift = touchForce * 0.25 * trailPos;
      final radiusMult    = 0.45 + trailPos * 0.55 + forceSizeLift;
      final r             = auraR * radiusMult;
      final pinkMix       = 0.30 + trailPos * 0.70;
      final lift          = touchForce * 0.60;

      // Gradient: first bright stop pulled in to 0.15 (was 0.28).
      // Eliminates the hollow donut on single-point touch while still
      // preventing the center-line blowout when circles stack.
      canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy), r,
            [
              const Color(0x00000000),
              Color.fromARGB(_a(op * 0.10),
                _lerp(120, 255, pinkMix), _lerp(0, 80, pinkMix), 255),
              Color.fromARGB(_a(op * (0.78 + lift)),
                _lerp(160, 255, pinkMix), _lerp(10, 60, pinkMix), 255),
              Color.fromARGB(_a(op * (0.52 + lift * 0.7)),
                _lerp(100, 220, pinkMix), _lerp(0, 40, pinkMix),
                _lerp(200, 255, pinkMix)),
              const Color(0x00000000),
            ],
            [0.0, 0.25, 0.50, 0.78, 1.0],
          ),
      );
    }
  }

  static int _a(double v) => (v * 255).clamp(0, 255).toInt();
  static int _lerp(int a, int b, double t) =>
      (a + (b - a) * t).round().clamp(0, 255);

  @override
  bool shouldRepaint(FluidPainter old) => true;
}

double mix(double a, double b, double t) => a + (b - a) * t;