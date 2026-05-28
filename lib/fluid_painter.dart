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
    final auraR   = fh * 0.22;
    final bool touching = engine.touching;

    const double kSkipPx = 12.0;
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

      // Original: i=_kTrailLen-1 is oldest (tail, small)
      //           i=0 is newest (head, big)
      // trailPos goes 0→1 as i goes 0→_kTrailLen-1
      // So trailPos=0 at head, trailPos=1 at tail
      // radiusMult = 0.40 + trailPos*0.60 → head=0.40, tail=1.0 ← WRONG
      // 
      // Wait — the ORIGINAL from the document used exactly this and it worked.
      // The reason: the loop draws i=79 first (tail) and i=0 last (head).
      // idx formula: i=79 → trailHead-80 = oldest. i=0 → trailHead-1 = newest.
      // So newest point (head/finger) has i=0, trailPos=0, radiusMult=0.40 (SMALL).
      // Oldest point (tail) has i=79, trailPos≈1, radiusMult=1.0 (BIG).
      // That means tail is BIG and head is SMALL — which IS the teardrop.
      //
      // BUT the original worked beautifully. Why? Because while DRAGGING,
      // the head is always at the finger and keeps getting NEW points written.
      // The "tail" points are old and already fading (op very low).
      // So visually the head GLOWS brighter even if radius is smaller.
      // The glow brightness compensates for the radius difference.
      //
      // The teardrop we see now is because we changed _kTrailDecay to 0.028
      // (slower decay) so tail points stay bright AND big = visible teardrop.
      //
      // REAL FIX: restore original _kTrailDecay = 0.050 so tail fades fast
      // and isn't visible long enough to form the teardrop shape.
      final trailPos   = i / FluidEngine._kTrailLen.toDouble();
      final radiusMult = 0.40 + trailPos * 0.60;
      final r          = auraR * radiusMult;
      final pinkMix    = 0.30 + trailPos * 0.70;

      canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader    = ui.Gradient.radial(
            Offset(cx, cy), r,
            [
              const Color(0x00000000),
              Color.fromARGB(_a(op * 0.55),
                _lerp(120, 255, pinkMix), _lerp(0, 80, pinkMix), 255),
              Color.fromARGB(_a(op * 0.85),
                _lerp(160, 255, pinkMix), _lerp(10, 60, pinkMix), 255),
              Color.fromARGB(_a(op * 0.45),
                _lerp(60, 180, pinkMix), _lerp(0, 20, pinkMix),
                _lerp(200, 255, pinkMix)),
              const Color(0x00000000),
            ],
            [0.0, 0.12, 0.32, 0.65, 1.0],
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