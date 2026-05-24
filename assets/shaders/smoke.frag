#include <flutter/runtime_effect.glsl>

uniform vec2  uResolution;
uniform float uTime;
uniform vec2  uTouch;
uniform vec2  uTouchVel;
uniform float uTouchStrength;
uniform float uClarity;
uniform float uProcessing;

out vec4 fragColor;

mat2 rot(float a) {
  float c = cos(a), s = sin(a);
  return mat2(c, -s, s, c);
}

float hash(vec2 p) {
  p = fract(p * vec2(127.1, 311.7));
  p += dot(p, p + 17.5);
  return fract(p.x * p.y);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i),             hash(i + vec2(1,0)), u.x),
    mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x),
    u.y
  );
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  vec2  shift = vec2(100.0);
  mat2  r = rot(0.5);
  for (int i = 0; i < 6; i++) {
    v += a * vnoise(p);
    p  = r * p * 2.0 + shift;
    a *= 0.5;
  }
  return v;
}

float smokeFbm(vec2 p, float t) {
  vec2 q = vec2(
    fbm(p + vec2(0.0, 0.0) + t * 0.18),
    fbm(p + vec2(5.2, 1.3) + t * 0.14)
  );
  vec2 r = vec2(
    fbm(p + 3.5 * q + vec2(1.7, 9.2) + t * 0.11),
    fbm(p + 3.5 * q + vec2(8.3, 2.8) + t * 0.09)
  );
  return fbm(p + 3.5 * r + vec2(3.3, 7.1) + t * 0.06);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv        = fragCoord / uResolution;
  float aspect   = uResolution.x / uResolution.y;
  vec2 st        = (uv - 0.5) * vec2(aspect, 1.0);
  float t        = uTime * 0.30;

  float hasTouch  = step(0.0, uTouch.x);
  vec2  touchSt   = (uTouch - 0.5) * vec2(aspect, 1.0);
  vec2  toFrag    = st - touchSt;
  float d         = length(toFrag);
  vec2  pushDir   = toFrag / (d + 0.0001);

  // ── Pure domain warp push — no visible shape ──────────────────────────
  // Instead of moving the smoke pixels, we warp the SAMPLE POINT.
  // This means the smoke texture itself deforms — no circle, no boundary.
  // The further from finger, the less warp. Gaussian falloff = invisible edge.
  float sigma     = 0.13; // tightness of influence — small = finger-sized
  float gaussian  = exp(-(d * d) / (2.0 * sigma * sigma));

  // Push: warp sample point away from finger
  vec2 domainPush = hasTouch * pushDir * gaussian
                  * uTouchStrength * 0.40;

  // Velocity drag: smoke flows in swipe direction near finger
  vec2 velDrag    = hasTouch * uTouchVel * gaussian * 0.18;

  // ── Stage warps ───────────────────────────────────────────────────────
  float dCenter  = length(st);
  vec2 procPull  = -normalize(st + 0.0001) * uProcessing * 0.13
                  * (1.0 - smoothstep(0.0, 0.9, dCenter));
  vec2 clarPush  = normalize(st + 0.0001)  * uClarity    * 0.09
                  * smoothstep(0.05, 0.5, dCenter);

  // ── Sample ────────────────────────────────────────────────────────────
  vec2 samplePos = st * 1.5 + vec2(1.8, 0.6)
                 + domainPush + velDrag
                 + procPull  + clarPush;

  float f     = smokeFbm(samplePos, t);
  float smoke = smoothstep(0.30, 0.80, f);
  smoke       = pow(smoke, 1.3);

  // Vignette
  float vig = 1.0 - smoothstep(0.28, 1.0, length(uv - 0.5) * 1.9);
  smoke    *= vig;

  // Clarity: open center
  smoke *= mix(1.0, smoothstep(0.0, 0.50, dCenter), uClarity * 0.88);

  // ── Glow ─────────────────────────────────────────────────────────────
  float clarGlow = uClarity  * (1.0 - smoothstep(0.0, 0.38, dCenter)) * 0.06;
  float pulse    = sin(uTime * 3.8) * 0.5 + 0.5;
  float procGlow = uProcessing * pulse
                 * (1.0 - smoothstep(0.0, 0.22, dCenter)) * 0.14;

  // ── Color ─────────────────────────────────────────────────────────────
  vec3 bg         = vec3(0.033, 0.033, 0.040);
  vec3 smokeColor = vec3(0.86, 0.87, 0.89);
  vec3 col        = mix(bg, smokeColor, smoke);
  col += vec3(0.90, 0.92, 0.96) * clarGlow;
  col += vec3(0.82, 0.86, 0.95) * procGlow;
  col *= mix(0.80, 1.0, uv.y * 0.55 + 0.45);

  fragColor = vec4(col, 1.0);
}
