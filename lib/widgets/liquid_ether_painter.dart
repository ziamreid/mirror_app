import 'dart:ui';
import 'package:flutter/material.dart';
import 'touch_point.dart';

class LiquidEtherPainter extends CustomPainter {
  final FragmentShader shader;
  final double time;
  final List<TouchPoint> touches;
  final double flowSpeed;
  final double turbulence;
  final double glowIntensity;
  final double idleBreath;
  final double touchActivity;
  final double emotionalState;

  // Pre-allocated paint object to avoid garbage collection overhead during paint cycles
  final Paint _paint = Paint();

  LiquidEtherPainter({
    required this.shader,
    required this.time,
    required this.touches,
    required this.flowSpeed,
    required this.turbulence,
    required this.glowIntensity,
    required this.idleBreath,
    required this.touchActivity,
    required this.emotionalState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 0: uTime
    shader.setFloat(0, time);
    
    // 1-2: uResolution
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);

    // 3-12: Individual touch coordinates (uTouch1x, uTouch1y, uTouch2x, uTouch2y, etc.)
    for (int i = 0; i < 5; i++) {
      if (i < touches.length) {
        final tp = touches[i];
        final nx = tp.position.dx / size.width;
        final ny = tp.position.dy / size.height;
        shader.setFloat(3 + (i * 2), nx);
        shader.setFloat(3 + (i * 2) + 1, ny);
      } else {
        shader.setFloat(3 + (i * 2), 0.0);
        shader.setFloat(3 + (i * 2) + 1, 0.0);
      }
    }

    // 13-17: Individual touch strengths
    for (int i = 0; i < 5; i++) {
      if (i < touches.length) {
        shader.setFloat(13 + i, touches[i].strength);
      } else {
        shader.setFloat(13 + i, 0.0);
      }
    }

    // 18-27: Individual touch velocity vectors (normalized) — 2 floats per touch
    for (int i = 0; i < 5; i++) {
      if (i < touches.length) {
        final tp = touches[i];
        final velMag = tp.velocity.distance;
        if (velMag > 0.001) {
          final velDir = tp.velocity / velMag;
          // Normalize to screen space
          shader.setFloat(18 + (i * 2), velDir.dx / size.width);
          shader.setFloat(18 + (i * 2) + 1, velDir.dy / size.height);
        } else {
          shader.setFloat(18 + (i * 2), 0.0);
          shader.setFloat(18 + (i * 2) + 1, 0.0);
        }
      } else {
        shader.setFloat(18 + (i * 2), 0.0);
        shader.setFloat(18 + (i * 2) + 1, 0.0);
      }
    }

    // 28-32: Individual touch trail lengths
    for (int i = 0; i < 5; i++) {
      if (i < touches.length) {
        shader.setFloat(28 + i, touches[i].trailLength);
      } else {
        shader.setFloat(28 + i, 0.0);
      }
    }
    
    // 33: uTouchCount
    shader.setFloat(33, touches.length.toDouble());
    
    // 34: uFlowSpeed
    shader.setFloat(34, flowSpeed);
    
    // 35: uTurbulence
    shader.setFloat(35, turbulence);
    
    // 36: uGlowIntensity
    shader.setFloat(36, glowIntensity);

    // 37: uEmotionalState (0=fog, 1=processing, 2=clarity, 3=conviction)
    shader.setFloat(37, emotionalState);

    // 38: uIdleBreath (breathing pulse when idle)
    shader.setFloat(38, idleBreath);

    // 39: uTouchActivity (0→1 on touch, back to 0 when idle)
    shader.setFloat(39, touchActivity);

    _paint.shader = shader;
    canvas.drawPaint(_paint);
  }

  @override
  bool shouldRepaint(covariant LiquidEtherPainter oldDelegate) {
    // True since the fluid self-animates and handles real-time pointer shifts
    return true;
  }
}
