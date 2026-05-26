import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'fluid_painter.dart';
import 'velocity_field.dart';

void main() => runApp(const MyApp());

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
      debugShowCheckedModeBanner: false, home: FluidScreen());
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

  final FluidEngine _engine  = FluidEngine();
  final _repaint = ValueNotifier<int>(0);
  bool _physicsRunning = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_size == Size.zero) return;
    final t  = elapsed.inMilliseconds / 1000.0;
    final dt = (t - _prevT).clamp(0.0, 0.05);
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

  void _onPanStart(DragStartDetails d) {
    if (_size == Size.zero) return;
    final nx = d.localPosition.dx / _size.width;
    final ny = d.localPosition.dy / _size.height;
    final as = _size.width / _size.height;
    _engine.setTouching(true);
    _engine.resetTrail(nx, ny);
    _engine.setTouch(Offset(nx, ny));
    _engine.setTouchForce(1.0);
    _engine.setTouchBurst(1.0);
    _engine.setVelocity(Offset.zero);
    _engine.pushTrail(nx, ny);
    for (final dir in [
      const Offset( 0.10,  0.00),
      const Offset(-0.10,  0.00),
      const Offset( 0.00,  0.10),
      const Offset( 0.00, -0.10),
    ]) {
      _engine.velocityField.addForce(nx, ny, dir.dx, dir.dy, aspect: as);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_size == Size.zero) return;
    final nx = d.localPosition.dx / _size.width;
    final ny = d.localPosition.dy / _size.height;
    final as = _size.width / _size.height;
    final vx = d.delta.dx / _size.width;
    final vy = d.delta.dy / _size.height;
    _engine.setTouch(Offset(nx, ny));
    final prev = _engine.velocity;
    _engine.setVelocity(Offset(
      prev.dx * 0.75 + vx * 0.25,
      prev.dy * 0.75 + vy * 0.25,
    ));
    _engine.setTouchForce(1.0);
    _engine.pushTrail(nx, ny);
    _engine.velocityField.addForce(nx, ny, vx * 22.0, vy * 22.0, aspect: as);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_size == Size.zero) return;
    _engine.setTouching(false); // triggers fast decay
    final pv = d.velocity.pixelsPerSecond;
    final as = _size.width / _size.height;
    _engine.velocityField.addForce(
      _engine.touch.dx, _engine.touch.dy,
      pv.dx * 0.0008, pv.dy * 0.0008, aspect: as,
    );
    final ev = _engine.velocity;
    _engine.setVelocity(Offset(
      ev.dx * 0.5 + pv.dx * 0.0006,
      ev.dy * 0.5 + pv.dy * 0.0006,
    ));
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
      body: GestureDetector(
        onPanStart:  _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd:    _onPanEnd,
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