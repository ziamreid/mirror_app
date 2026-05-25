import 'dart:math';
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
  late Ticker _ticker;
  bool _loaded = false;
  String? _errorMessage;

  double _time = 0.0;
  double _breath = 0.5;
  Offset _touch = const Offset(0.5, 0.5);
  double _touchForce = 0.0;
  Offset _velocity = Offset.zero;
  final Offset _gyro = Offset.zero;
  Size _size = Size.zero;

  final _velocityField = VelocityField();
  ui.Image? _velocityTexture;
  bool _textureBuilding = false;

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
      // Build the first texture before we allow painting
      await _buildTexture();
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  int _frameCount = 0;

  void _onTick(Duration elapsed) {
    if (!_loaded) return;
    final t = elapsed.inMilliseconds / 1000.0;
    final dt = (t - _time).clamp(0.0, 0.05);
    _time = t;

    final breathCycle = (t % 8.0) / 8.0;
    _breath = (sin(breathCycle * 2 * pi - pi / 2) + 1.0) / 2.0;

    _touchForce = (_touchForce - dt * 1.5).clamp(0.0, 1.0);
    _velocity = _velocity * 0.88;

    _velocityField.step(dt);
    _frameCount++;
    if (_frameCount % 2 == 0) _buildTexture(); // 30hz texture, 60fps render

    _repaint.value++;
  }

  Future<void> _buildTexture() async {
    if (_textureBuilding) return;
    _textureBuilding = true;
    try {
      final pixels = _velocityField.toPixels();
      final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: VelocityField.kSize,
        height: VelocityField.kSize,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      final old = _velocityTexture;
      _velocityTexture = frame.image;
      old?.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    } catch (e) {
      debugPrint('Texture build error: $e');
    } finally {
      _textureBuilding = false;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_size == Size.zero) return;
    final nx = details.localPosition.dx / _size.width;
    final ny = details.localPosition.dy / _size.height;
    final aspect = _size.width / _size.height;
    _velocityField.addForce(
      nx,
      ny,
      details.delta.dx * 12.0 / _size.width,
      details.delta.dy * 12.0 / _size.height,
      aspect: aspect,
    );
    _touch = Offset(nx, ny);
    _velocity = Offset(
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
                    shader: _shader!,
                    state: this,
                    repaint: _repaint,
                  ),
                  size: Size.infinite,
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Color(0xFF8844CC)),
              ),
      ),
    );
  }
}

class _FluidPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final _FluidScreenState state;

  _FluidPainter({
    required this.shader,
    required this.state,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    // Safety guard — never paint without a texture
    final texture = state._velocityTexture;
    if (texture == null) return;

    shader.setFloat(0, state._time);
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    shader.setFloat(3, state._touch.dx);
    shader.setFloat(4, state._touch.dy);
    shader.setFloat(5, state._touchForce);
    shader.setFloat(6, state._velocity.dx);
    shader.setFloat(7, state._velocity.dy);
    shader.setFloat(8, state._breath);
    shader.setFloat(9, state._gyro.dx);
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
