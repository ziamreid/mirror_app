import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FluidScreen(),
    );
  }
}

class FluidScreen extends StatefulWidget {
  const FluidScreen({super.key});
  @override
  State<FluidScreen> createState() => _FluidScreenState();
}

class _FluidScreenState extends State<FluidScreen>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late Ticker _ticker;

  double _time = 0.0;
  double _breath = 0.5;
  double _pulse = 0.0;
  bool _pulseDone = false;
  bool _loaded = false;

  // Touch
  Offset _touch = const Offset(0.5, 0.5);
  double _touchForce = 0.0;
  Offset _velocity = Offset.zero;
  Offset _lastTouch = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset(
      'assets/shaders/fluid.frag',
    );
    setState(() {
      _shader = program.fragmentShader();
      _loaded = true;
    });
  }

  void _onTick(Duration elapsed) {
    if (!_loaded) return;
    final t = elapsed.inMilliseconds / 1000.0;
    final dt = t - _time;

    // Breathing — 8 second cycle
    final breathCycle = (t % 8.0) / 8.0;
    final breath = (sin(breathCycle * 2 * pi - pi / 2) + 1.0) / 2.0;

    // Launch pulse — plays once over 2 seconds
    double pulse = _pulse;
    if (!_pulseDone) {
      pulse = (t / 2.0).clamp(0.0, 1.0);
      if (pulse >= 1.0) _pulseDone = true;
    }

    // Touch force decay
    double touchForce = (_touchForce - dt * 1.2).clamp(0.0, 1.0);

    // Velocity damping
    Offset velocity = _velocity * 0.85;

    setState(() {
      _time = t;
      _breath = breath;
      _pulse = pulse;
      _touchForce = touchForce;
      _velocity = velocity;
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    final pos = Offset(
      details.localPosition.dx / size.width,
      details.localPosition.dy / size.height,
    );
    final vel = Offset(
      details.delta.dx / size.width,
      details.delta.dy / size.height,
    );
    setState(() {
      _touch = pos;
      _touchForce = 1.0;
      _velocity = vel;
      _lastTouch = pos;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // touchForce decays naturally in tick
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onPanUpdate: (d) => _onPanUpdate(d, size),
        onPanEnd: _onPanEnd,
        child: _loaded && _shader != null
            ? RepaintBoundary(
                child: CustomPaint(
                  painter: FluidPainter(
                    shader: _shader!,
                    time: _time,
                    touch: _touch,
                    touchForce: _touchForce,
                    velocity: _velocity,
                    breath: _breath,
                    pulse: _pulse,
                  ),
                  size: Size.infinite,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class FluidPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final Offset touch;
  final double touchForce;
  final Offset velocity;
  final double breath;
  final double pulse;

  FluidPainter({
    required this.shader,
    required this.time,
    required this.touch,
    required this.touchForce,
    required this.velocity,
    required this.breath,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, time);
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    shader.setFloat(3, touch.dx);
    shader.setFloat(4, touch.dy);
    shader.setFloat(5, touchForce);
    shader.setFloat(6, velocity.dx);
    shader.setFloat(7, velocity.dy);
    shader.setFloat(8, breath);
    shader.setFloat(9, pulse);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(FluidPainter old) => true;
}