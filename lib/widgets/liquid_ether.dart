import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'touch_point.dart';
import 'liquid_ether_painter.dart';

class LiquidEther extends StatefulWidget {
  final Widget? child;
  final double flowSpeed;       // default: 0.25
  final double turbulence;      // default: 1.0  
  final double glowIntensity;   // default: 1.0
  final double emotionalState;  // 0=fog, 1=processing, 2=clarity, 3=conviction
  final bool interactable;      // default: true
  
  const LiquidEther({
    super.key,
    this.child,
    this.flowSpeed = 0.25,
    this.turbulence = 1.0,
    this.glowIntensity = 1.0,
    this.emotionalState = 1.0,  // Default to processing state
    this.interactable = true,
  });

  @override
  State<LiquidEther> createState() => _LiquidEtherState();
}

class _LiquidEtherState extends State<LiquidEther> with SingleTickerProviderStateMixin {
  FragmentShader? _shader;
  Ticker? _ticker;
  double _time = 0.0;
  Duration _lastElapsed = Duration.zero;
  final List<TouchPoint> _touches = [];
  double _idleTime = 0.0;  // Track time since last touch
  double _idleBreath = 0.0;  // Breathing animation value
  double _touchActivity = 0.0;  // Smoothly lerps 0→1 on touch, back to 0 when idle
  
  // Custom repaint notifier to isolate animation ticks and avoid widget rebuilds
  late final _FluidRepaintNotifier _repaintNotifier;

  @override
  void initState() {
    super.initState();
    _repaintNotifier = _FluidRepaintNotifier();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      // Loads the pre-compiled shader program from the assets
      final program = await FragmentProgram.fromAsset('lib/shaders/fluid.frag');
      if (mounted) {
        setState(() {
          _shader = program.fragmentShader();
        });
        _startTicker();
      }
    } catch (e) {
      debugPrint('Failed to load fluid shader: $e');
    }
  }

  void _startTicker() {
    _ticker = createTicker((elapsed) {
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final dt = (elapsed.inMicroseconds - _lastElapsed.inMicroseconds) / 1000000.0;
      _lastElapsed = elapsed;

      // Update shader time uniform
      _time += dt;

      // Track idle time
      if (_touches.isEmpty) {
        _idleTime += dt;
      } else {
        _idleTime = 0.0;
      }

      // Calculate idle breathing (0 to 1 pulse)
      _idleBreath = (_idleTime > 3.0) ? 0.5 + 0.5 * sin(_time * 0.4) : 0.0;

      // Smooth touch activity lerp
      final targetActivity = _touches.isEmpty ? 0.0 : 1.0;
      _touchActivity += (targetActivity - _touchActivity) * (dt * 3.0).clamp(0.0, 1.0);

      // Decay and prune inactive touch points (in reverse to prevent indexing issues)
      for (int i = _touches.length - 1; i >= 0; i--) {
        final tp = _touches[i];
        tp.decay(dt);
        if (tp.strength < 0.001) {
          _touches.removeAt(i);
        }
      }

      // Notify the custom painter to repaint (bypasses build/layout stages)
      _repaintNotifier.update(
        _time,
        _touches,
        _idleBreath,
        _touchActivity,
        widget.emotionalState,
      );
    });
    _ticker!.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaintNotifier.dispose();
    super.dispose();
  }

  void _addTouch(int pointerId, Offset position) {
    if (!widget.interactable) return;
    if (_touches.length >= 5) return; // Cap at maximum 5 concurrent touches
    
    // Prevent double-registration of the same pointer
    if (_touches.any((t) => t.id == pointerId)) return;

    _touches.add(TouchPoint(
      id: pointerId,
      position: position,
      strength: 1.0,
      velocityMagnitude: 0.0,
      trailLength: 0.0,
      active: true,
    ));
    _repaintNotifier.update(
      _time,
      _touches,
      _idleBreath,
      _touchActivity,
      widget.emotionalState,
    );
  }

  void _updateTouch(int pointerId, Offset position) {
    if (!widget.interactable) return;
    final index = _touches.indexWhere((t) => t.id == pointerId);
    if (index != -1) {
      final tp = _touches[index];
      final dt = 1.0 / 60.0; // Approximate frame time
      tp.updatePosition(position, dt);
      tp.strength = 1.0; // Maintain full strength while pressing
      tp.active = true;
      _repaintNotifier.update(
        _time,
        _touches,
        _idleBreath,
        _touchActivity,
        widget.emotionalState,
      );
    }
  }

  void _releaseTouch(int pointerId) {
    final index = _touches.indexWhere((t) => t.id == pointerId);
    if (index != -1) {
      // Release active status to begin strength decay phase
      _touches[index].active = false;
    }
  }

  @override
  void didUpdateWidget(covariant LiquidEther oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Push parameter changes directly to the paint notifier if the widget is rebuilt externally
    _repaintNotifier.update(
      _time,
      _touches,
      _idleBreath,
      _touchActivity,
      widget.emotionalState,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    
    if (shader == null) {
      // Solid dark palette background fallback during compilation/initialization
      return Container(
        color: const Color(0xFF060312),
        child: widget.child,
      );
    }

    Widget fluidCanvas = AnimatedBuilder(
      animation: _repaintNotifier,
      builder: (context, _) {
        return CustomPaint(
          painter: LiquidEtherPainter(
            shader: shader,
            time: _repaintNotifier.time,
            touches: _repaintNotifier.touches,
            flowSpeed: widget.flowSpeed,
            turbulence: widget.turbulence,
            glowIntensity: widget.glowIntensity,
            idleBreath: _repaintNotifier.idleBreath,
            touchActivity: _repaintNotifier.touchActivity,
            emotionalState: _repaintNotifier.emotionalState,
          ),
        );
      },
    );

    // If gesture interactions are enabled, wrap the CustomPaint in raw listener
    if (widget.interactable) {
      fluidCanvas = Listener(
        onPointerDown: (e) => _addTouch(e.pointer, e.localPosition),
        onPointerMove: (e) => _updateTouch(e.pointer, e.localPosition),
        onPointerUp: (e) => _releaseTouch(e.pointer),
        onPointerCancel: (e) => _releaseTouch(e.pointer),
        child: fluidCanvas,
      );
    }

    // RepaintBoundary isolates the shader painting layer from the parent and child layers
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          fluidCanvas,
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

// Data notifier holding fluid state variables to trigger repaint-only frames
class _FluidRepaintNotifier extends ChangeNotifier {
  double _time = 0.0;
  List<TouchPoint> _touches = [];
  double _idleBreath = 0.0;
  double _touchActivity = 0.0;
  double _emotionalState = 1.0;

  double get time => _time;
  List<TouchPoint> get touches => _touches;
  double get idleBreath => _idleBreath;
  double get touchActivity => _touchActivity;
  double get emotionalState => _emotionalState;

  void update(
    double time,
    List<TouchPoint> touches,
    double idleBreath,
    double touchActivity,
    double emotionalState,
  ) {
    _time = time;
    _touches = List.from(touches);
    _idleBreath = idleBreath;
    _touchActivity = touchActivity;
    _emotionalState = emotionalState;
    notifyListeners();
  }
}
