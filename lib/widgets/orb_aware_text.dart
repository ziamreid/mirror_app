import 'package:flutter/material.dart';
import '../fluid_painter.dart';

/// Wraps any child. As the fluid orb approaches, the child brightens toward
/// white (orb far = normal color, orb close = glows white).
/// Uses a brighten ColorFilter matrix — never inverts.
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
      builder: (context, _, __) => _OrbAwareBuilder(
        engine:      engine,
        innerRadius: innerRadius,
        outerRadius: outerRadius,
        child:       child,
      ),
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

  double _computeT() {
    final ctx = _key.currentContext;
    if (ctx == null) return 0.0;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0.0;

    final screenSize = MediaQuery.of(ctx).size;
    final orbPx = Offset(
      widget.engine.orbX * screenSize.width,
      widget.engine.orbY * screenSize.height,
    );
    final widgetOffset = box.localToGlobal(Offset.zero);
    final widgetCenter = widgetOffset + Offset(box.size.width / 2, box.size.height / 2);
    final dist = (orbPx - widgetCenter).distance;

    if (dist >= widget.outerRadius) return 0.0;
    if (dist <= widget.innerRadius) return 1.0;
    double t = (widget.outerRadius - dist) / (widget.outerRadius - widget.innerRadius);
    t = t.clamp(0.0, 1.0);
    // Smooth step
    return t * t * (3 - 2 * t);
  }

  @override
  Widget build(BuildContext context) {
    final t = _computeT(); // 0 = far, 1 = close

    // Brighten matrix: adds up to +180 to each RGB channel as t → 1
    // At t=0 → pure identity (no effect). At t=1 → text glows white.
    // Matrix layout: [R_scale, 0, 0, 0, R_bias,  G_scale...  A_scale, A_bias]
    final bias = t * 180.0;
    final matrix = <double>[
      1, 0, 0, 0, bias,
      0, 1, 0, 0, bias,
      0, 0, 1, 0, bias,
      0, 0, 0, 1, 0,
    ];

    return ColorFiltered(
      key: _key,
      colorFilter: ColorFilter.matrix(matrix),
      child: widget.child,
    );
  }
}