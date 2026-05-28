import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'fluid_painter.dart';
import 'velocity_field.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: FluidScreen(),
      );
}

class FluidScreen extends StatefulWidget {
  const FluidScreen({super.key});
  @override
  State<FluidScreen> createState() => _FluidScreenState();
}

class _FluidScreenState extends State<FluidScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _prevT = 0.0;
  Size   _size  = Size.zero;

  final FluidEngine _engine = FluidEngine();
  final _repaint            = ValueNotifier<int>(0);
  bool  _physicsRunning     = false;
  int?  _activePointer;

  // Track velocity for fling on release
  Offset _lastMoveVelocity = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_size == Size.zero) return;
    final t  = elapsed.inMicroseconds / 1000000.0;
    final dt = (t - _prevT).clamp(0.0, 0.032);
    _prevT   = t;
    _engine.tick(dt);
    if (!_physicsRunning) _dispatchPhysics(dt);
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
    }).catchError((e) {
      debugPrint('Physics: $e');
      _physicsRunning = false;
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_activePointer != null) return; // lock to first finger only
    _activePointer = e.pointer;
    if (_size == Size.zero) return;
    final nx = e.localPosition.dx / _size.width;
    final ny = e.localPosition.dy / _size.height;
    final as = _size.width / _size.height;

    // Reset trail instantly — clean single trail, no overlap blobs
    _engine.resetTrail(nx, ny);
    _engine.setTouching(true);
    _engine.setTouch(Offset(nx, ny));
    _engine.setTouchForce(1.0);
    _engine.setTouchBurst(1.0);
    _engine.setVelocity(Offset.zero);
    _lastMoveVelocity = Offset.zero;
    _engine.velocityField.addForce(nx, ny, 0.0, 0.0, aspect: as);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _activePointer) return;
    if (_size == Size.zero) return;
    final nx = e.localPosition.dx / _size.width;
    final ny = e.localPosition.dy / _size.height;
    final as = _size.width / _size.height;
    final vx = e.delta.dx / _size.width;
    final vy = e.delta.dy / _size.height;

    _engine.setTouch(Offset(nx, ny));

    // Smooth velocity tracking for fling detection
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
    _engine.pushTrailDense(nx, ny);
    _engine.velocityField.addForce(nx, ny, vx * 38.0, vy * 38.0, aspect: as);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    if (_size == Size.zero) return;

    // Convert normalized velocity to pixel velocity for drift calculation
    final pixelVel = Offset(
      _lastMoveVelocity.dx * _size.width,
      _lastMoveVelocity.dy * _size.height,
    );
    _engine.assignDriftOnRelease(pixelVel, _size);
    _engine.setTouching(false);
    _lastMoveVelocity = Offset.zero;
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    _engine.setTouching(false);
    _lastMoveVelocity = Offset.zero;
  }

  @override
  void dispose() {
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
    );
  }
}