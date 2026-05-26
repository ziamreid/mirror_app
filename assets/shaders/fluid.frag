#include <flutter/runtime_effect.glsl>

// ─── Uniforms ────────────────────────────────────────────────────────────────
// Slot mapping (must match paint() in main.dart exactly):
//   0        u_time
//   1, 2     u_resolution  (x, y)
//   3        u_breath
//   4, 5     u_gyro        (x, y)
//   sampler0 u_velocityField
//
// Removed: u_touch, u_touchForce, u_velocity — velocity grid handles all touch.

uniform float     u_time;
uniform vec2      u_resolution;
uniform float     u_breath;
uniform vec2      u_gyro;
uniform sampler2D u_velocityField;

out vec4 fragColor;

// ─── Noise primitives ─────────────────────────────────────────────────────────
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
    mix(dot(hash(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
        dot(hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
    mix(dot(hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
        dot(hash(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
    u.y);
}

// Task A.4 — 3 octaves (was 3, kept same count but power curve opens contrast)
float fbm(vec2 p) {
  float value     = 0.0;
  float amplitude = 0.5;
  vec2  shift     = vec2(100.0);
  for (int i = 0; i < 3; i++) {
    value     += amplitude * noise(p);
    p          = p * 2.1 + shift;
    amplitude *= 0.5;
  }
  return value;
}

// ─── Fluid layer (domain-warped fBm) ─────────────────────────────────────────
float fluidLayer(vec2 p, float t) {
  vec2 q = vec2(
    fbm(p + t),
    fbm(p + vec2(1.7, 9.2) + t)
  );
  vec2 r = vec2(
    fbm(p + 2.0 * q + vec2(1.7, 9.2) + t * 0.8),
    fbm(p + 2.0 * q + vec2(8.3, 2.8) + t * 0.6)
  );
  return fbm(p + 2.5 * r + t * 0.4);
}

// ─── Color palette ────────────────────────────────────────────────────────────
// Task A.4 — deeper dark floor, stronger bloom
vec3 fluidColor(float f) {
  vec3 colorDark  = vec3(0.01, 0.005, 0.04);   // deep void
  vec3 colorMid   = vec3(0.25, 0.12,  0.60);
  vec3 colorLight = vec3(0.55, 0.38,  0.95);
  vec3 colorBloom = vec3(0.95, 0.88,  1.00);   // near-white bloom

  vec3 color = colorDark;
  color = mix(color, colorMid,   smoothstep(0.0, 0.4, f));
  color = mix(color, colorLight, smoothstep(0.3, 0.7, f));
  color = mix(color, colorBloom, smoothstep(0.6, 1.0, f));
  return color;
}

// ─── Main ─────────────────────────────────────────────────────────────────────
void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv        = fragCoord / u_resolution;

  // Breath — subtle scale pulse
  uv = (uv - 0.5) * (1.0 + u_breath * 0.008) + 0.5;

  // ── Task A.1 — Multi-step UV advection from velocity grid ──────────────────
  // Step 1: sample velocity at current UV
  vec2 vel1 = texture(u_velocityField, uv).rg * 2.0 - 1.0;

  // Step 2: step forward and sample again — gives trailing depth
  vec2 uv2  = clamp(uv + vel1 * 0.08, vec2(0.01), vec2(0.99));
  vec2 vel2 = texture(u_velocityField, uv2).rg * 2.0 - 1.0;

  // Combined advection — shifts the fBm sample point in drag direction
  vec2 baseUV = uv + (vel1 + vel2) * 0.5 * 0.12;

  // Clamp to prevent edge artifacts (Task E.2 pre-applied)
  baseUV = clamp(baseUV, vec2(0.01), vec2(0.99));

  // ── Task A.2 — Finite-difference curl from velocity texture ───────────────
  // Derives organic swirl directly from the real velocity field.
  // No fBm curl needed — no extra cost, no disconnected swirl.
  float e      = 1.0 / 32.0;  // one texel in the 32×32 grid

  float dvy_dx = texture(u_velocityField, uv + vec2(e,   0.0)).g
               - texture(u_velocityField, uv - vec2(e,   0.0)).g;
  float dvx_dy = texture(u_velocityField, uv + vec2(0.0, e  )).r
               - texture(u_velocityField, uv - vec2(0.0, e  )).r;

  float curlVal = dvy_dx - dvx_dy;
  baseUV += vec2(-curlVal, curlVal) * 0.04;

  // ── Drift — slow time-based offset so fluid never repeats ─────────────────
  float driftX = u_time * 0.02;
  float driftY = u_time * 0.12;

  // ── Three depth layers with gyroscope parallax ────────────────────────────
  // Task A.4 — power curve changed to 1.4 / 1.2 / 1.5 (opens highlights)
  // Background
  vec2  bgUV = baseUV * 1.8
             + u_gyro * 0.3
             + vec2(driftX * 0.3, -driftY * 0.15);
  float bgF  = fluidLayer(bgUV, u_time * 0.3 * 0.25);
  bgF        = 0.5 + 0.5 * bgF;
  bgF        = pow(bgF, 1.4);   // was 1.9 — opens highlights

  // Midground
  vec2  midUV = baseUV * 2.8
              + u_gyro * 0.7
              + vec2(driftX * 0.7, -driftY * 0.40);
  float midF  = fluidLayer(midUV + vec2(3.7, 5.1), u_time * 0.8 * 0.25);
  midF        = 0.5 + 0.5 * midF;
  midF        = pow(midF, 1.2);   // was 1.6 — opens midground highlights

  // Foreground — fine detail layer restored (was removed, added back at low opacity)
  vec2  fgUV = baseUV * 4.2
             + u_gyro * 1.0
             + vec2(driftX * 1.2, -driftY * 0.70);
  float fgF  = fluidLayer(fgUV + vec2(7.3, 2.9), u_time * 1.4 * 0.25);
  fgF        = 0.5 + 0.5 * fgF;
  fgF        = pow(fgF, 1.5);

  // ── Composite ─────────────────────────────────────────────────────────────
  vec3 color = vec3(0.01, 0.005, 0.04);   // deep dark base
  color += fluidColor(bgF)  * 0.35;        // background — subtle
  color += fluidColor(midF) * 0.80;        // midground — dominant
  color += fluidColor(fgF)  * 0.28;        // foreground — fine detail

  // Task A.4 — softer tonemapping: gamma lift instead of reinhard
  // Opens shadows, preserves bloom. pow(x, 0.85) ≈ gentle gamma correction.
  color = pow(max(color, vec3(0.0)), vec3(0.85));

  // ── Task A.3 — Velocity magnitude glow ────────────────────────────────────
  // Where fluid moves fast → brightness increases → luminous drag trail.
  // Derived from vel1 — no extra texture samples needed.
  float speed     = length(vel1);
  float glow      = smoothstep(0.0, 0.25, speed);
  vec3  glowColor = mix(
    vec3(0.45, 0.20, 0.90),   // deep violet at low speed
    vec3(0.95, 0.88, 1.00),   // near-white bloom at peak speed
    glow
  );
  color += glowColor * glow * 0.55;

  // ── Breath modulation ──────────────────────────────────────────────────────
  float breathMod = 1.0 + (u_breath - 0.5) * 0.20;
  color *= breathMod;

  fragColor = vec4(color, 1.0);
}
