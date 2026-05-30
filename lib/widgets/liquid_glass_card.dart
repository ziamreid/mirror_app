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

    // Fill: near-zero at distance, violet wash as orb approaches
    final fillColor = selected
        ? Color.lerp(
            const Color(0x18a855f7),
            const Color(0x40a855f7),
            proximity,
          )!
        : Color.lerp(
            const Color(0x0AFFFFFF),   // almost invisible at distance
            const Color(0x2Ac026d3),   // violet tint when close
            proximity,
          )!;

    // Border alpha:
    // FIX #3 — at proximity=0 border is nearly invisible (alpha ~8)
    // FIX #2 — reacts strongly as orb approaches (up to alpha ~180)
    // This gives the "border lights up" Apple glass feel on drag
    final borderAlpha = selected
        ? (20 + proximity * 160).round().clamp(0, 255)
        : (8  + proximity * 172).round().clamp(0, 255);  // starts near-zero

    final borderColor = selected
        ? Color.fromARGB(borderAlpha, 168, 85,  247)
        : Color.fromARGB(borderAlpha, 220, 200, 255);    // cool white-violet

    // Inner glow: a subtle inner shadow that appears when orb is close
    // Mimics the Apple "light source behind glass" refraction feel
    final innerGlowAlpha = (proximity * 30).round().clamp(0, 255);

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: rr,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: CustomPaint(
            foregroundPainter: _GlassBorderPainter(
              selected:   selected,
              proximity:  proximity,
              orbOffset:  orbOffset,
              radius:     cornerRadius,
              borderColor: borderColor,
              innerGlowAlpha: innerGlowAlpha,
            ),
            child: Container(
              decoration: BoxDecoration(
                color:        fillColor,
                borderRadius: rr,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom border painter — reacts to orb position ───────────────────────────
// This replaces the static Border.all so we can vary opacity per-edge
// based on which side the orb is approaching from.
class _GlassBorderPainter extends CustomPainter {
  final bool   selected;
  final double proximity;
  final Offset orbOffset;   // normalised 0–1 relative to card
  final double radius;
  final Color  borderColor;
  final int    innerGlowAlpha;

  const _GlassBorderPainter({
    required this.selected,
    required this.proximity,
    required this.orbOffset,
    required this.radius,
    required this.borderColor,
    required this.innerGlowAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // ── Orb specular patch ────────────────────────────────────────────────
    // A soft radial glow on the glass surface where the orb sits behind it
    // This is the key Apple interaction — glass "focuses" the light behind it
    if (proximity > 0.03) {
      final ox   = orbOffset.dx * size.width;
      final oy   = orbOffset.dy * size.height;
      final glow = size.width * 0.50;
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawCircle(
        Offset(ox, oy),
        glow,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.fromARGB((proximity * 35).round().clamp(0, 255), 210, 120, 255),
              Color.fromARGB((proximity * 15).round().clamp(0, 255), 168, 85,  247),
              const Color(0x00000000),
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(ox, oy), radius: glow)),
      );
      canvas.restore();
    }

    // ── Outer border — brightens on the side closest to the orb ──────────
    // Compute a directional gradient so the near-orb edge glows brighter
    // This gives the "light wrapping around the glass edge" Apple effect
    final baseA  = borderColor.alpha;
    final dimA   = (baseA * 0.15).round().clamp(0, 255);  // far side is very dim

    // Orb direction: normalise to -1..1 from card center
    final dirX = (orbOffset.dx - 0.5) * 2.0;
    final dirY = (orbOffset.dy - 0.5) * 2.0;

    // Gradient runs from the orb-side (bright) to opposite (dim)
    final gradBegin = Alignment(dirX.clamp(-1.0, 1.0), dirY.clamp(-1.0, 1.0));
    final gradEnd   = Alignment(-dirX.clamp(-1.0, 1.0), -dirY.clamp(-1.0, 1.0));

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: gradBegin,
          end:   gradEnd,
          colors: [
            Color.fromARGB(baseA, borderColor.red, borderColor.green, borderColor.blue),
            Color.fromARGB(dimA,  borderColor.red, borderColor.green, borderColor.blue),
          ],
        ).createShader(rect)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = proximity > 0.1 ? 1.2 : 0.7,  // border thickens slightly on approach
    );

    // ── Inner inset border — subtle depth line ────────────────────────────
    if (proximity > 0.05) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          Radius.circular(radius - 1),
        ),
        Paint()
          ..color       = Color.fromARGB(
              (proximity * 25).round().clamp(0, 255), 255, 255, 255)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(_GlassBorderPainter old) =>
      old.proximity  != proximity  ||
      old.orbOffset  != orbOffset  ||
      old.selected   != selected   ||
      old.borderColor != borderColor;
}