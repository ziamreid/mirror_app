import 'dart:math';
import 'dart:typed_data';

/// 32×32 velocity field — simulates fluid momentum in Dart.
///
/// Every cell stores a velocity vector (velX, velY).
/// Each frame: addForce() injects touch input, step() evolves the field.
/// Output: toPixels() encodes the field as RGBA bytes for the shader texture.
///
/// No Flutter imports — isolate-compatible for Phase 4.
class VelocityField {
  static const int kSize = 32;
  static const int kCells = kSize * kSize; // 1024

  // Two flat arrays — row-major, index = y * kSize + x
  final Float32List velX = Float32List(kCells);
  final Float32List velY = Float32List(kCells);

  // Scratch buffers — reused every frame, no allocation in hot path
  final Float32List _nextX = Float32List(kCells);
  final Float32List _nextY = Float32List(kCells);

  // Pixel buffer — reused for texture upload
  final Uint8List _pixels = Uint8List(kCells * 4);

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Inject force at a normalized screen position (0..1, 0..1).
  /// forceX/forceY are in grid-space units per second.
  /// Splash radius: ~3 cells gaussian.
  void addForce(
    double normX,
    double normY,
    double forceX,
    double forceY, {
    double aspect = 1.0, // screen width / height — corrects oval splat
  }) {
    // Convert normalized coords to grid coords
    final gx = normX * (kSize - 1);
    final gy = normY * (kSize - 1);

    // Gaussian splat radius in grid cells
    const double radius = 3.0;
    const double sigma2 = radius * radius * 0.5;

    // Only touch cells within radius + 1
    final x0 = (gx - radius - 1).floor().clamp(0, kSize - 1);
    final x1 = (gx + radius + 1).ceil().clamp(0, kSize - 1);
    final y0 = (gy - radius - 1).floor().clamp(0, kSize - 1);
    final y1 = (gy + radius + 1).ceil().clamp(0, kSize - 1);

    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        // Aspect-corrected distance — prevents oval splat on tall screens
        final dx = (x - gx);
        final dy = (y - gy) * aspect;
        final dist2 = dx * dx + dy * dy;

        if (dist2 > (radius + 1) * (radius + 1)) continue;

        final weight = exp(-dist2 / sigma2);
        final idx = y * kSize + x;
        velX[idx] += forceX * weight;
        velY[idx] += forceY * weight;
      }
    }
  }

  /// Evolve the field one timestep.
  /// Call once per frame from _onTick.
  void step(double dt) {
    _diffuse(dt);
    _advect(dt);
    _decay(dt);
  }

  /// Encode the velocity field as RGBA pixels for the shader texture.
  /// velX → R channel, velY → G channel.
  /// Range: -1.0..1.0 → 0..255  (formula: v * 127.5 + 127.5)
  Uint8List toPixels() {
    for (int i = 0; i < kCells; i++) {
      // Clamp to -1..1 before encoding — prevents wrap-around artifacts
      final vx = velX[i].clamp(-1.0, 1.0);
      final vy = velY[i].clamp(-1.0, 1.0);
      _pixels[i * 4 + 0] = (vx * 127.5 + 127.5).round(); // R = velX
      _pixels[i * 4 + 1] = (vy * 127.5 + 127.5).round(); // G = velY
      _pixels[i * 4 + 2] = 0;                              // B unused
      _pixels[i * 4 + 3] = 255;                            // A always opaque
    }
    return _pixels;
  }

  // ─── Internal simulation steps ─────────────────────────────────────────────

  /// Diffuse — spread velocity to neighbors.
  /// Simulates viscosity: sharp injections blur into smooth flows.
  /// Alpha controls how much diffusion per frame.
  void _diffuse(double dt) {
    const double viscosity = 0.8; // 0 = no diffusion, 1 = instant spread
    final double alpha = viscosity * dt * 60.0; // frame-rate independent

    for (int y = 0; y < kSize; y++) {
      for (int x = 0; x < kSize; x++) {
        final idx = y * kSize + x;

        // Von Neumann neighbors — wrap at edges (torus topology)
        final left  = y * kSize + ((x - 1 + kSize) % kSize);
        final right = y * kSize + ((x + 1) % kSize);
        final up    = ((y - 1 + kSize) % kSize) * kSize + x;
        final down  = ((y + 1) % kSize) * kSize + x;

        final avgX = (velX[left] + velX[right] + velX[up] + velX[down]) * 0.25;
        final avgY = (velY[left] + velY[right] + velY[up] + velY[down]) * 0.25;

        // Lerp current cell toward neighbor average
        _nextX[idx] = velX[idx] + (avgX - velX[idx]) * alpha.clamp(0.0, 1.0);
        _nextY[idx] = velY[idx] + (avgY - velY[idx]) * alpha.clamp(0.0, 1.0);
      }
    }

    // Swap buffers
    velX.setAll(0, _nextX);
    velY.setAll(0, _nextY);
  }

  /// Advect — move velocity along itself.
  /// This is what creates trailing and inertia.
  /// Each cell "looks back" along its own velocity to find where it came from.
  void _advect(double dt) {
    const double strength = 8.0; // advection scale — tune for trail length

    for (int y = 0; y < kSize; y++) {
      for (int x = 0; x < kSize; x++) {
        final idx = y * kSize + x;

        // Back-trace: where did this cell's fluid come from?
        final srcX = x - velX[idx] * strength * dt;
        final srcY = y - velY[idx] * strength * dt;

        // Bilinear sample at source position (clamped, not wrapped)
        _nextX[idx] = _bilinearX(srcX, srcY);
        _nextY[idx] = _bilinearY(srcX, srcY);
      }
    }

    velX.setAll(0, _nextX);
    velY.setAll(0, _nextY);
  }

  /// Decay — multiply every cell by a factor slightly below 1.
  /// Natural momentum fade: ~1 second for velocity to reach ~5% of original.
  void _decay(double dt) {
    // 0.97 per frame at 60fps ≈ full decay in ~1.1 seconds
    // Frame-rate independent: pow(0.97, dt * 60)
    final factor = pow(0.97, dt * 60.0).toDouble();
    for (int i = 0; i < kCells; i++) {
      velX[i] *= factor;
      velY[i] *= factor;
    }
  }

  // ─── Bilinear sampling ─────────────────────────────────────────────────────

  double _bilinearX(double fx, double fy) => _bilinear(velX, fx, fy);
  double _bilinearY(double fx, double fy) => _bilinear(velY, fx, fy);

  double _bilinear(Float32List field, double fx, double fy) {
    // Clamp to grid bounds
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