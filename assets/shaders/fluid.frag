#include <flutter/runtime_effect.glsl>

uniform float u_time;
uniform vec2 u_resolution;
uniform vec2 u_touch;
uniform float u_touchForce;
uniform vec2 u_velocity;
uniform float u_breath;
uniform float u_pulse;

out vec4 fragColor;

vec2 hash(vec2 p) {
  p = vec2(dot(p, vec2(127.1, 311.7)),
           dot(p, vec2(269.5, 183.3)));
  return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(dot(hash(i + vec2(0.0,0.0)), f - vec2(0.0,0.0)),
        dot(hash(i + vec2(1.0,0.0)), f - vec2(1.0,0.0)), u.x),
    mix(dot(hash(i + vec2(0.0,1.0)), f - vec2(0.0,1.0)),
        dot(hash(i + vec2(1.0,1.0)), f - vec2(1.0,1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  vec2 shift = vec2(100.0);
  for (int i = 0; i < 6; i++) {
    value += amplitude * noise(p);
    p = p * 2.1 + shift;
    amplitude *= 0.5;
  }
  return value;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / u_resolution;
  float t = u_time * 0.3;

  // --- TOUCH DISPLACEMENT ---
  vec2 toTouch = uv - u_touch;
  float dist = length(toTouch);
  float touchDisplace = u_touchForce * 0.10 / (dist * dist + 0.015);
  touchDisplace = clamp(touchDisplace, 0.0, 0.08);
  vec2 displaced = uv + normalize(toTouch + vec2(0.001)) * touchDisplace;
  displaced += u_velocity * 0.03 * u_touchForce;

  // --- LAUNCH PULSE ---
  vec2 center = vec2(0.5, 0.5);
  float pulseRing = length(uv - center);
  float pulseMask = smoothstep(0.04, 0.0,
    abs(pulseRing - u_pulse * 0.9)) * (1.0 - u_pulse);
  displaced += normalize(uv - center + vec2(0.001)) * pulseMask * 0.06;

  // --- FBM DOMAIN WARP ---
  vec2 q = vec2(fbm(displaced + t),
                fbm(displaced + vec2(1.7, 9.2) + t * 0.8));
  vec2 r = vec2(fbm(displaced + 2.0 * q + vec2(1.7, 9.2) + t * 0.3),
                fbm(displaced + 2.0 * q + vec2(8.3, 2.8) + t * 0.5));
  float f = fbm(displaced + 2.5 * r + t * 0.2);

  f = 0.5 + 0.5 * f;
  f = pow(f, 1.8);

  // --- COLOR ---
  vec3 colorDark  = vec3(0.05, 0.04, 0.12);
  vec3 colorMid   = vec3(0.28, 0.15, 0.65);
  vec3 colorLight = vec3(0.55, 0.40, 0.95);
  vec3 colorBloom = vec3(0.85, 0.78, 1.00);

  vec3 color = colorDark;
  color = mix(color, colorMid,   smoothstep(0.0, 0.4, f));
  color = mix(color, colorLight, smoothstep(0.3, 0.7, f));
  color = mix(color, colorBloom, smoothstep(0.6, 1.0, f));
  color += vec3(0.02, 0.01, 0.05);

  // --- BREATHING ---
  float breathMod = 1.0 + (u_breath - 0.5) * 0.16;
  color *= breathMod;

  fragColor = vec4(color, 1.0);
}