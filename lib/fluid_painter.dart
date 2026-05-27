import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'velocity_field.dart';

final _rng = Random();

class TrailPoint {
  double x, y, age;
  // Per-point drift assigned on release — gives each point unique movement
  double driftX = 0.0;
  double driftY = 0.0;

  TrailPoint(this.x, this.y) : age = 0.0;
}

class FluidEngine {
  static const int    _kTrailLen   = 120;
  static const double _kTrailDecay = 0.055;
  static const double _kMinDist    = 0.009;

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
      // Move each trail point by its own assigned drift
      for (final p in trail) {
        if (p.age < 0.98) {
          p.x = (p.x + p.driftX * dt).clamp(0.0, 1.0);
          p.y = (p.y + p.driftY * dt).clamp(0.0, 1.0);
          // Friction — drift decays over time
          p.driftX *= 0.90;
          p.driftY *= 0.90;
        }
      }
    }

    final baseDecay = _touching ? _kTrailDecay : _kTrailDecay * 6.0;

    if (_touching) {
      // While dragging: uniform decay
      for (final p in trail) {
        p.age = (p.age + dt * baseDecay).clamp(0.0, 1.0);
      }
    } else {
      // After release: tail dies first, head lingers last
      // i=0 in draw loop = newest (head), i=_kTrailLen-1 = oldest (tail)
      for (int i = 0; i < _kTrailLen; i++) {
        // Map draw-loop index to actual trail array index
        final idx = (_trailHead - 1 - i + _kTrailLen) % _kTrailLen;
        final p = trail[idx];
        if (p.age >= 1.0) continue;
        // trailPos: 0.0=head(newest), 1.0=tail(oldest)
        final trailPos = i / (_kTrailLen - 1).toDouble();
        // tail decays 8x faster than head → tail gone first, head lingers
        final pointDecay = baseDecay * (1.0 + trailPos * 7.0);
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

    if (lx < 0) {
      _writePt(nx, ny);
      _lastPush = Offset(nx, ny);
      return;
    }

    final dx   = nx - lx;
    final dy   = ny - ly;
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

  /// Called on release — assigns per-point drift implementing Option C:
  /// - Newer points (low index from head) get strong forward momentum (comet head)
  /// - Older points get turbulent outward scatter (tail dissolves)
  void assignDriftOnRelease(Offset pixelVelocity, Size screenSize) {
    // Normalize fling direction
    final flingX = pixelVelocity.dx / screenSize.width;
    final flingY = pixelVelocity.dy / screenSize.height;
    final flingMag = sqrt(flingX * flingX + flingY * flingY);
    final hasFling = flingMag > 0.05;
    final normX = hasFling ? flingX / flingMag : 0.0;
    final normY = hasFling ? flingY / flingMag : 0.0;

    for (int i = 0; i < _kTrailLen; i++) {
      final idx = (_trailHead - 1 - i + _kTrailLen) % _kTrailLen;
      final p = trail[idx];
      if (p.age >= 0.98) continue;

      // i=0 → newest (head), i=_kTrailLen-1 → oldest (tail)
      final normalizedAge = i / _kTrailLen; // 0.0=head, 1.0=tail

      // === OPTION A: Comet head — forward momentum, stronger for newer points ===
      final forwardStrength = (1.0 - normalizedAge) * (hasFling ? flingMag * 0.5 : 0.0);
      final forwardX = normX * forwardStrength;
      final forwardY = normY * forwardStrength;

      // === OPTION B: Turbulent scatter — stronger for older points ===
      final scatterStrength = normalizedAge * 0.08;
      final angle = _rng.nextDouble() * 2 * pi;
      final scatterX = cos(angle) * scatterStrength;
      final scatterY = sin(angle) * scatterStrength;

      // === OPTION C: Blend both ===
      p.driftX = forwardX + scatterX;
      p.driftY = forwardY + scatterY;
    }
  }

  // expose for drift assignment loop
  int get trailHead => _trailHead;

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
  }

  void _drawTrail(Canvas canvas, double fw, double fh) {
    // One single draw call per point — aura+mid+core baked into one gradient
    // 3x less GPU work vs separate layers, same visual quality
    const double auraFrac = 0.28;
    final auraR = fh * auraFrac;

    for (int i = FluidEngine._kTrailLen - 1; i >= 0; i--) {
      final idx = (engine.trailHead - 1 - i + FluidEngine._kTrailLen)
          % FluidEngine._kTrailLen;
      final p = engine.trail[idx];
      if (p.age >= 0.98) continue;

      final t  = p.age.clamp(0.0, 1.0);
      final op = pow(1.0 - t, 2.5) as double;
      if (op < 0.008) continue;

      final cx = p.x * fw;
      final cy = p.y * fh;

      // Position in trail: 0.0 = newest (head), 1.0 = oldest (tail)
      final trailPos = i / FluidEngine._kTrailLen.toDouble();
      // Aggressive taper: head is full size, tail tapers to nothing
      final radiusMult = pow(1.0 - trailPos, 0.5) as double;
      final r = auraR * (0.05 + radiusMult * 0.95);
      // Kill dot artifact: skip any point that is visually too small to look good
      if (r < auraR * 0.18) continue;

      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy),
            r,
            [
              Color.fromARGB(_a(op * 1.00), 255, 220, 255), // white-pink core
              Color.fromARGB(_a(op * 0.90), 220, 100, 255), // bright violet
              Color.fromARGB(_a(op * 0.55), 160,  40, 255), // mid purple
              Color.fromARGB(_a(op * 0.20),  70,   5, 200), // deep aura
              Color.fromARGB(_a(op * 0.08),  40,   0, 140), // outer glow
              const Color(0x00000000),                       // transparent edge
            ],
            [0.0, 0.08, 0.20, 0.45, 0.70, 1.0],
          ),
      );
    }
  }

  static int _a(double v) => (v * 255).clamp(0, 255).toInt();

  @override
  bool shouldRepaint(FluidPainter old) => true;
}

double mix(double a, double b, double t) => a + (b - a) * t;