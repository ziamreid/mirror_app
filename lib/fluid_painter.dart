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
  static const int    kTrailLen   = 80;
  static const double kTrailDecay = 0.07;
  static const double kMinDist    = 0.007;

  Offset _touch      = const Offset(0.5, 0.5);
  Offset _lastPush   = const Offset(-1, -1);
  Offset _velocity   = Offset.zero;
  double _touchForce = 1.0;
  double _touchBurst = 0.0;
  bool   _touching   = false;
  double _speed      = 0.0;

  final List<TrailPoint> trail = List.generate(
      kTrailLen, (_) => TrailPoint(0.5, 0.35)..age = 0.0);
  int _trailHead = 0;

  final VelocityField velocityField = VelocityField();

  void trailHeadSet(int v) => _trailHead = v % kTrailLen;

  void forceTrailPoint(double x, double y) {
    trail[_trailHead] = TrailPoint(x, y)..age = 0.0;
    _trailHead = (_trailHead + 1) % kTrailLen;
    _lastPush  = Offset(x, y);
  }

  void tick(double dt) {
    if (_touching) {
      _touchForce = 1.0;
    } else {
      _touchForce = (_touchForce - dt * 1.2).clamp(0.0, 1.0);
      _speed      = (_speed - dt * 8.0).clamp(0.0, 1.0);
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
        p.age = (p.age + dt * kTrailDecay).clamp(0.0, 1.0);
      }
    } else {
      for (int i = 0; i < kTrailLen; i++) {
        final idx = (_trailHead - 1 - i + kTrailLen) % kTrailLen;
        final p   = trail[idx];
        if (p.age >= 1.0) continue;
        final trailPos   = i / (kTrailLen - 1).toDouble();
        final pointDecay = kTrailDecay * 10.0 * (1.0 + trailPos * 3.0);
        p.age = (p.age + dt * pointDecay).clamp(0.0, 1.0);
      }
    }
  }

  void resetTrail(double nx, double ny) {
    for (final p in trail) {
      p.x = nx; p.y = ny; p.age = 1.0;
      p.driftX = 0.0; p.driftY = 0.0;
    }
    _trailHead = 0;
    _lastPush  = Offset(nx, ny);
    for (int i = 0; i < 28; i++) {
      trail[i] = TrailPoint(nx, ny)..age = 0.0;
    }
    _trailHead = 28;
    _speed = 0.0;
  }

  void pushTrailDense(double nx, double ny) {
    final lx = _lastPush.dx;
    final ly = _lastPush.dy;
    if (lx < 0) { forceTrailPoint(nx, ny); return; }
    final dx = nx - lx, dy = ny - ly;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < kMinDist) return;
    _speed = (_speed + dist * 12.0).clamp(0.0, 1.0);
    final steps = (dist / kMinDist).ceil().clamp(1, 20);
    for (int s = 1; s <= steps; s++) {
      final t = s / steps;
      _writePt(lx + dx * t, ly + dy * t);
    }
    _lastPush = Offset(nx, ny);
  }

  void _writePt(double x, double y) {
    trail[_trailHead] = TrailPoint(x, y);
    _trailHead = (_trailHead + 1) % kTrailLen;
  }

  void assignDriftOnRelease(Offset pixelVelocity, Size screenSize) {
    final flingX   = pixelVelocity.dx / screenSize.width;
    final flingY   = pixelVelocity.dy / screenSize.height;
    final flingMag = sqrt(flingX * flingX + flingY * flingY);
    if (flingMag < 0.04) return;
    final normX     = flingX / flingMag;
    final normY     = flingY / flingMag;
    final cappedMag = flingMag.clamp(0.0, 0.6);
    for (int i = 0; i < kTrailLen; i++) {
      final idx = (_trailHead - 1 - i + kTrailLen) % kTrailLen;
      final p   = trail[idx];
      if (p.age >= 0.98) continue;
      final headness = 0.30 + 0.70 * (1.0 - (i / kTrailLen));
      final fwdStr   = headness * cappedMag * 1.2;
      p.driftX = normX * fwdStr;
      p.driftY = normY * fwdStr;
    }
  }

  Offset get orbCenter {
    final idx = (_trailHead - 1 + kTrailLen) % kTrailLen;
    return Offset(trail[idx].x, trail[idx].y);
  }

  double get orbX      => orbCenter.dx;
  double get orbY      => orbCenter.dy;
  double get speed     => _speed;
  int    get trailHead => _trailHead;
  bool   get touching  => _touching;
  Offset get touch     => _touch;
  Offset get velocity  => _velocity;
  double get touchForce => _touchForce;
  double get touchBurst => _touchBurst;

  void setTouch(Offset t)              => _touch = t;
  void setVelocity(Offset v)           => _velocity = v;
  void setTouchForce(double f)         => _touchForce = f;
  void setTouchBurst(double b)         => _touchBurst = b;
  void setTouching(bool v)             => _touching = v;
  void setLastPush(double x, double y) => _lastPush = Offset(x, y);
}

class FluidPainter extends CustomPainter {
  final FluidEngine engine;
  final Size        screenSize;
  final double      teleportFade;

  FluidPainter({
    required this.engine,
    required this.screenSize,
    required Listenable repaint,
    this.teleportFade = 1.0,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );
    if (teleportFade <= 0.001) return;
    _drawTrail(canvas, size.width, size.height);
  }

  void _drawTrail(Canvas canvas, double fw, double fh) {
    // Slightly larger than before: 0.16 (was 0.13, original was 0.21)
    // Sweet spot — visible but not bleeding over cards
    final baseR      = fh * 0.16;
    final speedBoost = 1.0 + engine.speed * 0.25;
    final auraR      = baseR * speedBoost;

    const double kSkipPx = 10.0;
    double lastDrawX = -9999, lastDrawY = -9999;

    for (int i = FluidEngine.kTrailLen - 1; i >= 0; i--) {
      final idx = (engine.trailHead - 1 - i + FluidEngine.kTrailLen)
          % FluidEngine.kTrailLen;
      final p = engine.trail[idx];
      if (p.age >= 0.97) continue;

      final op = (pow(1.0 - p.age, 2.8) as double) * teleportFade;
      if (op < 0.01) continue;

      final cx = p.x * fw;
      final cy = p.y * fh;

      if (engine.touching) {
        final ddx = cx - lastDrawX, ddy = cy - lastDrawY;
        if (ddx * ddx + ddy * ddy < kSkipPx * kSkipPx) continue;
      }
      lastDrawX = cx; lastDrawY = cy;

      final trailPos   = i / FluidEngine.kTrailLen.toDouble();
      final radiusMult = 0.50 + trailPos * 0.55;
      final r          = auraR * radiusMult;
      final pinkMix    = 0.25 + trailPos * 0.75;

      canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy), r,
            [
              const Color(0x00000000),
              Color.fromARGB(_a(op * 0.18), _lerp(100, 240, pinkMix), _lerp(0, 70,  pinkMix), 255),
              Color.fromARGB(_a(op * 0.88), _lerp(150, 255, pinkMix), _lerp(0, 50,  pinkMix), 255),
              Color.fromARGB(_a(op * 0.60), _lerp(90,  210, pinkMix), _lerp(0, 30,  pinkMix), _lerp(210, 255, pinkMix)),
              const Color(0x00000000),
            ],
            [0.0, 0.20, 0.48, 0.75, 1.0],
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