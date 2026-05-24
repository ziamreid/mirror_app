import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FluidBackground extends StatefulWidget {
  const FluidBackground({super.key});

  @override
  State<FluidBackground> createState() => _FluidBackgroundState();
}

class _FluidBackgroundState extends State<FluidBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Particle> _particles = List.generate(72, (_) => _Particle());
  final List<_TouchSample> _trail = <_TouchSample>[];

  Size _size = Size.zero;
  Offset? _touchPoint;
  Offset _touchVelocity = Offset.zero;
  bool _isTouching = false;
  double _time = 0;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    final dt = previous == null
        ? 1 / 60
        : (elapsed - previous).inMicroseconds / 1000000.0;

    _time += dt;

    for (final particle in _particles) {
      particle.update(
        dt: dt,
        size: _size,
        touchPoint: _touchPoint,
        touchVelocity: _touchVelocity,
        trail: _trail,
        isTouching: _isTouching,
        time: _time,
      );
    }

    for (final sample in _trail) {
      sample.life -= dt;
    }
    _trail.removeWhere((sample) => sample.life <= 0);

    if (mounted) {
      setState(() {});
    }
  }

  void _setTouch(Offset localPosition, {bool isNewContact = false}) {
    if (_touchPoint != null && !isNewContact) {
      _touchVelocity = localPosition - _touchPoint!;
    } else {
      _touchVelocity = Offset.zero;
    }

    _touchPoint = localPosition;
    _isTouching = true;
    _trail.insert(0, _TouchSample(localPosition));
    if (_trail.length > 10) {
      _trail.removeLast();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _clearTouch() {
    _touchPoint = null;
    _touchVelocity = Offset.zero;
    _isTouching = false;

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _setTouch(event.localPosition, isNewContact: true),
          onPointerMove: (event) => _setTouch(event.localPosition),
          onPointerUp: (_) => _clearTouch(),
          onPointerCancel: (_) => _clearTouch(),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _FluidPainter(
                particles: _particles,
                touchPoint: _touchPoint,
                touchVelocity: _touchVelocity,
                trail: _trail,
                isTouching: _isTouching,
                time: _time,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}

class _Particle {
  _Particle()
      : x = math.Random().nextDouble(),
        y = math.Random().nextDouble(),
        vx = (math.Random().nextDouble() - 0.5) * 0.12,
        vy = (math.Random().nextDouble() - 0.5) * 0.12,
        radius = math.Random().nextDouble() * 6.0 + 3.0,
        hue = 235 + math.Random().nextDouble() * 75,
        alpha = math.Random().nextDouble() * 0.55 + 0.28;

  double x;
  double y;
  double vx;
  double vy;
  double radius;
  double hue;
  double alpha;

  void update({
    required double dt,
    required Size size,
    required Offset? touchPoint,
    required Offset touchVelocity,
    required List<_TouchSample> trail,
    required bool isTouching,
    required double time,
  }) {
    if (size.isEmpty) {
      return;
    }

    final width = size.width;
    final height = size.height;
    final px = x * width;
    final py = y * height;

    final wave = math.sin(px * 0.010 + time * 0.9) + math.cos(py * 0.010 - time * 0.7);
    vx += math.cos(wave) * 0.0018 * dt * 60;
    vy += math.sin(wave) * 0.0018 * dt * 60;

    if (touchPoint != null) {
      final dx = px - touchPoint.dx;
      final dy = py - touchPoint.dy;
      final distance = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final force = math.max(0.0, 420.0 - distance) / 420.0;
      final push = force * 0.85;
      final swirlX = -dy / distance;
      final swirlY = dx / distance;
      vx += ((dx / distance) * push + swirlX * push * 0.6) * dt * 60;
      vy += ((dy / distance) * push + swirlY * push * 0.6) * dt * 60;

      if (isTouching) {
        vx += touchVelocity.dx * 0.04 * force;
        vy += touchVelocity.dy * 0.04 * force;
      }
    }

    for (final sample in trail) {
      final dx = px - sample.position.dx;
      final dy = py - sample.position.dy;
      final distance = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final force = math.max(0.0, 240.0 - distance) / 240.0;
      vx += (-dy / distance) * force * sample.life * 0.55 * dt * 60;
      vy += (dx / distance) * force * sample.life * 0.55 * dt * 60;
    }

    vx *= math.pow(0.985, dt * 60).toDouble();
    vy *= math.pow(0.985, dt * 60).toDouble();

    x += (vx * dt) / width;
    y += (vy * dt) / height;

    if (x < 0) x = 1;
    if (x > 1) x = 0;
    if (y < 0) y = 1;
    if (y > 1) y = 0;
  }
}

class _FluidPainter extends CustomPainter {
  _FluidPainter({
    required this.particles,
    required this.touchPoint,
    required this.touchVelocity,
    required this.trail,
    required this.isTouching,
    required this.time,
  });

  final List<_Particle> particles;
  final Offset? touchPoint;
  final Offset touchVelocity;
  final List<_TouchSample> trail;
  final bool isTouching;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF060610));

    final glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    for (final sample in trail) {
      final alpha = sample.life.clamp(0.0, 1.0) * 0.18;
      canvas.drawCircle(
        sample.position,
        54 + (1 - sample.life.clamp(0.0, 1.0)) * 42,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0x88C48CFF).withValues(alpha: alpha),
              const Color(0x00000000),
            ],
          ).createShader(Rect.fromCircle(center: sample.position, radius: 80)),
      );
    }

    for (var i = 0; i < particles.length; i++) {
      final a = particles[i];
      final ax = a.x * size.width;
      final ay = a.y * size.height;

      for (var j = i + 1; j < particles.length; j++) {
        final b = particles[j];
        final bx = b.x * size.width;
        final by = b.y * size.height;
        final dx = ax - bx;
        final dy = ay - by;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance < 84) {
          final alpha = (1 - distance / 84) * 0.10;
          final hue = (a.hue + b.hue) / 2;
          canvas.drawLine(
            Offset(ax, ay),
            Offset(bx, by),
            Paint()
              ..color = HSLColor.fromAHSL(alpha, hue, 0.75, 0.72).toColor()
              ..strokeWidth = 0.6,
          );
        }
      }
    }

    for (final particle in particles) {
      final x = particle.x * size.width;
      final y = particle.y * size.height;
      final pulse = 0.8 + math.sin(time * 2.4 + particle.x * 9) * 0.2;

      canvas.drawCircle(
        Offset(x, y),
        particle.radius * pulse,
        glowPaint..color = HSLColor.fromAHSL(particle.alpha * pulse, particle.hue, 0.8, 0.76).toColor(),
      );
    }

    if (touchPoint != null) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0x99C48CFF),
            const Color(0x004A1B7A),
          ],
        ).createShader(Rect.fromCircle(center: touchPoint!, radius: 150));
      canvas.drawCircle(touchPoint!, 150, glow);

      final direction = touchVelocity.distance;
      if (direction > 0.5) {
        final angle = touchVelocity.direction;
        final head = touchPoint! + Offset(math.cos(angle), math.sin(angle)) * 34;
        canvas.drawLine(
          touchPoint!,
          head,
          Paint()
            ..color = const Color(0xAAFFFFFF)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FluidPainter oldDelegate) => true;
}

class _TouchSample {
  _TouchSample(this.position) : life = 1.0;

  final Offset position;
  double life;
}