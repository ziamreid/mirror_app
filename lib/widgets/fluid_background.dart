import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../fluid_painter.dart';
import '../velocity_field.dart';

Float32List _physicsStep(List<dynamic> args) {
  final Float32List velX = args[0];
  final Float32List velY = args[1];
  final double dt = args[2];
  final field = VelocityField.fromArrays(velX, velY);
  field.step(dt);
  const int n = VelocityField.kCells;
  final out = Float32List(n * 2);
  for (int i = 0; i < n; i++) {
    out[i] = field.velX[i];
    out[n + i] = field.velY[i];
  }
  return out;
}

class FluidController {
  _FluidBackgroundState? _state;
  void _attach(_FluidBackgroundState s) => _state = s;
  void _detach() => _state = null;
  void setSpeed(double v) => _state?._targetSpeed = v;
  void setMood(double v)  => _state?._targetMood  = v;
  void lockOrb()   => _state?._orbLocked = true;
  void unlockOrb() => _state?._orbLocked = false;
  FluidEngine?        get engine  => _state?._engine;
  ValueNotifier<int>? get repaint => _state?._repaint;
}

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
  final FluidEngine        _engine  = FluidEngine();
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  int?   _activePointer;
  Offset _lastMoveVelocity = Offset.zero;
  bool   _orbLocked = false;

  double _t  = 0.0;
  double _wx = 0.22, _wy = 0.35;
  double _px = 0.0,  _py = 0.0;
  double _ax = 0.30, _ay = 0.22;
  double _cx = 0.50, _cy = 0.40;
  double _tcx = 0.50, _tcy = 0.40;
  double _centerTimer = 8.0;
  double _orbX = 0.50, _orbY = 0.40;
  double _teleportFade  = 1.0;
  bool   _teleporting   = false;
  double _teleportTimer = 0.0;
  double _nextTeleport  = 60.0;
  double _currentSpeed = 1.0, _targetSpeed = 1.0;
  double _currentMood  = 0.0, _targetMood  = 0.0;
  int _frameCnt = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _wx = 0.20 + _rng.nextDouble() * 0.05;
    _wy = 0.32 + _rng.nextDouble() * 0.06;
    _ax = 0.26 + _rng.nextDouble() * 0.08;
    _ay = 0.18 + _rng.nextDouble() * 0.06;
    _rephaseToPosition(0.50, 0.40);
    _orbX = 0.50; _orbY = 0.40;
    for (int i = 0; i < FluidEngine.kTrailLen; i++) {
      _engine.trail[i] = TrailPoint(0.50, 0.40)..age = 0.0;
    }
    _engine.trailHeadSet(FluidEngine.kTrailLen - 1);
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void didUpdateWidget(FluidBackground old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _rephaseToPosition(double x, double y) {
    _cx = x; _cy = y; _tcx = x; _tcy = y;
    _px = -_wx * _t; _py = -_wy * _t;
  }

  void _rephaseFromCurrentPosition() {
    final dxNorm = _ax > 0 ? ((_orbX - _cx) / _ax).clamp(-1.0, 1.0) : 0.0;
    final dyNorm = _ay > 0 ? ((_orbY - _cy) / _ay).clamp(-1.0, 1.0) : 0.0;
    _px = asin(dxNorm) - _wx * _t;
    _py = asin(dyNorm) - _wy * _t;
  }

  void _driftCenter(double dt) {
    _centerTimer -= dt;
    if (_centerTimer <= 0) {
      _tcx = 0.20 + _rng.nextDouble() * 0.60;
      _tcy = 0.18 + _rng.nextDouble() * 0.44;
      _centerTimer = 10.0 + _rng.nextDouble() * 8.0;
    }
    _cx += (_tcx - _cx) * dt * 0.06;
    _cy += (_tcy - _cy) * dt * 0.06;
  }

  void _onTick(Duration elapsed) {
    if (_size == Size.zero) return;
    final nowSec = elapsed.inMicroseconds / 1_000_000.0;
    final dt     = (nowSec - _prevT).clamp(0.0, 0.032);
    _prevT = nowSec;
    _frameCnt++;
    _currentSpeed += (_targetSpeed - _currentSpeed) * dt * 2.5;
    _currentMood  += (_targetMood  - _currentMood)  * dt * 2.5;
    final eff = dt * _currentSpeed;
    _engine.tick(eff);
    if (!_engine.touching) {
      _t += dt * _currentSpeed;
      _driftCenter(dt);

      _nextTeleport -= dt;
      if (_nextTeleport <= 0 && !_teleporting) {
        _teleporting = true; _teleportTimer = 0.0;
        _nextTeleport = 60.0 + _rng.nextDouble() * 30.0;
      }
      if (_teleporting) {
        _teleportTimer += dt;
        const half = 0.60;
        if (_teleportTimer < half) {
          _teleportFade = 1.0 - (_teleportTimer / half);
        } else if (_teleportTimer < half * 2) {
          if (_teleportFade < 0.05) {
            final nx = 0.20 + _rng.nextDouble() * 0.60;
            final ny = 0.16 + _rng.nextDouble() * 0.46;
            _orbX = nx; _orbY = ny;
            _rephaseToPosition(nx, ny);
            _engine.resetTrail(nx, ny);
          }
          _teleportFade = ((_teleportTimer - half) / half).clamp(0.0, 1.0);
        } else {
          _teleportFade = 1.0; _teleporting = false;
        }
      }
      final rawX = _cx + _ax * sin(_wx * _t + _px);
      final rawY = _cy + _ay * sin(_wy * _t + _py);
      final targetX = rawX.clamp(0.10, 0.90);
      final targetY = rawY.clamp(0.12, 0.78);
      _orbX += (targetX - _orbX) * (1.0 - exp(-6.0 * dt));
      _orbY += (targetY - _orbY) * (1.0 - exp(-6.0 * dt));
      _engine.forceTrailPoint(_orbX, _orbY);
      if (_frameCnt % 2 == 0) {
        final velX = _ax * _wx * cos(_wx * _t + _px) * 0.02 * _currentSpeed;
        final velY = _ay * _wy * cos(_wy * _t + _py) * 0.02 * _currentSpeed;
        _engine.velocityField.addForce(_orbX, _orbY, velX, velY,
            aspect: _size.width / _size.height);
      }
    } else {
      _teleporting = false; _teleportFade = 1.0;
    }
    if (_frameCnt % 3 == 0 && !_physicsRunning) _dispatchPhysics(eff);
    _repaint.value++;
  }

  bool _physicsRunning = false;
  void _dispatchPhysics(double dt) {
    _physicsRunning = true;
    final vx = Float32List.fromList(_engine.velocityField.velX);
    final vy = Float32List.fromList(_engine.velocityField.velY);
    compute<List<dynamic>, Float32List>(_physicsStep, [vx, vy, dt]).then((r) {
      if (!mounted) return;
      const int n = VelocityField.kCells;
      _engine.velocityField.velX.setAll(0, r.sublist(0, n));
      _engine.velocityField.velY.setAll(0, r.sublist(n, n * 2));
      _physicsRunning = false;
    }).catchError((_) => _physicsRunning = false);
  }

  Offset _safeNorm(Offset local) => Offset(
    (local.dx / _size.width).clamp(0.05, 0.95),
    (local.dy / _size.height).clamp(0.05, 0.95),
  );

  void _onPointerDown(PointerDownEvent e) {
    if (_orbLocked) return;
    if (_activePointer != null) return;
    _activePointer = e.pointer;
    _teleporting = false; _teleportFade = 1.0;
    if (_size == Size.zero) return;
    final n = _safeNorm(e.localPosition);
    _engine.resetTrail(n.dx, n.dy);
    _engine.setTouching(true);
    _engine.setTouch(n);
    _engine.setTouchForce(0.0);
    _engine.setTouchBurst(1.0);
    _engine.setVelocity(Offset.zero);
    _lastMoveVelocity = Offset.zero;
    _engine.velocityField.addForce(n.dx, n.dy, 0, 0,
        aspect: _size.width / _size.height);
    _orbX = n.dx; _orbY = n.dy;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_orbLocked) return;
    if (e.pointer != _activePointer) return;
    if (_size == Size.zero) return;
    final n  = _safeNorm(e.localPosition);
    final as = _size.width / _size.height;
    final vx = e.delta.dx / _size.width;
    final vy = e.delta.dy / _size.height;
    _engine.setTouch(n);
    _lastMoveVelocity = Offset(
      _lastMoveVelocity.dx * 0.3 + vx * 0.7,
      _lastMoveVelocity.dy * 0.3 + vy * 0.7,
    );
    _engine.setVelocity(Offset(
      _engine.velocity.dx * 0.55 + vx * 0.45,
      _engine.velocity.dy * 0.55 + vy * 0.45,
    ));
    _engine.pushTrailDense(n.dx, n.dy);
    _engine.velocityField.addForce(n.dx, n.dy, vx * 100.0, vy * 100.0, aspect: as);
    _orbX = n.dx; _orbY = n.dy;
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    if (_size == Size.zero) return;
    _engine.assignDriftOnRelease(
      Offset(_lastMoveVelocity.dx * _size.width, _lastMoveVelocity.dy * _size.height),
      _size,
    );
    _engine.setTouching(false);
    _lastMoveVelocity = Offset.zero;
    _rephaseFromCurrentPosition();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    _engine.setTouching(false);
    _lastMoveVelocity = Offset.zero;
    _rephaseFromCurrentPosition();
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
            RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _repaint,
                builder: (_, __, ___) => CustomPaint(
                  painter: FluidPainter(
                    engine:       _engine,
                    screenSize:   _size,
                    repaint:      _repaint,
                    teleportFade: _teleportFade,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            if (widget.child != null) Positioned.fill(child: widget.child!),
          ],
        ),
      ),
    );
  }
}

final _rng = Random();