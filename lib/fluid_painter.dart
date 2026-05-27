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
  static const int    _kTrailLen   = 60;
  static const double _kTrailDecay = 0.055;
  static const double _kMinDist    = 0.010;

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
    _touchForce = (_touchForce - dt * 2.0).clamp(0.0, 1.0);
    _touchBurst = (_touchBurst - dt * 4.0).clamp(0.0, 1.0);
    _velocity   = _velocity * 0.88;

    if (!_touching) {
      for (final p in trail) {
        if (p.age < 0.98) {
          p.x = (p.x + p.driftX * dt).clamp(0.0, 1.0);
          p.y = (p.y + p.driftY * dt).clamp(0.0, 1.0);
          p.driftX *= 0.88;
          p.driftY *= 0.88;
        }
      }
    }

    if (_touching) {
      for (final p in trail) {
        p.age = (p.age + dt * _kTrailDecay).clamp(0.0, 1.0);
      }
    } else {
      // Tail dies first (trailPos=1.0 → fastest), head lingers (trailPos=0.0 → slowest)
      // Uses OPACITY-based fade only — no radius shrinking on release = no dots
      for (int i = 0; i < _kTrailLen; i++) {
        final idx = (_trailHead - 1 - i + _kTrailLen) % _kTrailLen;
        final p   = trail[idx];
        if (p.age >= 1.0) continue;
        final trailPos  = i / (_kTrailLen - 1).toDouble(); // 0=head,1=tail
        final pointDecay = _kTrailDecay * 4.0 * (1.0 + trailPos * 3.0);
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
  }

  void pushTrailDense(double nx, double ny) {
    final lx = _lastPush.dx;
    final ly = _lastPush.dy;
    if (lx < 0) { _writePt(nx, ny); _lastPush = Offset(nx, ny); return; }
    final dx = nx - lx, dy = ny - ly;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < _kMinDist) return;
    final steps = (dist / _kMinDist).ceil().clamp(1, 15);
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
    final hasFling = flingMag > 0.05;
    final normX    = hasFling ? flingX / flingMag : 0.0;
    final normY    = hasFling ? flingY / flingMag : 0.0;

    for (int i = 0; i < _kTrailLen; i++) {
      final idx = (_trailHead - 1 - i + _kTrailLen) % _kTrailLen;
      final p   = trail[idx];
      if (p.age >= 0.98) continue;
      final norm       = i / _kTrailLen;
      final fwdStr     = (1.0 - norm) * (hasFling ? flingMag * 0.5 : 0.0);
      final scatStr    = norm * 0.06;
      final angle      = _rng.nextDouble() * 2 * pi;
      p.driftX = normX * fwdStr + cos(angle) * scatStr;
      p.driftY = normY * fwdStr + sin(angle) * scatStr;
    }
  }

  int    get trailHead  => _trailHead;
  Offset get touch      => _touch;
  Offset get velocity   => _velocity;
  double get touchForce => _touchForce;
  double get touchBurst => _touchBurst;

  void setTouch(Offset t)      => _touch = t;
  void setVelocity(Offset v)   => _velocity = v;
  void setTouchForce(double f) => _touchForce = f;
  void setTouchBurst(double b) => _touchBurst = b;
  void setTouching(bool v)     => _touching = v;
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
    final auraR = fh * 0.26; // full-size radius

    for (int i = FluidEngine._kTrailLen - 1; i >= 0; i--) {
      final idx = (engine.trailHead - 1 - i + FluidEngine._kTrailLen)
          % FluidEngine._kTrailLen;
      final p = engine.trail[idx];
      if (p.age >= 0.97) continue;

      // Opacity only — fades gracefully, never becomes a dot
      final op = pow(1.0 - p.age, 2.2) as double;
      if (op < 0.01) continue;

      // Radius tapers from head to tail — but NEVER below 40% so no dots
      // Only opacity reaches 0, radius stays large enough to be invisible not dotty
      final trailPos   = i / FluidEngine._kTrailLen.toDouble();
      final radiusMult = 0.40 + (1.0 - trailPos) * 0.60; // 0.40(tail) → 1.0(head)
      final r          = auraR * radiusMult;

      final cx = p.x * fw;
      final cy = p.y * fh;

      canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy), r,
            [
              Color.fromARGB(_a(op * 1.00), 255, 215, 255),
              Color.fromARGB(_a(op * 0.85), 210,  80, 255),
              Color.fromARGB(_a(op * 0.45), 140,  30, 230),
              Color.fromARGB(_a(op * 0.12),  60,   5, 180),
              const Color(0x00000000),
            ],
            [0.0, 0.10, 0.30, 0.60, 1.0],
          ),
      );
    }
  }

  static int _a(double v) => (v * 255).clamp(0, 255).toInt();

  @override
  bool shouldRepaint(FluidPainter old) => true;
}

double mix(double a, double b, double t) => a + (b - a) * t;