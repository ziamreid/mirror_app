import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidGlassCard extends StatelessWidget {
  final bool   selected;
  final Offset orbOffset;
  final double proximity;
  final double cornerRadius;
  final double height;
  final Widget child;

  const LiquidGlassCard({
    super.key,
    required this.selected,
    required this.child,
    this.orbOffset    = const Offset(0.5, 0.5),
    this.proximity    = 0.0,
    this.cornerRadius = 20.0,
    this.height       = 84.0,
  });

  @override
  Widget build(BuildContext context) {
    final rr = BorderRadius.circular(cornerRadius);

    final fillColor = selected
        ? Color.lerp(
            const Color(0x20a855f7),
            const Color(0x38a855f7),
            proximity,
          )!
        : Color.lerp(
            const Color(0x14FFFFFF),
            const Color(0x28c026d3),
            proximity,
          )!;

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: rr,
        // antiAliasWithSaveLayer composites into an offscreen buffer FIRST,
        // then clips — so the blur edge is mathematically contained inside
        // the rounded rect. This is the only mode with zero edge leak.
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: fillColor,
              border: Border.all(
                strokeAlign: BorderSide.strokeAlignInside,
                color: selected
                    ? const Color(0x44a855f7)
                    : Color.fromARGB(
                        ((0.15 + proximity * 0.15) * 255).round().clamp(0, 255),
                        255, 255, 255,
                      ),
                width: 0.8,
              ),
              borderRadius: rr,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}