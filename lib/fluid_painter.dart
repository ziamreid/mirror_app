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
      for (int i = 0; i < _kTrailLen; i++) {
        final idx = (_trailHead - 1 - i + _kTrailLen) % _kTrailLen;
        final p   = trail[idx];
        if (p.age >= 1.0) continue;
        final trailPos   = i / (_kTrailLen - 1).toDouble();
        final pointDecay = _kTrailDecay * 4.0 * (1.0 + trailPos * 3.5);
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
    final hasFling = flingMag > 0.05;
    final normX    = hasFling ? flingX / flingMag : 0.0;
    final normY    = hasFling ? flingY / flingMag : 0.0;

    for (int i = 0; i < _kTrailLen; i++) {
      final idx = (_trailHead - 1 - i + _kTrailLen) % _kTrailLen;
      final p   = trail[idx];
      if (p.age >= 0.98) continue;
      final norm    = i / _kTrailLen;
      final fwdStr  = (1.0 - norm) * (hasFling ? flingMag * 0.5 : 0.0);
      final scatStr = norm * 0.06;
      final angle   = _rng.nextDouble() * 2 * pi;
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

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

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
    final int    len     = FluidEngine._kTrailLen;
    final int    head    = engine.trailHead;
    final double baseR   = fh * 0.20; // slightly smaller overall

    for (int i = len - 1; i >= 0; i--) {
      final idx = (head - 1 - i + len) % len;
      final p   = engine.trail[idx];
      if (p.age >= 0.97) continue;

      // trailPos: 0.0 = oldest/tail, 1.0 = newest/head
      final trailPos = i / (len - 1).toDouble();
      final op       = pow(1.0 - p.age, 2.2) as double;
      if (op < 0.01) continue;

      final cx = p.x * fw;
      final cy = p.y * fh;

      // ── #2 Subtle width pulse — feels alive, not static ─────────────────
      final pulse     = 1.0 + sin(trailPos * 18.0) * 0.04;

      // ── #3 Explosive head — tip is 1.45× wider and brighter ─────────────
      final headBoost = trailPos > 0.85
          ? 1.0 + (trailPos - 0.85) / 0.15 * 0.45
          : 1.0;

      final sizeMult  = (0.35 + trailPos * 0.65) * pulse * headBoost;

      // ── #4 Asymmetric falloff — wide soft halo + tight bright core ───────
      final haloR = baseR * sizeMult;          // wide outer halo
      final coreR = baseR * sizeMult * 0.22;   // tight inner core

      // ── #1 Color temperature shift along trail ───────────────────────────
      // tail: deep indigo → mid: violet-purple → head: hot white-pink
      final headness = trailPos; // 0=tail, 1=head

      // Halo colors shift indigo → violet → pink
      final haloR1 = _lerpInt(30,  150, headness);   // red channel
      final haloG1 = _lerpInt(5,   40,  headness);   // green channel
      final haloB1 = _lerpInt(180, 255, headness);   // blue channel

      final haloMidR = _lerpInt(80,  210, headness);
      final haloMidG = _lerpInt(10,  80,  headness);
      final haloMidB = _lerpInt(220, 255, headness);

      // Pass 1: Wide outer halo — transparent center blooms at ~20% radius
      canvas.drawCircle(
        Offset(cx, cy), haloR,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy), haloR,
            [
              const Color(0x00000000),
              Color.fromARGB(_a(op * 0.45), haloR1,      haloG1,      haloB1),
              Color.fromARGB(_a(op * 0.70), haloMidR,    haloMidG,    haloMidB),
              Color.fromARGB(_a(op * 0.35), haloMidR~/2, haloMidG~/2, haloB1),
              const Color(0x00000000),
            ],
            [0.0, 0.18, 0.38, 0.68, 1.0],
          ),
      );

      // Pass 2: Tight bright core — white-hot at head, violet at tail
      final coreHotR = _lerpInt(180, 255, headness);
      final coreHotG = _lerpInt(60,  210, headness);
      final coreHotB = 255;
      final coreOpScale = 0.65 + headness * 0.35; // head glows harder

      canvas.drawCircle(
        Offset(cx, cy), coreR,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy), coreR,
            [
              Color.fromARGB(_a(op * coreOpScale), coreHotR, coreHotG, coreHotB),
              Color.fromARGB(_a(op * coreOpScale * 0.5), haloMidR, haloMidG, haloMidB),
              const Color(0x00000000),
            ],
            [0.0, 0.55, 1.0],
          ),
      );
    }

    // ── #3 Extra explosive burst at the very tip (head 4 points) ────────────
    for (int i = len - 1; i >= len - 5; i--) {
      if (i < 0) continue;
      final idx = (head - 1 - i + len) % len;
      final p   = engine.trail[idx];
      if (p.age >= 0.90) continue;

      final op        = pow(1.0 - p.age, 1.8) as double;
      final trailPos  = i / (len - 1).toDouble();
      final burstStr  = (trailPos - 0.80) / 0.20; // 0→1 over last 4 pts
      final burstR    = baseR * 0.55 * burstStr;

      final cx = p.x * fw;
      final cy = p.y * fh;

      canvas.drawCircle(
        Offset(cx, cy), burstR,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy), burstR,
            [
              Color.fromARGB(_a(op * 0.90), 255, 230, 255),
              Color.fromARGB(_a(op * 0.50), 220, 120, 255),
              const Color(0x00000000),
            ],
            [0.0, 0.45, 1.0],
          ),
      );
    }
  }

  static int _a(double v) => (v * 255).clamp(0, 255).toInt();
  static int _lerpInt(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);

  @override
  bool shouldRepaint(FluidPainter old) => true;
}

double mix(double a, double b, double t) => a + (b - a) * t;