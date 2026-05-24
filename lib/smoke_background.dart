import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum SmokeStage { fog, processing, clarity }

class SmokeBackground extends StatefulWidget {
  final SmokeStage stage;
  final Widget? child;

  const SmokeBackground({
    super.key,
    this.stage = SmokeStage.fog,
    this.child,
  });

  @override
  State<SmokeBackground> createState() => _SmokeBackgroundState();
}

class _SmokeBackgroundState extends State<SmokeBackground>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  ui.FragmentShader? _shader;

  double _time = 0.0;
  DateTime? _lastTick;

  // Touch state
  Offset _touch        = const Offset(-1, -1);
  Offset _prevTouch    = const Offset(-1, -1);
  Offset _touchVel     = Offset.zero;
  double _touchStrength = 0.0; // springs up on contact, decays on release
  bool   _isTouching   = false;

  // Stage uniforms — smoothly animated
  double _clarity    = 0.0, _clarityTarget    = 0.0;
  double _processing = 0.0, _processingTarget = 0.0;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(SmokeBackground old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) _applyStage(widget.stage);
  }

  void _applyStage(SmokeStage s) {
    _clarityTarget    = s == SmokeStage.clarity    ? 1.0 : 0.0;
    _processingTarget = s == SmokeStage.processing ? 1.0 : 0.0;
  }

  Future<void> _loadShader() async {
    try {
      final prog = await ui.FragmentProgram.fromAsset('assets/shaders/smoke.frag');
      if (mounted) setState(() => _shader = prog.fragmentShader());
      _applyStage(widget.stage);
    } catch (e) {
      debugPrint('Shader load error: $e');
    }
  }

  void _onTick(Duration _) {
    final now = DateTime.now();
    final dt  = _lastTick == null
        ? 0.016
        : (now.difference(_lastTick!).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = now;

    _time += dt;

    // Smooth stage transitions
    _clarity    += (_clarityTarget    - _clarity)    * 0.010 * 60 * dt;
    _processing += (_processingTarget - _processing) * 0.015 * 60 * dt;

    // Touch strength: spring up instantly, decay smoothly when finger lifts
    if (_isTouching) {
      _touchStrength += (1.0 - _touchStrength) * 0.18 * 60 * dt;
    } else {
      _touchStrength *= pow(0.92, 60 * dt); // smooth exponential decay
      if (_touchStrength < 0.005) _touchStrength = 0.0;
    }

    // Velocity decay
    _touchVel = _touchVel * pow(0.88, 60 * dt);

    if (mounted) setState(() {});
  }

  double pow(double base, double exp) => base == 0 ? 0 : _fastPow(base, exp);
  double _fastPow(double b, double e) {
    // Simple iterative for small exponents in hot path
    double result = 1.0;
    double remaining = e;
    while (remaining > 1.0) { result *= b; remaining -= 1.0; }
    return result * (1.0 - remaining + remaining * b);
  }

  void _onPanStart(DragStartDetails d, Size size) {
    _isTouching = true;
    _touch      = _normalizeTouch(d.localPosition, size);
    _prevTouch  = _touch;
    _touchVel   = Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    final newTouch = _normalizeTouch(d.localPosition, size);
    // Velocity = delta position this frame (already normalized)
    final vel = newTouch - _prevTouch;
    // Low-pass filter velocity for smoothness
    _touchVel  = Offset(
      _touchVel.dx * 0.6 + vel.dx * 0.4 * 18,
      _touchVel.dy * 0.6 + vel.dy * 0.4 * 18,
    );
    _prevTouch = _touch;
    _touch     = newTouch;
  }

  void _onPanEnd(DragEndDetails d) {
    _isTouching = false;
    // Keep last position so decay looks natural
  }

  void _onTapDown(TapDownDetails d, Size size) {
    _isTouching = true;
    _touch      = _normalizeTouch(d.localPosition, size);
    _touchVel   = Offset.zero;
  }

  void _onTapUp(TapUpDetails d) {
    _isTouching = false;
  }

  Offset _normalizeTouch(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    // Flip Y: Flutter y=0 is top, GLSL y=0 is bottom
    (1.0 - local.dy / size.height).clamp(0.0, 1.0),
  );

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        onPanStart:  (d) => _onPanStart(d, size),
        onPanUpdate: (d) => _onPanUpdate(d, size),
        onPanEnd:    _onPanEnd,
        onTapDown:   (d) => _onTapDown(d, size),
        onTapUp:     _onTapUp,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _SmokePainter(
                shader:        _shader,
                time:          _time,
                touch:         _touch,
                touchVel:      _touchVel,
                touchStrength: _touchStrength.clamp(0.0, 1.0),
                clarity:       _clarity.clamp(0.0, 1.0),
                processing:    _processing.clamp(0.0, 1.0),
              ),
            ),
            if (widget.child != null) widget.child!,
          ],
        ),
      );
    });
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────
// Uniform layout (matches smoke.frag):
//   0,1  uResolution
//   2    uTime
//   3,4  uTouch
//   5,6  uTouchVel
//   7    uTouchStrength
//   8    uClarity
//   9    uProcessing
class _SmokePainter extends CustomPainter {
  final ui.FragmentShader? shader;
  final double time, touchStrength, clarity, processing;
  final Offset touch, touchVel;

  _SmokePainter({
    required this.shader,
    required this.time,
    required this.touch,
    required this.touchVel,
    required this.touchStrength,
    required this.clarity,
    required this.processing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shader == null) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = const Color(0xFF090910));
      return;
    }
    shader!
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, touch.dx)
      ..setFloat(4, touch.dy)
      ..setFloat(5, touchVel.dx)
      ..setFloat(6, touchVel.dy)
      ..setFloat(7, touchStrength)
      ..setFloat(8, clarity)
      ..setFloat(9, processing);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_SmokePainter o) => true;
}
