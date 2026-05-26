import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'velocity_field.dart';

void main() {
  runApp(const MyApp());
}

// ─── Isolate function ─────────────────────────────────────────────────────────
// Receives: [Float32List velX, Float32List velY, double dt]
// Returns:  Float32List packed as:
//   [0    .. 1023] = updated velX
//   [1024 .. 2047] = updated velY
//   [2048 .. 3071] = pixel R values as floats (0..255)
//   [3072 .. 4095] = pixel G values as floats (0..255)
// We avoid Uint8List crossing isolate boundary by using Float32List throughout.
Float32List _physicsStep(List<dynamic> args) {
  final Float32List velX = args[0] as Float32List;
  final Float32List velY = args[1] as Float32List;
  final double      dt   = args[2] as double;

  final field = VelocityField.fromArrays(velX, velY);
  field.step(dt);

  const int n = VelocityField.kCells; // 1024
  final out   = Float32List(n * 4);

  // Pack velX and velY
  for (int i = 0; i < n; i++) {
    out[i]         = field.velX[i];
    out[n + i]     = field.velY[i];
  }

  // Pack encoded pixel channels (R=velX encoded, G=velY encoded)
  for (int i = 0; i < n; i++) {
    final vx = field.velX[i].clamp(-1.0, 1.0);
    final vy = field.velY[i].clamp(-1.0, 1.0);
    out[n * 2 + i] = (vx * 127.5 + 127.5).roundToDouble();
    out[n * 3 + i] = (vy * 127.5 + 127.5).roundToDouble();
  }

  return out;
}

// ─── App ──────────────────────────────────────────────────────────────────────
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
  bool                _loaded  = false;
  String?             _errorMessage;

  double _time       = 0.0;
  double _breath     = 0.5;
  Offset _touch      = const Offset(0.5, 0.5);
  double _touchForce = 0.0;
  Offset _velocity   = Offset.zero;
  final Offset _gyro = Offset.zero;
  Size   _size       = Size.zero;

  final _velocityField  = VelocityField();
  ui.Image? _velocityTexture;

  // True while isolate is running — prevents stacking physics calls
  bool _physicsRunning = false;

  // Pre-allocated RGBA pixel buffer for decodeImageFromPixels
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
      // Build first texture synchronously — guarantees sampler bound before paint
      await _buildTextureOnce();
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  // Startup only — awaitable so we never paint without a texture
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

  void _onTick(Duration elapsed) {
    if (!_loaded) return;

    final t  = elapsed.inMilliseconds / 1000.0;
    final dt = (t - _time).clamp(0.0, 0.05);
    _time    = t;

    // Breath animation always runs — never blocked
    final breathCycle = (t % 8.0) / 8.0;
    _breath = (sin(breathCycle * 2 * pi - pi / 2) + 1.0) / 2.0;

    _touchForce = (_touchForce - dt * 0.8).clamp(0.0, 1.0);
    _velocity   = _velocity * 0.88;

    // Dispatch physics to isolate only if previous one finished
    // and frame isn't running late
    if (!_physicsRunning && dt < 0.033) {
      _dispatchPhysics(dt);
    }

    // Render always happens regardless of physics state
    _repaint.value++;
  }

  void _dispatchPhysics(double dt) {
    _physicsRunning = true;

    // Snapshot current arrays — isolate gets independent copies
    final velXSnap = Float32List.fromList(_velocityField.velX);
    final velYSnap = Float32List.fromList(_velocityField.velY);

    compute<List<dynamic>, Float32List>(
      _physicsStep,
      [velXSnap, velYSnap, dt],
    ).then((Float32List result) {
      const int n = VelocityField.kCells;

      // Unpack updated velocity arrays back into our field
      _velocityField.velX.setAll(0, result.sublist(0, n));
      _velocityField.velY.setAll(0, result.sublist(n, n * 2));

      // Unpack pixel channels into RGBA buffer
      for (int i = 0; i < n; i++) {
        _pixelBuffer[i * 4 + 0] = result[n * 2 + i].toInt(); // R = velX encoded
        _pixelBuffer[i * 4 + 1] = result[n * 3 + i].toInt(); // G = velY encoded
        _pixelBuffer[i * 4 + 2] = 0;
        _pixelBuffer[i * 4 + 3] = 255;
      }

      // Decode into GPU texture — fast, pixels already ready
      ui.decodeImageFromPixels(
        _pixelBuffer,
        VelocityField.kSize,
        VelocityField.kSize,
        ui.PixelFormat.rgba8888,
        (ui.Image img) {
          final old = _velocityTexture;
          _velocityTexture = img;
          old?.dispose();
          _physicsRunning = false;
        },
      );
    }).catchError((Object e) {
      debugPrint('Physics isolate error: $e');
      _physicsRunning = false;
    });
  }

  // Burst on finger landing — fluid parts immediately on touch
  void _onPanStart(DragStartDetails details) {
    if (_size == Size.zero) return;
    final nx     = details.localPosition.dx / _size.width;
    final ny     = details.localPosition.dy / _size.height;
    final aspect = _size.width / _size.height;
    // Radial burst — inject force outward in 4 directions
    _velocityField.addForce(nx, ny,  0.08,  0.0,  aspect: aspect);
    _velocityField.addForce(nx, ny, -0.08,  0.0,  aspect: aspect);
    _velocityField.addForce(nx, ny,  0.0,   0.08, aspect: aspect);
    _velocityField.addForce(nx, ny,  0.0,  -0.08, aspect: aspect);
    _touch      = Offset(nx, ny);
    _touchForce = 1.0;
  }

  // Natural lift-off — inject final velocity on release
  void _onPanEnd(DragEndDetails details) {
    final vel = details.velocity.pixelsPerSecond;
    if (_size == Size.zero) return;
    final nx     = _touch.dx;
    final ny     = _touch.dy;
    final aspect = _size.width / _size.height;
    _velocityField.addForce(
      nx, ny,
      vel.dx * 0.0008,
      vel.dy * 0.0008,
      aspect: aspect,
    );
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
        onPanStart:  _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd:    _onPanEnd,
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