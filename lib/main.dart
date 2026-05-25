import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'velocity_field.dart';

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
  late Ticker         _ticker;
  bool                _loaded = false;
  String?             _errorMessage;

  double _time       = 0.0;
  double _breath     = 0.5;
  Offset _touch      = const Offset(0.5, 0.5);
  double _touchForce = 0.0;
  Offset _velocity   = Offset.zero;
  final Offset _gyro = Offset.zero;
  Size   _size       = Size.zero;

  final _velocityField = VelocityField();
  ui.Image? _velocityTexture;

  // 4.3 — frame counter for texture throttle (60hz data, 120fps render)
  int  _frameCount      = 0;
  bool _textureBuilding = false;

  // 4.3 — pre-allocated pixel buffer, zero allocation per frame
  final Uint8List _pixelBuffer =
      Uint8List(VelocityField.kSize * VelocityField.kSize * 4);

  final _repaint = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/fluid.frag',
      );
      _shader = program.fragmentShader();
      // Must await first texture — guarantees sampler is bound before paint()
      await _buildTextureOnce();
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  // Used once at startup — awaitable so we never paint without a texture
  Future<void> _buildTextureOnce() async {
    _velocityField.toPixelsInto(_pixelBuffer);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      _pixelBuffer,
      VelocityField.kSize,
      VelocityField.kSize,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    _velocityTexture = await completer.future;
  }

  // Used every tick — fire-and-forget, single callback, no chained awaits
  void _buildTexture() {
    if (_textureBuilding) return;
    _textureBuilding = true;
    _velocityField.toPixelsInto(_pixelBuffer);
    ui.decodeImageFromPixels(
      _pixelBuffer,
      VelocityField.kSize,
      VelocityField.kSize,
      ui.PixelFormat.rgba8888,
      (ui.Image img) {
        final old = _velocityTexture;
        _velocityTexture = img;
        old?.dispose();
        _textureBuilding = false;
      },
    );
  }

  void _onTick(Duration elapsed) {
    if (!_loaded) return;

    final t  = elapsed.inMilliseconds / 1000.0;
    final dt = (t - _time).clamp(0.0, 0.05);
    _time    = t;

    // 4.3 — frame pacing: skip physics if frame is late, never skip render
    if (dt < 0.033) {
      final breathCycle = (t % 8.0) / 8.0;
      _breath = (sin(breathCycle * 2 * pi - pi / 2) + 1.0) / 2.0;

      _touchForce = (_touchForce - dt * 1.5).clamp(0.0, 1.0);
      _velocity   = _velocity * 0.88;

      _velocityField.step(dt);

      // 4.3 — texture throttle: upload every 2nd frame only
      _frameCount++;
      if (_frameCount % 2 == 0) _buildTexture();
    }

    _repaint.value++;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_size == Size.zero) return;
    final nx     = details.localPosition.dx / _size.width;
    final ny     = details.localPosition.dy / _size.height;
    final aspect = _size.width / _size.height;
    _velocityField.addForce(
      nx, ny,
      details.delta.dx * 12.0 / _size.width,
      details.delta.dy * 12.0 / _size.height,
      aspect: aspect,
    );
    _touch      = Offset(nx, ny);
    _velocity   = Offset(
      details.delta.dx / _size.width,
      details.delta.dy / _size.height,
    );
    _touchForce = 1.0;
  }

  @override
  void dispose() {
    _velocityTexture?.dispose();
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
        onPanUpdate: _onPanUpdate,
        child: _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error: $_errorMessage',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _loaded && _shader != null && _velocityTexture != null
                ? RepaintBoundary(
                    child: CustomPaint(
                      painter: _FluidPainter(
                        shader:  _shader!,
                        state:   this,
                        repaint: _repaint,
                      ),
                      size: Size.infinite,
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8844CC),
                    ),
                  ),
      ),
    );
  }
}

class _FluidPainter extends CustomPainter {
  final ui.FragmentShader  shader;
  final _FluidScreenState  state;

  _FluidPainter({
    required this.shader,
    required this.state,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final texture = state._velocityTexture;
    if (texture == null) return;

    shader.setFloat(0,  state._time);
    shader.setFloat(1,  size.width);
    shader.setFloat(2,  size.height);
    shader.setFloat(3,  state._touch.dx);
    shader.setFloat(4,  state._touch.dy);
    shader.setFloat(5,  state._touchForce);
    shader.setFloat(6,  state._velocity.dx);
    shader.setFloat(7,  state._velocity.dy);
    shader.setFloat(8,  state._breath);
    shader.setFloat(9,  state._gyro.dx);
    shader.setFloat(10, state._gyro.dy);

    shader.setImageSampler(0, texture);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_FluidPainter old) => false;
}