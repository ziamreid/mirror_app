import 'dart:math';
import 'dart:typed_data';

class VelocityField {
  static const int kSize  = 32;
  static const int kCells = kSize * kSize;

  final Float32List velX;
  final Float32List velY;
  final Float32List _nextX;
  final Float32List _nextY;

  VelocityField()
      : velX  = Float32List(kCells),
        velY  = Float32List(kCells),
        _nextX = Float32List(kCells),
        _nextY = Float32List(kCells);

  // Used by isolate — constructs from copied arrays
  VelocityField.fromArrays(Float32List x, Float32List y)
      : velX  = Float32List.fromList(x),
        velY  = Float32List.fromList(y),
        _nextX = Float32List(kCells),
        _nextY = Float32List(kCells);

  void addForce(
    double normX,
    double normY,
    double forceX,
    double forceY, {
    double aspect = 1.0,
  }) {
    final gx = normX * (kSize - 1);
    final gy = normY * (kSize - 1);

    const double radius = 3.0;
    const double sigma2 = radius * radius * 0.5;

    final x0 = (gx - radius - 1).floor().clamp(0, kSize - 1);
    final x1 = (gx + radius + 1).ceil().clamp(0, kSize - 1);
    final y0 = (gy - radius - 1).floor().clamp(0, kSize - 1);
    final y1 = (gy + radius + 1).ceil().clamp(0, kSize - 1);

    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        final dx    = (x - gx);
        final dy    = (y - gy) * aspect;
        final dist2 = dx * dx + dy * dy;
        if (dist2 > (radius + 1) * (radius + 1)) continue;
        final weight = exp(-dist2 / sigma2);
        final idx    = y * kSize + x;
        velX[idx] += forceX * weight;
        velY[idx] += forceY * weight;
      }
    }
  }

  void step(double dt) {
    _diffuse(dt);
    _advect(dt);
    _decay(dt);
  }

  void toPixelsInto(Uint8List out) {
    for (int i = 0; i < kCells; i++) {
      final vx = velX[i].clamp(-1.0, 1.0);
      final vy = velY[i].clamp(-1.0, 1.0);
      out[i * 4 + 0] = (vx * 127.5 + 127.5).round();
      out[i * 4 + 1] = (vy * 127.5 + 127.5).round();
      out[i * 4 + 2] = 0;
      out[i * 4 + 3] = 255;
    }
  }

  Uint8List toPixels() {
    final buf = Uint8List(kCells * 4);
    toPixelsInto(buf);
    return buf;
  }

  void _diffuse(double dt) {
    const double viscosity = 0.8;
    final double alpha = (viscosity * dt * 60.0).clamp(0.0, 1.0);
    for (int y = 0; y < kSize; y++) {
      for (int x = 0; x < kSize; x++) {
        final idx   = y * kSize + x;
        final left  = y * kSize + ((x - 1 + kSize) % kSize);
        final right = y * kSize + ((x + 1) % kSize);
        final up    = ((y - 1 + kSize) % kSize) * kSize + x;
        final down  = ((y + 1) % kSize) * kSize + x;
        final avgX  = (velX[left] + velX[right] + velX[up] + velX[down]) * 0.25;
        final avgY  = (velY[left] + velY[right] + velY[up] + velY[down]) * 0.25;
        _nextX[idx] = velX[idx] + (avgX - velX[idx]) * alpha;
        _nextY[idx] = velY[idx] + (avgY - velY[idx]) * alpha;
      }
    }
    velX.setAll(0, _nextX);
    velY.setAll(0, _nextY);
  }

  void _advect(double dt) {
    const double strength = 8.0;
    for (int y = 0; y < kSize; y++) {
      for (int x = 0; x < kSize; x++) {
        final idx  = y * kSize + x;
        final srcX = x - velX[idx] * strength * dt;
        final srcY = y - velY[idx] * strength * dt;
        _nextX[idx] = _bilinearX(srcX, srcY);
        _nextY[idx] = _bilinearY(srcX, srcY);
      }
    }
    velX.setAll(0, _nextX);
    velY.setAll(0, _nextY);
  }

  void _decay(double dt) {
    final factor = pow(0.97, dt * 60.0).toDouble();
    for (int i = 0; i < kCells; i++) {
      velX[i] *= factor;
      velY[i] *= factor;
    }
  }

  double _bilinearX(double fx, double fy) => _bilinear(velX, fx, fy);
  double _bilinearY(double fx, double fy) => _bilinear(velY, fx, fy);

  double _bilinear(Float32List field, double fx, double fy) {
    fx = fx.clamp(0.0, kSize - 1.0001);
    fy = fy.clamp(0.0, kSize - 1.0001);
    final x0 = fx.floor();
    final y0 = fy.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;
    final tx = fx - x0;
    final ty = fy - y0;
    final i00 = y0 * kSize + x0;
    final i10 = y0 * kSize + x1;
    final i01 = y1 * kSize + x0;
    final i11 = y1 * kSize + x1;
    return field[i00] * (1 - tx) * (1 - ty) +
           field[i10] * tx       * (1 - ty) +
           field[i01] * (1 - tx) * ty       +
           field[i11] * tx       * ty;
  }
}