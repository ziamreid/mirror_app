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
//   [2048 .. 3071] = pixel R values as floats (0..255)  velX encoded
//   [3072 .. 4095] = pixel G values as floats (0..255)  velY encoded
Float32List _physicsStep(List<dynamic> args) {
  final Float32List velX = args[0] as Float32List;
  final Float32List velY = args[1] as Float32List;
  final double      dt   = args[2] as double;

  final field = VelocityField.fromArrays(velX, velY);
  field.step(dt);

  const int n = VelocityField.kCells;
  final out   = Float32List(n * 4);

  for (int i = 0; i < n; i++) {
    out[i]     = field.velX[i];
    out[n + i] = field.velY[i];
  }
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
  bool                _loaded = false;
  String?             _errorMessage;

  double _time       = 0.0;
  double _breath     = 0.5;
  Size   _size       = Size.zero;

  // Touch state — drives smooth gaussian smear in shader (pixel-perfect)
  Offset _touch      = const Offset(0.5, 0.5);
  Offset _velocity   = Offset.zero;
  double _touchForce = 0.0;

  // Gyro — wired in Phase B. Zero placeholder keeps uniform slot filled.
  final Offset _gyro = Offset.zero;

  final _velocityField = VelocityField();
  ui.Image? _velocityTexture;

  bool _physicsRunning = false;

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
      await _buildTextureOnce();
      if (mounted) setState(() => _loaded = true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

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

    // Breath — always runs
    final breathCycle = (t % 8.0) / 8.0;
    _breath = (sin(breathCycle * 2 * pi - pi / 2) + 1.0) / 2.0;

    // Touch force decay — 1.2s to fully decay
    _touchForce = (_touchForce - dt * 0.85).clamp(0.0, 1.0);

    // Velocity decay — smooths out between drag events
    _velocity = _velocity * 0.85;

    if (!_physicsRunning && dt < 0.033) {
      _dispatchPhysics(dt);
    }

    _repaint.value++;
  }

  void _dispatchPhysics(double dt) {
    _physicsRunning = true;

    final velXSnap = Float32List.fromList(_velocityField.velX);
    final velYSnap = Float32List.fromList(_velocityField.velY);

    compute<List<dynamic>, Float32List>(
      _physicsStep,
      [velXSnap, velYSnap, dt],
    ).then((Float32List result) {
      const int n = VelocityField.kCells;

      _velocityField.velX.setAll(0, result.sublist(0, n));
      _velocityField.velY.setAll(0, result.sublist(n, n * 2));

      for (int i = 0; i < n; i++) {
        _pixelBuffer[i * 4 + 0] = result[n * 2 + i].toInt();
        _pixelBuffer[i * 4 + 1] = result[n * 3 + i].toInt();
        _pixelBuffer[i * 4 + 2] = 0;
        _pixelBuffer[i * 4 + 3] = 255;
      }

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

  // ─── Touch handlers ───────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails details) {
    if (_size == Size.zero) return;
    final nx     = details.localPosition.dx / _size.width;
    final ny     = details.localPosition.dy / _size.height;
    final aspect = _size.width / _size.height;
    _touch      = Offset(nx, ny);
    _touchForce = 1.0;
    // Radial burst into physics grid
    _velocityField.addForce(nx, ny,  0.08,  0.0,  aspect: aspect);
    _velocityField.addForce(nx, ny, -0.08,  0.0,  aspect: aspect);
    _velocityField.addForce(nx, ny,  0.0,   0.08, aspect: aspect);
    _velocityField.addForce(nx, ny,  0.0,  -0.08, aspect: aspect);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_size == Size.zero) return;
    final nx     = details.localPosition.dx / _size.width;
    final ny     = details.localPosition.dy / _size.height;
    final aspect = _size.width / _size.height;
    final vx     = details.delta.dx / _size.width;
    final vy     = details.delta.dy / _size.height;

    _touch      = Offset(nx, ny);
    _velocity   = Offset(vx, vy);
    _touchForce = 1.0;

    // Physics grid still gets force for glow trail
    _velocityField.addForce(
      nx, ny,
      vx * 12.0,
      vy * 12.0,
      aspect: aspect,
    );
  }

  void _onPanEnd(DragEndDetails details) {
    if (_size == Size.zero) return;
    final vel    = details.velocity.pixelsPerSecond;
    final aspect = _size.width / _size.height;
    // Inject final momentum into physics grid for glow trail continuation
    _velocityField.addForce(
      _touch.dx, _touch.dy,
      vel.dx * 0.0008,
      vel.dy * 0.0008,
      aspect: aspect,
    );
    // Keep velocity for shader smear inertia — decays naturally in _onTick
    _velocity = Offset(
      vel.dx * 0.0005,
      vel.dy * 0.0005,
    );
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

// ─── Painter ──────────────────────────────────────────────────────────────────
class _FluidPainter extends CustomPainter {
  final ui.FragmentShader _shader;
  final _FluidScreenState _state;

  _FluidPainter({
    required ui.FragmentShader shader,
    required _FluidScreenState state,
    required Listenable repaint,
  })  : _shader = shader,
        _state  = state,
        super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final texture = _state._velocityTexture;
    if (texture == null) return;

    // Uniform slot map — must match fluid.frag exactly:
    //   0        u_time
    //   1, 2     u_resolution
    //   3        u_breath
    //   4, 5     u_gyro
    //   6, 7     u_touch
    //   8, 9     u_velocity
    //   10       u_touchForce
    //   sampler0 u_velocityField
    _shader.setFloat(0,  _state._time);
    _shader.setFloat(1,  size.width);
    _shader.setFloat(2,  size.height);
    _shader.setFloat(3,  _state._breath);
    _shader.setFloat(4,  _state._gyro.dx);
    _shader.setFloat(5,  _state._gyro.dy);
    _shader.setFloat(6,  _state._touch.dx);
    _shader.setFloat(7,  _state._touch.dy);
    _shader.setFloat(8,  _state._velocity.dx);
    _shader.setFloat(9,  _state._velocity.dy);
    _shader.setFloat(10, _state._touchForce);

    _shader.setImageSampler(0, texture);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = _shader,
    );
  }

  @override
  bool shouldRepaint(_FluidPainter old) => false;
}