import 'package:flutter/rendering.dart';

class TouchPoint {
  final int id;
  Offset position;
  Offset lastPosition;  // Previous frame position for velocity calculation
  Offset velocity;      // Direction + speed of swipe
  double strength;      // 0.0 to 1.0
  double velocityMagnitude;  // Speed in pixels per second
  double trailLength;   // Elongation based on speed magnitude (0.0=tap, 1.0=fast swipe)
  bool active;          // Track if the finger is currently pressing

  TouchPoint({
    required this.id,
    required this.position,
    this.strength = 1.0,
    this.velocity = Offset.zero,
    this.velocityMagnitude = 0.0,
    this.trailLength = 0.0,
    this.active = true,
  }) : lastPosition = position;

  // Update position and calculate velocity from frame-to-frame movement
  void updatePosition(Offset newPosition, double dt) {
    lastPosition = position;
    position = newPosition;
    
    if (dt > 0) {
      // Calculate 2D velocity vector
      velocity = (newPosition - lastPosition) / dt;
      velocityMagnitude = velocity.distance;
      // Trail length increases with speed (normalized to 300 px/sec max)
      trailLength = (velocityMagnitude / 300.0).clamp(0.0, 1.0);
    }
  }

  // Strength decays at 1.2/sec when the finger is lifted
  void decay(double dt) {
    if (!active) {
      strength = (strength - dt * 1.2).clamp(0.0, 1.0);
      // Exponential velocity decay for momentum carry-through
      velocity = velocity * (1.0 - dt * 2.5).clamp(0.0, 1.0);
      velocityMagnitude = velocity.distance;
      trailLength = (velocityMagnitude / 300.0).clamp(0.0, 1.0);
    }
  }
}
