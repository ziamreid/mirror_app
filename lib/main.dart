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
  late Ticker _ticker;
  bool _loaded = false;

  double _time       = 0.0;
  double _breath     = 0.5;
  Offset _touch      = const Offset(0.5, 0.5);
  double _touchForce = 0.0;
  Offset _velocity   = Offset.zero;
  Offset _gyro       = Offset.zero;
  Size   _size       = Size.zero;

  // Phase 4.1 — velocity grid
  final _velocityField = VelocityField();

  // Phase 4.2 — texture that carries the grid to the shader
  ui.Image? _velocityTexture;

  // Track in-flight texture build so we don't stack async calls
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
    final program = await ui.FragmentProgram.fromAsset(
      'assets/shaders/fluid.frag',
    );
    _shader = program.fragmentShader();
    setState(() => _loaded = true);
  }

  void _onTick(Duration elapsed) {
    if (!_loaded) return;
    final t  = elapsed.inMilliseconds / 1000.0;
    final dt = (t - _time).clamp(0.0, 0.05);
    _time    = t;

    final breathCycle = (t % 8.0) / 8.0;
    _breath = (sin(breathCycle * 2 * pi - pi / 2) + 1.0) / 2.0;

    _touchForce = (_touchForce - dt * 1.5).clamp(0.0, 1.0);
    _velocity   = _velocity * 0.88;

    // Phase 4.1 — evolve velocity field
    _velocityField.step(dt);

    // Phase 4.2 — encode grid as texture (non-stacking async)
    _buildTexture();

    _repaint.value++;
  }

  /// Encode the 32×32 velocity grid as a ui.Image every frame.
  /// Uses ImmutableBuffer + ImageDescriptor — faster than decodeImageFromPixels,
  /// no intermediate allocations. Guard flag prevents stacking async calls.
  Future<void> _buildTexture() async {
    if (_textureBuilding) return; // skip if last frame's upload isn't done
    _textureBuilding = true;

    try {
      final pixels = _velocityField.toPixels();

      final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width:       VelocityField.kSize,
        height:      VelocityField.kSize,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();

      final oldTexture = _velocityTexture;
      _velocityTexture = frame.image;
      oldTexture?.dispose();

      // Cleanup
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
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
      nx, ny,
      details.delta.dx * 12.0 / _size.width,
      details.delta.dy * 12.0 / _size.height,
      aspect: aspect,
    );

    // Keep old uniforms alive — Phase 4.3 removes them
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
        child: _loaded && _shader != null
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
            : const SizedBox.shrink(),
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

    // Phase 4.2 — velocity field texture (sampler slot 0)
    if (state._velocityTexture != null) {
      shader.setImageSampler(0, state._velocityTexture!);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_FluidPainter old) => false;
}