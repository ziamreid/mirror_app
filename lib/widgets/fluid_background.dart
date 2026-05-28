import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../fluid_painter.dart';
import '../velocity_field.dart';

// ─── Physics isolate ──────────────────────────────────────────────────────────
Float32List _physicsStep(List<dynamic> args) {
  final Float32List velX = args[0];
  final Float32List velY = args[1];
  final double      dt   = args[2];
  final field = VelocityField.fromArrays(velX, velY);
  field.step(dt);
  const int n = VelocityField.kCells;
  final out = Float32List(n * 2);
  for (int i = 0; i < n; i++) {
    out[i]     = field.velX[i];
    out[n + i] = field.velY[i];
  }
  return out;
}

// ─── Controller ───────────────────────────────────────────────────────────────
class FluidController {
  _FluidBackgroundState? _state;
  void _attach(_FluidBackgroundState s) => _state = s;
  void _detach()                         => _state = null;
  void setSpeed(double v) => _state?._targetSpeed = v;
  void setMood(double v)  => _state?._targetMood  = v;
}

// ─── Widget ───────────────────────────────────────────────────────────────────
class FluidBackground extends StatefulWidget {
  final Widget?          child;
  final FluidController? controller;
  const FluidBackground({super.key, this.child, this.controller});
  @override
  State<FluidBackground> createState() => _FluidBackgroundState();
}

class _FluidBackgroundState extends State<FluidBackground>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _prevT = 0.0;
  Size   _size  = Size.zero;

  final FluidEngine _engine = FluidEngine();
  final _repaint            = ValueNotifier<int>(0);
  bool  _physicsRunning     = false;
  int?  _activePointer;
  Offset _lastMoveVelocity  = Offset.zero;

  // ── Idle wander (smooth Perlin-like target following) ─────────────────────
  double _idleTimer  = 0.0;
  // Current wander target (normalized 0–1)
  double _wanderTx   = 0.5;
  double _wanderTy   = 0.35;
  // Actual orb position (smoothly follows target)
  double _orbX       = 0.5;
  double _orbY       = 0.35;
  // Time until next new target is chosen
  double _nextTarget = 0.0;

  // ── Teleport (after long idle) ────────────────────────────────────────────
  double _teleportFade      = 1.0;
  bool   _teleporting       = false;
  double _teleportTimer     = 0.0;
  double _pendingTx         = 0.5;
  double _pendingTy         = 0.5;
  double _lastTeleport      = 8.0; // first teleport after 8s

  // ── Speed / mood ──────────────────────────────────────────────────────────
  double _currentSpeed = 1.0;
  double _targetSpeed  = 1.0;
  double _currentMood  = 0.0;
  double _targetMood   = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _ticker = createTicker(_onTick);
    _ticker.start();
    _pickNewWanderTarget();
  }

  @override
  void didUpdateWidget(FluidBackground old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  // Pick a wander target safely away from edges
  void _pickNewWanderTarget() {
    double nx, ny;
    int tries = 0;
    do {
      nx = 0.18 + _rng.nextDouble() * 0.64;
      ny = 0.12 + _rng.nextDouble() * 0.45; // keep in upper half of screen
      tries++;
    } while (tries < 12 &&
        (nx - _wanderTx).abs() < 0.15 &&
        (ny - _wanderTy).abs() < 0.10);
    _wanderTx = nx;
    _wanderTy = ny;
    _nextTarget = 2.5 + _rng.nextDouble() * 2.0; // 2.5–4.5s between targets
  }

  void _onTick(Duration elapsed) {
    if (_size == Size.zero) return;
    final t  = elapsed.inMicroseconds / 1_000_000.0;
    final dt = (t - _prevT).clamp(0.0, 0.032);
    _prevT   = t;

    _currentSpeed += (_targetSpeed - _currentSpeed) * dt * 1.8;
    _currentMood  += (_targetMood  - _currentMood)  * dt * 1.8;

    final eff = dt * _currentSpeed;
    _engine.tick(eff);

    if (!_engine.touching) {
      _idleTimer  += dt;
      _nextTarget -= dt;
      final as = _size.width / _size.height;

      // Pick a new wander target when timer expires
      if (_nextTarget <= 0) _pickNewWanderTarget();

      // ── Teleport after 8 s idle ──────────────────────────────────────────
      if (_idleTimer >= _lastTeleport && !_teleporting) {
        _teleporting   = true;
        _teleportTimer = 0.0;
        _pendingTx     = 0.18 + _rng.nextDouble() * 0.64;
        _pendingTy     = 0.12 + _rng.nextDouble() * 0.45;
        _lastTeleport  = _idleTimer + 8.0;
      }

      if (_teleporting) {
        _teleportTimer += dt;
        const half = 0.5;
        if (_teleportTimer < half) {
          _teleportFade = 1.0 - (_teleportTimer / half);
        } else if (_teleportTimer < half * 2) {
          if (_teleportFade < 0.05) {
            // Snap to new position silently
            _orbX = _pendingTx;
            _orbY = _pendingTy;
            _wanderTx = _pendingTx;
            _wanderTy = _pendingTy;
            _engine.resetTrail(_orbX, _orbY);
          }
          _teleportFade = ((_teleportTimer - half) / half).clamp(0.0, 1.0);
        } else {
          _teleportFade = 1.0;
          _teleporting  = false;
        }
      }

      // ── Smooth wander: ease orb position toward wander target ────────────
      // Use a gentle spring — very smooth, 120fps friendly
      const double springK = 0.9; // lower = slower/smoother
      _orbX += (_wanderTx - _orbX) * springK * dt;
      _orbY += (_wanderTy - _orbY) * springK * dt;

      // Clamp away from edges so addForce never gets weird values
      _orbX = _orbX.clamp(0.12, 0.88);
      _orbY = _orbY.clamp(0.10, 0.65);

      // Stamp the trail at the smooth position every frame
      _engine.pushTrailDense(_orbX, _orbY);

      // Velocity is the direction of movement — gives the comet tail
      final velX = (_wanderTx - _orbX) * 0.08 * _currentSpeed;
      final velY = (_wanderTy - _orbY) * 0.08 * _currentSpeed;
      _engine.velocityField.addForce(_orbX, _orbY, velX, velY, aspect: as);

      // Keep orb bright — maintain touchForce during idle
      _engine.setTouchForce(0.90);

    } else {
      _idleTimer    = 0.0;
      _teleporting  = false;
      _teleportFade = 1.0;
    }

    if (!_physicsRunning) _dispatchPhysics(eff);
    _repaint.value++;
  }

  void _dispatchPhysics(double dt) {
    _physicsRunning = true;
    final vx = Float32List.fromList(_engine.velocityField.velX);
    final vy = Float32List.fromList(_engine.velocityField.velY);
    compute<List<dynamic>, Float32List>(_physicsStep, [vx, vy, dt]).then((r) {
      const int n = VelocityField.kCells;
      _engine.velocityField.velX.setAll(0, r.sublist(0, n));
      _engine.velocityField.velY.setAll(0, r.sublist(n, n * 2));
      _physicsRunning = false;
    }).catchError((_) => _physicsRunning = false);
  }

  // ── Touch handlers — clamp to safe zone away from edges ──────────────────
  Offset _safeNorm(Offset local) => Offset(
    (local.dx / _size.width).clamp(0.05, 0.95),
    (local.dy / _size.height).clamp(0.05, 0.95),
  );

  void _onPointerDown(PointerDownEvent e) {
    if (_activePointer != null) return;
    _activePointer = e.pointer;
    _idleTimer     = 0.0;
    _teleporting   = false;
    _teleportFade  = 1.0;
    if (_size == Size.zero) return;
    final n  = _safeNorm(e.localPosition);
    final as = _size.width / _size.height;
    _engine.resetTrail(n.dx, n.dy);
    _engine.setTouching(true);
    _engine.setTouch(n);
    _engine.setTouchForce(1.0);
    _engine.setTouchBurst(1.0);
    _engine.setVelocity(Offset.zero);
    _lastMoveVelocity = Offset.zero;
    _engine.velocityField.addForce(n.dx, n.dy, 0, 0, aspect: as);
    // Sync idle orb position to touch so wander resumes from here
    _orbX = n.dx; _orbY = n.dy;
    _wanderTx = n.dx; _wanderTy = n.dy;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _activePointer) return;
    if (_size == Size.zero) return;
    final n  = _safeNorm(e.localPosition);
    final as = _size.width / _size.height;
    final vx = e.delta.dx / _size.width;
    final vy = e.delta.dy / _size.height;
    _engine.setTouch(n);
    _lastMoveVelocity = Offset(
      _lastMoveVelocity.dx * 0.6 + vx * 0.4,
      _lastMoveVelocity.dy * 0.6 + vy * 0.4,
    );
    final prev = _engine.velocity;
    _engine.setVelocity(Offset(
      prev.dx * 0.75 + vx * 0.25,
      prev.dy * 0.75 + vy * 0.25,
    ));
    _engine.setTouchForce(1.0);
    _engine.pushTrailDense(n.dx, n.dy);
    _engine.velocityField.addForce(n.dx, n.dy, vx * 38.0, vy * 38.0, aspect: as);
    _orbX = n.dx; _orbY = n.dy;
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    if (_size == Size.zero) return;
    final pixelVel = Offset(
      _lastMoveVelocity.dx * _size.width,
      _lastMoveVelocity.dy * _size.height,
    );
    _engine.assignDriftOnRelease(pixelVel, _size);
    _engine.setTouching(false);
    _lastMoveVelocity = Offset.zero;
    // Resume wander from release point
    _wanderTx = _orbX; _wanderTy = _orbY;
    _pickNewWanderTarget();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    _engine.setTouching(false);
    _lastMoveVelocity = Offset.zero;
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        onPointerDown:   _onPointerDown,
        onPointerMove:   _onPointerMove,
        onPointerUp:     _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: Stack(
          children: [
            // Fluid — fades during teleport only
            Opacity(
              opacity: _teleportFade.clamp(0.0, 1.0),
              child: RepaintBoundary(
                child: ValueListenableBuilder<int>(
                  valueListenable: _repaint,
                  builder: (_, __, ___) => CustomPaint(
                    painter: FluidPainter(
                      engine:     _engine,
                      screenSize: _size,
                      repaint:    _repaint,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            // UI on top — always fully visible
            if (widget.child != null) widget.child!,
          ],
        ),
      ),
    );
  }
}

final _rng = Random();