import 'package:flutter/material.dart';
import '../fluid_painter.dart';

/// Wraps any child and smoothly inverts its color (white → black)
/// when the fluid orb passes over it, then returns to white as it moves away.
class OrbAwareText extends StatelessWidget {
  final FluidEngine        engine;
  final ValueNotifier<int> repaint;
  final Widget             child;
  final double             innerRadius;
  final double             outerRadius;

  const OrbAwareText({
    super.key,
    required this.engine,
    required this.repaint,
    required this.child,
    this.innerRadius = 70,
    this.outerRadius = 140,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: repaint,
      builder: (context, _, __) {
        return _OrbColorFilter(
          engine:      engine,
          innerRadius: innerRadius,
          outerRadius: outerRadius,
          child:       child,
        );
      },
    );
  }
}

class _OrbColorFilter extends StatelessWidget {
  final FluidEngine engine;
  final double      innerRadius;
  final double      outerRadius;
  final Widget      child;

  const _OrbColorFilter({
    required this.engine,
    required this.innerRadius,
    required this.outerRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          foregroundPainter: null,
          child: _InvertingWidget(
            engine:      engine,
            innerRadius: innerRadius,
            outerRadius: outerRadius,
            child:       child,
          ),
        );
      },
    );
  }
}

class _InvertingWidget extends StatelessWidget {
  final FluidEngine engine;
  final double      innerRadius;
  final double      outerRadius;
  final Widget      child;

  const _InvertingWidget({
    required this.engine,
    required this.innerRadius,
    required this.outerRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // We use a CompositedTransformFollower approach — simpler:
    // just read orbX/orbY (normalised) and compare with this widget's
    // render position via a GlobalKey.
    return _OrbAwareBuilder(
      engine:      engine,
      innerRadius: innerRadius,
      outerRadius: outerRadius,
      child:       child,
    );
  }
}

class _OrbAwareBuilder extends StatefulWidget {
  final FluidEngine engine;
  final double      innerRadius;
  final double      outerRadius;
  final Widget      child;

  const _OrbAwareBuilder({
    required this.engine,
    required this.innerRadius,
    required this.outerRadius,
    required this.child,
  });

  @override
  State<_OrbAwareBuilder> createState() => _OrbAwareBuilderState();
}

class _OrbAwareBuilderState extends State<_OrbAwareBuilder> {
  final GlobalKey _key = GlobalKey();

  double _t = 0.0;

  double _computeT() {
    final ctx = _key.currentContext;
    if (ctx == null) return 0.0;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0.0;

    final screenSize = MediaQuery.of(ctx).size;

    // Orb position in screen pixels
    final orbPx = Offset(
      widget.engine.orbX * screenSize.width,
      widget.engine.orbY * screenSize.height,
    );

    // Widget center in screen pixels
    final widgetOffset = box.localToGlobal(Offset.zero);
    final widgetCenter = widgetOffset + Offset(box.size.width / 2, box.size.height / 2);

    final dist = (orbPx - widgetCenter).distance;

    if (dist >= widget.outerRadius) return 0.0;
    double t = (widget.outerRadius - dist) / (widget.outerRadius - widget.innerRadius);
    t = t.clamp(0.0, 1.0);
    // Smooth step
    return t * t * (3 - 2 * t);
  }

  @override
  Widget build(BuildContext context) {
    _t = _computeT();

    // ColorFilter matrix lerp: identity (t=0) → invert (t=1)
    final v = _t;
    final matrix = <double>[
      1 - 2 * v, 0,         0,         0, 255 * v,
      0,         1 - 2 * v, 0,         0, 255 * v,
      0,         0,         1 - 2 * v, 0, 255 * v,
      0,         0,         0,         1, 0,
    ];

    return ColorFiltered(
      key: _key,
      colorFilter: ColorFilter.matrix(matrix),
      child: widget.child,
    );
  }
}