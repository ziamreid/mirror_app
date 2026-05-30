import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class LiquidGlassCard extends StatelessWidget {
  final bool   selected;
  final Offset orbOffset;
  final double proximity;
  final double cornerRadius;
  final double height;
  final Widget child;

  static const _orbColor = Color(0xFFd946ef);

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
    final radius = BorderRadius.circular(cornerRadius);

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [

            // ── ONLY layer: pure blur + near-zero tint ───────────────────
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Pure glass — no tint, just frosted
                  color: selected
                      ? const Color(0x1Aa855f7)
                      : const Color(0x0CFFFFFF),
                  borderRadius: radius,
                  border: Border.all(
                    // Single thin uniform border — exactly like Apple
                    color: selected
                        ? const Color(0x55a855f7)
                        : const Color(0x28FFFFFF),
                    width: 0.5,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────
            child,
          ],
        ),
      ),
    );
  }
}