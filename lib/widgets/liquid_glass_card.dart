import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget — drop-in replacement for the old _LiquidGlassCard
// ─────────────────────────────────────────────────────────────────────────────
class LiquidGlassCard extends StatefulWidget {
  final bool   selected;
  final double shimmer;      // 0→1 (Franko sweep)
  final double refraction;   // 0→1, default 1.0
  final double cornerRadius;
  final double height;
  final Widget child;

  const LiquidGlassCard({
    super.key,
    required this.selected,
    required this.child,
    this.shimmer      = 0.0,
    this.refraction   = 1.0,
    this.cornerRadius = 18.0,
    this.height       = 84.0,
  });

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard> {
  ui.FragmentShader? _shader;
  bool               _shaderFailed = false;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
      if (mounted) setState(() => _shader = program.fragmentShader());
    } catch (e) {
      // Shader unavailable (simulator / web) — fall back to blur glass
      if (mounted) setState(() => _shaderFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // While shader loads (or failed), use the blur fallback
    if (_shader == null) {
      return _BlurFallback(
        selected:     widget.selected,
        shimmer:      widget.shimmer,
        cornerRadius: widget.cornerRadius,
        height:       widget.height,
        child:        widget.child,
      );
    }

    return _ShaderCard(
      shader:       _shader!,
      selected:     widget.selected,
      shimmer:      widget.shimmer,
      refraction:   widget.refraction,
      cornerRadius: widget.cornerRadius,
      height:       widget.height,
      child:        widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The real shader card — captures the scene behind itself and renders the lens
// ─────────────────────────────────────────────────────────────────────────────
class _ShaderCard extends StatefulWidget {
  final ui.FragmentShader shader;
  final bool              selected;
  final double            shimmer;
  final double            refraction;
  final double            cornerRadius;
  final double            height;
  final Widget            child;

  const _ShaderCard({
    required this.shader,
    required this.selected,
    required this.shimmer,
    required this.refraction,
    required this.cornerRadius,
    required this.height,
    required this.child,
  });

  @override
  State<_ShaderCard> createState() => _ShaderCardState();
}

class _ShaderCardState extends State<_ShaderCard> {
  // We need a GlobalKey on the scene (FluidBackground) so we can capture it.
  // But since we don't own the scene widget, we use a different strategy:
  // we render the card in a Stack with a RepaintBoundary BELOW it capturing
  // just the orb layer, then pass that as texture to the shader.
  //
  // Strategy: use a _SceneCaptureController that the card registers with,
  // then the FluidBackground calls captureScene() each frame before painting
  // the card layer. We implement this via a simple InheritedWidget lookup.

  @override
  Widget build(BuildContext context) {
    // Look up the scene provider from FluidBackground
    final sceneProvider = _SceneProvider.of(context);

    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: _LensShaderPainter(
          shader:       widget.shader,
          sceneGetter:  sceneProvider?.getScene,
          selected:     widget.selected,
          shimmer:      widget.shimmer,
          refraction:   widget.refraction,
          cornerRadius: widget.cornerRadius,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.cornerRadius),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter that runs the fragment shader
// ─────────────────────────────────────────────────────────────────────────────
class _LensShaderPainter extends CustomPainter {
  final ui.FragmentShader      shader;
  final ui.Image? Function()?  sceneGetter;
  final bool                   selected;
  final double                 shimmer;
  final double                 refraction;
  final double                 cornerRadius;

  _LensShaderPainter({
    required this.shader,
    required this.sceneGetter,
    required this.selected,
    required this.shimmer,
    required this.refraction,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scene = sceneGetter?.call();

    if (scene == null) {
      // No scene yet — paint a simple frosted glass fallback
      _paintFallback(canvas, size);
      return;
    }

    // ── Set shader uniforms ────────────────────────────────────────────────
    shader.setFloat(0, size.width);       // uSize.x
    shader.setFloat(1, size.height);      // uSize.y
    shader.setImageSampler(0, scene);     // uScene
    shader.setFloat(2, cornerRadius);     // uCornerRadius
    shader.setFloat(3, refraction);       // uRefraction
    shader.setFloat(4, selected ? 1.0 : 0.0); // uSelected
    shader.setFloat(5, shimmer);          // uShimmer

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(cornerRadius),
    );

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
    canvas.restore();
  }

  void _paintFallback(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(cornerRadius),
    );
    // Simple semi-transparent glass
    canvas.drawRRect(rrect,
      Paint()..color = selected
          ? const Color(0x14a855f7)
          : const Color(0x10FFFFFF));
    // Border
    canvas.drawRRect(rrect,
      Paint()
        ..color       = const Color(0x44FFFFFF)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 0.9);
  }

  @override
  bool shouldRepaint(_LensShaderPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Scene capture infrastructure
// ─────────────────────────────────────────────────────────────────────────────

/// Controller — FluidBackground creates one and puts it in the tree via
/// [_SceneProvider]. Cards look it up to get the latest captured frame.
class SceneCaptureController {
  ui.Image? _lastScene;
  final _boundary = GlobalKey();

  GlobalKey get boundary => _boundary;

  ui.Image? getScene() => _lastScene;

  /// Call this once per frame BEFORE the card layer paints.
  Future<void> captureFrame() async {
    final ro = _boundary.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return;
    try {
      final img = await ro.toImage(pixelRatio: 1.0);
      _lastScene?.dispose();
      _lastScene = img;
    } catch (_) {}
  }

  void dispose() {
    _lastScene?.dispose();
    _lastScene = null;
  }
}

/// InheritedWidget that exposes the controller down the tree
class _SceneProvider extends InheritedWidget {
  final SceneCaptureController controller;

  const _SceneProvider({
    required this.controller,
    required super.child,
  });

  ui.Image? getScene() => controller.getScene();

  static _SceneProvider? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SceneProvider>();

  @override
  bool updateShouldNotify(_SceneProvider old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Blur fallback (used while shader loads or on unsupported platforms)
// ─────────────────────────────────────────────────────────────────────────────
class _BlurFallback extends StatelessWidget {
  final bool   selected;
  final double shimmer;
  final double cornerRadius;
  final double height;
  final Widget child;

  const _BlurFallback({
    required this.selected,
    required this.shimmer,
    required this.cornerRadius,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(cornerRadius),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(color: Colors.transparent),
            ),
          ),
          CustomPaint(
            painter: _FallbackPainter(
              selected:     selected,
              shimmer:      shimmer,
              cornerRadius: cornerRadius,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _FallbackPainter extends CustomPainter {
  final bool   selected;
  final double shimmer;
  final double cornerRadius;

  const _FallbackPainter({
    required this.selected,
    required this.shimmer,
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r     = cornerRadius;
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    canvas.drawRRect(rrect,
      Paint()..color = selected
          ? const Color(0x14a855f7)
          : const Color(0x08FFFFFF));

    if (shimmer > 0.0 && shimmer < 1.0) {
      final cx = size.width * (-0.3 + shimmer * 1.6);
      canvas.save();
      canvas.clipRRect(rrect);
      final sh = const LinearGradient(
        begin: Alignment.topLeft,
        end:   Alignment.bottomRight,
        colors: [
          Color(0x00FFFFFF), Color(0x00FFFFFF),
          Color(0x20FFFFFF), Color(0x30FFFFFF),
          Color(0x20FFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF),
        ],
        stops: [0.0, 0.28, 0.42, 0.50, 0.58, 0.72, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, size.height / 2), width: 180, height: size.height,
      ));
      canvas.drawRRect(rrect, Paint()..shader = sh);
      canvas.restore();
    }

    final topHL = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end:   Alignment.bottomCenter,
        colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 28));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, 26), const Radius.circular(17),
      ), topHL);

    canvas.drawRRect(rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: selected
              ? const [Color(0x88a855f7), Color(0x33a855f7), Color(0x11a855f7)]
              : const [Color(0x66FFFFFF), Color(0x22FFFFFF), Color(0x08FFFFFF)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 0.9);
  }

  @override
  bool shouldRepaint(_FallbackPainter old) =>
      old.selected != selected || old.shimmer != shimmer;
}