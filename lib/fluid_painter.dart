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
  static const int    _kTrailLen   = 24;
  static const double _kTrailDecay = 0.055;

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
    _touchForce = (_touchForce - dt * 1.5).clamp(0.0, 1.0);
    _touchBurst = (_touchBurst - dt * 4.0).clamp(0.0, 1.0);
    _velocity   = _velocity * 0.90;
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

    _drawAdvected(canvas, src, w, h);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0x08000000),
    );

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

    final gx = (_touch.dx * (VelocityField.kSize - 1)).clamp(0, VelocityField.kSize - 1).toInt();
    final gy = (_touch.dy * (VelocityField.kSize - 1)).clamp(0, VelocityField.kSize - 1).toInt();
    double avgVx = 0, avgVy = 0;
    int cnt = 0;
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        final nx = (gx + dx).clamp(0, VelocityField.kSize - 1);
        final ny = (gy + dy).clamp(0, VelocityField.kSize - 1);
        avgVx += velocityField.velX[ny * VelocityField.kSize + nx];
        avgVy += velocityField.velY[ny * VelocityField.kSize + nx];
        cnt++;
      }
    }
    avgVx /= cnt;
    avgVy /= cnt;

    final pixVx = avgVx * fw * 0.5;
    final pixVy = avgVy * fh * 0.5;
    final speed = sqrt(pixVx * pixVx + pixVy * pixVy);

    canvas.drawImage(src, Offset.zero, Paint());

    if (speed < 0.5) return;

    const int steps = 5;
    for (int s = 1; s <= steps; s++) {
      final t  = s / steps.toDouble();
      final op = 0.12 * (1.0 - t * 0.6);
      final dx = pixVx * t * 0.18;
      final dy = pixVy * t * 0.18;
      canvas.drawImage(
        src,
        Offset(dx, dy),
        Paint()
          ..color     = Color.fromARGB((op * 255).round(), 255, 255, 255)
          ..blendMode = BlendMode.srcOver,
      );
    }
  }

  void _injectInk(Canvas canvas, int w, int h) {
    final fw = w.toDouble();
    final fh = h.toDouble();

    for (int i = 0; i < _kTrailLen; i++) {
      final p = trail[i];
      if (p.age >= 1.0) continue;

      final ageCurved = p.age * p.age;
      final op = (1.0 - ageCurved).clamp(0.0, 1.0);
      final r  = fh * mix(0.11, 0.022, p.age);
      final px = p.x * fw;
      final py = p.y * fh;

      // NO MaskFilter.blur, NO BlendMode.plus anywhere
      // Soft edge comes purely from the radial gradient stopping at 0x00

      // Outer aura
      canvas.drawCircle(
        Offset(px, py),
        r * 2.4,
        Paint()
          ..blendMode = BlendMode.srcOver
          ..shader    = ui.Gradient.radial(
            Offset(px, py), r * 2.4,
            [
              Color.fromARGB((op * 28).clamp(0, 255).toInt(),  90, 15, 200),
              Color.fromARGB((op * 10).clamp(0, 255).toInt(),  60, 10, 160),
              const Color(0x00000000),
            ],
            [0.0, 0.5, 1.0],
          ),
      );

      // Main glow body
      canvas.drawCircle(
        Offset(px, py),
        r * 1.2,
        Paint()
          ..blendMode = BlendMode.srcOver
          ..shader    = ui.Gradient.radial(
            Offset(px, py), r * 1.2,
            [
              Color.fromARGB((op * 160).clamp(0, 255).toInt(), 180, 60, 255),
              Color.fromARGB((op * 80).clamp(0, 255).toInt(),  120, 20, 220),
              Color.fromARGB((op * 20).clamp(0, 255).toInt(),   80, 10, 180),
              const Color(0x00000000),
            ],
            [0.0, 0.4, 0.75, 1.0],
          ),
      );

      // Bright core
      canvas.drawCircle(
        Offset(px, py),
        r * 0.38,
        Paint()
          ..blendMode = BlendMode.srcOver
          ..shader    = ui.Gradient.radial(
            Offset(px, py), r * 0.38,
            [
              Color.fromARGB((op * 220).clamp(0, 255).toInt(), 235, 190, 255),
              Color.fromARGB((op * 80).clamp(0, 255).toInt(),  180,  60, 255),
              const Color(0x00000000),
            ],
            [0.0, 0.6, 1.0],
          ),
      );
    }

    // ── Live finger blob ─────────────────────────────────────────────────────
    if (_touchForce > 0.01) {
      final fx = _touch.dx * fw;
      final fy = _touch.dy * fh;
      final r  = fh * 0.088 * _touchForce;

      canvas.drawCircle(
        Offset(fx, fy),
        r * 3.0,
        Paint()
          ..blendMode = BlendMode.srcOver
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), r * 3.0,
            [
              Color.fromARGB((_touchForce * 25).clamp(0, 255).toInt(), 110, 25, 230),
              Color.fromARGB((_touchForce *  8).clamp(0, 255).toInt(),  80, 15, 180),
              const Color(0x00000000),
            ],
            [0.0, 0.5, 1.0],
          ),
      );

      canvas.drawCircle(
        Offset(fx, fy),
        r * 1.1,
        Paint()
          ..blendMode = BlendMode.srcOver
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), r * 1.1,
            [
              Color.fromARGB((_touchForce * 180).clamp(0, 255).toInt(), 195, 85, 255),
              Color.fromARGB((_touchForce * 100).clamp(0, 255).toInt(), 130, 30, 230),
              Color.fromARGB((_touchForce *  25).clamp(0, 255).toInt(),  80, 10, 190),
              const Color(0x00000000),
            ],
            [0.0, 0.45, 0.75, 1.0],
          ),
      );

      canvas.drawCircle(
        Offset(fx, fy),
        r * 0.30,
        Paint()
          ..blendMode = BlendMode.srcOver
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), r * 0.30,
            [
              Color.fromARGB((_touchForce * 245).clamp(0, 255).toInt(), 250, 210, 255),
              Color.fromARGB((_touchForce * 120).clamp(0, 255).toInt(), 200,  90, 255),
              const Color(0x00000000),
            ],
            [0.0, 0.55, 1.0],
          ),
      );

      // Velocity streak
      final vel    = _velocity;
      final velMag = sqrt(vel.dx * vel.dx + vel.dy * vel.dy);
      if (velMag > 0.0006) {
        final nx        = vel.dx / velMag;
        final ny        = vel.dy / velMag;
        final streakLen = (velMag * fw * 6.0).clamp(0.0, fh * 0.28);

        canvas.drawLine(
          Offset(fx, fy),
          Offset(fx + nx * streakLen, fy + ny * streakLen),
          Paint()
            ..blendMode  = BlendMode.srcOver
            ..strokeWidth = r * 1.8
            ..strokeCap  = StrokeCap.round
            ..style      = PaintingStyle.stroke
            ..shader     = ui.Gradient.linear(
              Offset(fx, fy),
              Offset(fx + nx * streakLen, fy + ny * streakLen),
              [
                Color.fromARGB((_touchForce * 45).clamp(0, 255).toInt(), 150, 50, 255),
                const Color(0x00000000),
              ],
            ),
        );

        canvas.drawLine(
          Offset(fx, fy),
          Offset(fx + nx * streakLen, fy + ny * streakLen),
          Paint()
            ..blendMode  = BlendMode.srcOver
            ..strokeWidth = r * 0.45
            ..strokeCap  = StrokeCap.round
            ..style      = PaintingStyle.stroke
            ..shader     = ui.Gradient.linear(
              Offset(fx, fy),
              Offset(fx + nx * streakLen, fy + ny * streakLen),
              [
                Color.fromARGB((_touchForce * 200).clamp(0, 255).toInt(), 235, 190, 255),
                const Color(0x00000000),
              ],
            ),
        );
      }
    }

    // Touch burst
    if (_touchBurst > 0.02) {
      final fx = _touch.dx * fw;
      final fy = _touch.dy * fh;
      final r  = fh * 0.15 * _touchBurst;
      canvas.drawCircle(
        Offset(fx, fy),
        r,
        Paint()
          ..blendMode = BlendMode.srcOver
          ..shader    = ui.Gradient.radial(
            Offset(fx, fy), r,
            [
              Color.fromARGB(
                  (_touchBurst * _touchBurst * 80).clamp(0, 255).toInt(),
                  210, 160, 255),
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