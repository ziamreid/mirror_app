import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'velocity_field.dart';

class TrailPoint {
  double x, y, age;
  TrailPoint(this.x, this.y) : age = 0.0;
}

class FluidEngine {
  static const int    _kTrailLen   = 20;
  static const double _kTrailDecay = 0.10; // slow fade ~10s

  ui.Image? _bufA;
  ui.Image? _bufB;
  bool      _pingIsA = true;

  int _w = 0;
  int _h = 0;

  Offset _touch      = const Offset(0.5, 0.5);
  Offset _velocity   = Offset.zero;
  double _touchForce = 0.0;
  double _touchBurst = 0.0;

  final List<TrailPoint> trail = List.generate(
      _kTrailLen, (_) => TrailPoint(0.5, 0.5)..age = 1.0);
  int _trailHead = 0;

  final VelocityField velocityField = VelocityField();

  void tick(double dt) {
    _touchForce = (_touchForce - dt * 1.2).clamp(0.0, 1.0);
    _touchBurst = (_touchBurst - dt * 3.0).clamp(0.0, 1.0);
    _velocity   = _velocity * 0.93;
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

  void setTouch(Offset t)        => _touch = t;
  void setVelocity(Offset v)     => _velocity = v;
  void setTouchForce(double f)   => _touchForce = f;
  void setTouchBurst(double b)   => _touchBurst = b;

  Offset get touch      => _touch;
  Offset get velocity   => _velocity;
  double get touchForce => _touchForce;

  Future<ui.Image> renderFrame(Size size) async {
    final w = size.width.toInt();
    final h = size.height.toInt();

    if (_w != w || _h != h || _bufA == null || _bufB == null) {
      _w = w; _h = h;
      _bufA?.dispose();
      _bufB?.dispose();
      _bufA = await _createBlackImage(w, h);
      _bufB = await _createBlackImage(w, h);
      _pingIsA = true;
    }

    final src = _pingIsA ? _bufA! : _bufB!;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder,
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    // Step 1: carry previous frame forward with slight advection
    _drawAdvected(canvas, src, w, h);

    // Step 2: decay toward black — controls how long fluid lingers
    // 0x0A = 10/255 ≈ 4% per frame. At 60fps → ~1.5s half-life
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0x0A000000),
    );

    // Step 3: inject new ink at touch
    _injectInk(canvas, w, h);

    final picture = recorder.endRecording();
    final newImg  = await picture.toImage(w, h);
    picture.dispose();

    if (_pingIsA) {
      _bufB?.dispose();
      _bufB = newImg;
      _pingIsA = false;
    } else {
      _bufA?.dispose();
      _bufA = newImg;
      _pingIsA = true;
    }

    return _pingIsA ? _bufA! : _bufB!;
  }

  void _drawAdvected(Canvas canvas, ui.Image src, int w, int h) {
    final fw = w.toDouble();
    final fh = h.toDouble();

    // Sample velocity at touch region
    final gx = (_touch.dx * (VelocityField.kSize - 1)).clamp(0, VelocityField.kSize - 1).toInt();
    final gy = (_touch.dy * (VelocityField.kSize - 1)).clamp(0, VelocityField.kSize - 1).toInt();
    double avgVx = 0, avgVy = 0;
    int cnt = 0;
    for (int dy = -3; dy <= 3; dy++) {
      for (int dx = -3; dx <= 3; dx++) {
        final nx = (gx + dx).clamp(0, VelocityField.kSize - 1);
        final ny = (gy + dy).clamp(0, VelocityField.kSize - 1);
        avgVx += velocityField.velX[ny * VelocityField.kSize + nx];
        avgVy += velocityField.velY[ny * VelocityField.kSize + nx];
        cnt++;
      }
    }
    avgVx /= cnt;
    avgVy /= cnt;

    final pixVx = avgVx * fw * 0.6;
    final pixVy = avgVy * fh * 0.6;
    final speed = sqrt(pixVx * pixVx + pixVy * pixVy);

    // Base frame — full opacity, no displacement
    canvas.drawImage(src, Offset.zero, Paint());

    if (speed < 0.8) return;

    // Smooth ghost advection — NO grid, just full-image offsets
    // Fewer steps, lower opacity to avoid blowout
    const int steps = 4;
    for (int s = 1; s <= steps; s++) {
      final t  = s / steps.toDouble();
      final op = 0.18 * (1.0 - t * 0.5); // max 18% per ghost → total ~50%
      final dx = pixVx * t * 0.20;
      final dy = pixVy * t * 0.20;
      canvas.drawImage(
        src,
        Offset(dx, dy),
        Paint()
          ..color     = Color.fromARGB((op * 255).round(), 255, 255, 255)
          ..blendMode = BlendMode.srcOver, // srcOver not plus — no blowout
      );
    }
  }

  void _injectInk(Canvas canvas, int w, int h) {
    final fw = w.toDouble();
    final fh = h.toDouble();

    // Trail segments — controlled size, no additive blowout
    for (int i = 0; i < _kTrailLen - 1; i++) {
      final a = trail[i];
      final b = trail[(i + 1) % _kTrailLen];
      if (a.age >= 1.0 && b.age >= 1.0) continue;

      final age = (a.age + b.age) * 0.5;
      final op  = pow(1.0 - age.clamp(0.0, 1.0), 1.6) as double;

      // Radius: matches Framer — blobs are 8-12% of screen height, not 20%+
      final r = mix(fh * 0.10, fh * 0.03, age);

      final ax = a.x * fw;
      final ay = a.y * fh;
      final bx = b.x * fw;
      final by = b.y * fh;

      // Outer haze — very transparent, large soft edge
      canvas.drawLine(Offset(ax, ay), Offset(bx, by),
        Paint()
          ..blendMode  = BlendMode.plus
          ..strokeWidth = r * 2.2
          ..strokeCap  = StrokeCap.round
          ..style      = PaintingStyle.stroke
          ..shader     = ui.Gradient.linear(
            Offset(ax, ay), Offset(bx, by),
            [
              Color.fromARGB((op * 55).clamp(0, 255).toInt(),  80, 10, 200),
              Color.fromARGB((op * 45).clamp(0, 255).toInt(),  60,  5, 180),
            ],
          ),
      );

      // Mid body — the main visible fluid color
      canvas.drawLine(Offset(ax, ay), Offset(bx, by),
        Paint()
          ..blendMode  = BlendMode.plus
          ..strokeWidth = r * 1.2
          ..strokeCap  = StrokeCap.round
          ..style      = PaintingStyle.stroke
          ..shader     = ui.Gradient.linear(
            Offset(ax, ay), Offset(bx, by),
            [
              Color.fromARGB((op * 130).clamp(0, 255).toInt(), 140, 40, 255),
              Color.fromARGB((op * 110).clamp(0, 255).toInt(), 110, 20, 220),
            ],
          ),
      );

      // Bright core spine
      canvas.drawLine(Offset(ax, ay), Offset(bx, by),
        Paint()
          ..blendMode  = BlendMode.plus
          ..strokeWidth = r * 0.45
          ..strokeCap  = StrokeCap.round
          ..style      = PaintingStyle.stroke
          ..shader     = ui.Gradient.linear(
            Offset(ax, ay), Offset(bx, by),
            [
              Color.fromARGB((op * 200).clamp(0, 255).toInt(), 210, 160, 255),
              Color.fromARGB((op * 180).clamp(0, 255).toInt(), 190, 130, 255),
            ],
          ),
      );
    }

    // Live finger — the hot injection point
    if (_touchForce > 0.01) {
      final fx = _touch.dx * fw;
      final fy = _touch.dy * fh;
      // Finger blob radius: ~9% of screen height — NOT 18-20%
      final r = fh * 0.09 * _touchForce;

      // Outer soft haze
      canvas.drawCircle(Offset(fx, fy), r * 2.0,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), r * 2.0,
            [
              Color.fromARGB((_touchForce * 40).toInt(), 100, 20, 220),
              const Color(0x00000000),
            ],
          ),
      );

      // Main body
      canvas.drawCircle(Offset(fx, fy), r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), r,
            [
              Color.fromARGB((_touchForce * 160).toInt(), 170, 80, 255),
              Color.fromARGB((_touchForce * 60).toInt(),  80, 10, 200),
              const Color(0x00000000),
            ],
            [0.0, 0.6, 1.0],
          ),
      );

      // Hot bright core — tiny, punchy
      canvas.drawCircle(Offset(fx, fy), r * 0.30,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), r * 0.30,
            [
              Color.fromARGB((_touchForce * 230).toInt(), 230, 190, 255),
              const Color(0x00000000),
            ],
          ),
      );

      // Velocity streak — elongated smear in drag direction
      final vel    = _velocity;
      final velMag = sqrt(vel.dx * vel.dx + vel.dy * vel.dy);
      if (velMag > 0.0008) {
        final nx = vel.dx / velMag;
        final ny = vel.dy / velMag;
        // Streak length proportional to speed but capped
        final streakLen = (velMag * fw * 5.0).clamp(0.0, fh * 0.35);

        // Outer streak haze
        canvas.drawLine(
          Offset(fx, fy),
          Offset(fx + nx * streakLen, fy + ny * streakLen),
          Paint()
            ..blendMode  = BlendMode.plus
            ..strokeWidth = r * 1.6
            ..strokeCap  = StrokeCap.round
            ..style      = PaintingStyle.stroke
            ..shader     = ui.Gradient.linear(
              Offset(fx, fy),
              Offset(fx + nx * streakLen, fy + ny * streakLen),
              [
                Color.fromARGB((_touchForce * 60).toInt(), 120, 40, 240),
                const Color(0x00000000),
              ],
            ),
        );

        // Bright streak core
        canvas.drawLine(
          Offset(fx, fy),
          Offset(fx + nx * streakLen, fy + ny * streakLen),
          Paint()
            ..blendMode  = BlendMode.plus
            ..strokeWidth = r * 0.55
            ..strokeCap  = StrokeCap.round
            ..style      = PaintingStyle.stroke
            ..shader     = ui.Gradient.linear(
              Offset(fx, fy),
              Offset(fx + nx * streakLen, fy + ny * streakLen),
              [
                Color.fromARGB((_touchForce * 190).toInt(), 210, 160, 255),
                const Color(0x00000000),
              ],
            ),
        );
      }
    }

    // Touch-down burst — radial flash, fades fast
    if (_touchBurst > 0.02) {
      final fx = _touch.dx * fw;
      final fy = _touch.dy * fh;
      final r  = fh * 0.18 * _touchBurst;
      canvas.drawCircle(Offset(fx, fy), r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), r,
            [
              Color.fromARGB(
                  (_touchBurst * _touchBurst * 100).clamp(0, 255).toInt(),
                  190, 140, 255),
              const Color(0x00000000),
            ],
          ),
      );
    }
  }

  Future<ui.Image> _createBlackImage(int w, int h) async {
    final rec = ui.PictureRecorder();
    final c   = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = const Color(0xFF000000));
    final pic = rec.endRecording();
    final img = await pic.toImage(w, h);
    pic.dispose();
    return img;
  }

  void dispose() {
    _bufA?.dispose();
    _bufB?.dispose();
    _bufA = null;
    _bufB = null;
  }
}

double mix(double a, double b, double t) => a + (b - a) * t;

class FluidPainter extends CustomPainter {
  final ui.Image? displayImage;

  FluidPainter({required this.displayImage, required Listenable repaint})
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );
    if (displayImage != null) {
      canvas.drawImage(displayImage!, Offset.zero, Paint());
    }
  }

  @override
  bool shouldRepaint(FluidPainter old) => old.displayImage != displayImage;
}