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
  static const double _kTrailDecay = 0.055; // slower = longer linger

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

    // Step 1: advect previous frame forward
    _drawAdvected(canvas, src, w, h);

    // Step 2: gentle decay toward black ~2s half-life at 60fps
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0x08000000),
    );

    // Step 3: inject new ink
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

    // Each trail point = soft glowing circle with MaskFilter.blur
    // This eliminates ALL pixelation — no drawLine with BlendMode.plus
    for (int i = 0; i < _kTrailLen; i++) {
      final p = trail[i];
      if (p.age >= 1.0) continue;

      // Quadratic ease-out: old points fade fast, new ones stay bright
      final ageCurved = p.age * p.age;
      final op = (1.0 - ageCurved).clamp(0.0, 1.0);

      // Smooth size decrease with age
      final r = fh * mix(0.11, 0.022, p.age);

      final px = p.x * fw;
      final py = p.y * fh;

      // Layer 1: wide soft aura
      canvas.drawCircle(
        Offset(px, py),
        r * 2.0,
        Paint()
          ..blendMode  = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.9)
          ..shader     = ui.Gradient.radial(
            Offset(px, py), r * 2.0,
            [
              Color.fromARGB((op * 30).clamp(0, 255).toInt(), 110, 25, 230),
              const Color(0x00000000),
            ],
          ),
      );

      // Layer 2: main glow — the blur kills all pixelation at edges
      canvas.drawCircle(
        Offset(px, py),
        r,
        Paint()
          ..blendMode  = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.50)
          ..shader     = ui.Gradient.radial(
            Offset(px, py), r,
            [
              Color.fromARGB((op * 125).clamp(0, 255).toInt(), 185, 65, 255),
              Color.fromARGB((op * 65).clamp(0, 255).toInt(),  115, 20, 230),
              const Color(0x00000000),
            ],
            [0.0, 0.55, 1.0],
          ),
      );

      // Layer 3: bright core spine
      canvas.drawCircle(
        Offset(px, py),
        r * 0.32,
        Paint()
          ..blendMode  = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22)
          ..shader     = ui.Gradient.radial(
            Offset(px, py), r * 0.32,
            [
              Color.fromARGB((op * 210).clamp(0, 255).toInt(), 235, 185, 255),
              const Color(0x00000000),
            ],
          ),
      );
    }

    // ── Live finger blob ─────────────────────────────────────────────────────
    if (_touchForce > 0.01) {
      final fx = _touch.dx * fw;
      final fy = _touch.dy * fh;
      final r  = fh * 0.088 * _touchForce;

      // Wide outer aura
      canvas.drawCircle(
        Offset(fx, fy),
        r * 2.6,
        Paint()
          ..blendMode  = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.1)
          ..shader     = ui.Gradient.radial(
            Offset(fx, fy), r * 2.6,
            [
              Color.fromARGB((_touchForce * 28).clamp(0, 255).toInt(), 125, 35, 245),
              const Color(0x00000000),
            ],
          ),
      );

      // Main body
      canvas.drawCircle(
        Offset(fx, fy),
        r,
        Paint()
          ..blendMode  = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.38)
          ..shader     = ui.Gradient.radial(
            Offset(fx, fy), r,
            [
              Color.fromARGB((_touchForce * 175).clamp(0, 255).toInt(), 195, 85, 255),
              Color.fromARGB((_touchForce * 75).clamp(0, 255).toInt(),  105, 18, 215),
              const Color(0x00000000),
            ],
            [0.0, 0.5, 1.0],
          ),
      );

      // Brilliant white-violet core
      canvas.drawCircle(
        Offset(fx, fy),
        r * 0.26,
        Paint()
          ..blendMode  = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.16)
          ..shader     = ui.Gradient.radial(
            Offset(fx, fy), r * 0.26,
            [
              Color.fromARGB((_touchForce * 245).clamp(0, 255).toInt(), 248, 205, 255),
              const Color(0x00000000),
            ],
          ),
      );

      // ── Velocity streak ──────────────────────────────────────────────────
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
            ..blendMode  = BlendMode.plus
            ..strokeWidth = r * 1.6
            ..strokeCap  = StrokeCap.round
            ..style      = PaintingStyle.stroke
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.65)
            ..shader     = ui.Gradient.linear(
              Offset(fx, fy),
              Offset(fx + nx * streakLen, fy + ny * streakLen),
              [
                Color.fromARGB((_touchForce * 50).clamp(0, 255).toInt(), 145, 45, 255),
                const Color(0x00000000),
              ],
            ),
        );

        canvas.drawLine(
          Offset(fx, fy),
          Offset(fx + nx * streakLen, fy + ny * streakLen),
          Paint()
            ..blendMode  = BlendMode.plus
            ..strokeWidth = r * 0.45
            ..strokeCap  = StrokeCap.round
            ..style      = PaintingStyle.stroke
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18)
            ..shader     = ui.Gradient.linear(
              Offset(fx, fy),
              Offset(fx + nx * streakLen, fy + ny * streakLen),
              [
                Color.fromARGB((_touchForce * 205).clamp(0, 255).toInt(), 235, 185, 255),
                const Color(0x00000000),
              ],
            ),
        );
      }
    }

    // ── Touch burst ──────────────────────────────────────────────────────────
    if (_touchBurst > 0.02) {
      final fx = _touch.dx * fw;
      final fy = _touch.dy * fh;
      final r  = fh * 0.15 * _touchBurst;
      canvas.drawCircle(
        Offset(fx, fy),
        r,
        Paint()
          ..blendMode  = BlendMode.plus
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45)
          ..shader     = ui.Gradient.radial(
            Offset(fx, fy), r,
            [
              Color.fromARGB(
                  (_touchBurst * _touchBurst * 85).clamp(0, 255).toInt(),
                  205, 155, 255),
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