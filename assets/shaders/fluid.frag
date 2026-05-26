#include <flutter/runtime_effect.glsl>

// ─── Uniforms ─────────────────────────────────────────────────────────────────
// 0        u_time
// 1, 2     u_resolution
// 3        u_breath
// 4, 5     u_gyro
// 6, 7     u_touch        (current finger, normalised 0..1)
// 8, 9     u_velocity     (drag delta, normalised)
// 10       u_touchForce   (1.0 while touching, decays to 0)
// 11..42   u_trail[8]     (vec4 each: xy=pos, z=age 0..1, w=unused)
//          — 8 × 4 floats = slots 11..42
// sampler0 u_velocityField  (physics only, never drives the mask)

uniform float     u_time;
uniform vec2      u_resolution;
uniform float     u_breath;
uniform vec2      u_gyro;
uniform vec2      u_touch;
uniform vec2      u_velocity;
uniform float     u_touchForce;
// Trail ring buffer — 8 points × 4 floats
uniform float     u_t0x; uniform float u_t0y; uniform float u_t0a;
uniform float     u_t1x; uniform float u_t1y; uniform float u_t1a;
uniform float     u_t2x; uniform float u_t2y; uniform float u_t2a;
uniform float     u_t3x; uniform float u_t3y; uniform float u_t3a;
uniform float     u_t4x; uniform float u_t4y; uniform float u_t4a;
uniform float     u_t5x; uniform float u_t5y; uniform float u_t5a;
uniform float     u_t6x; uniform float u_t6y; uniform float u_t6a;
uniform float     u_t7x; uniform float u_t7y; uniform float u_t7a;
uniform sampler2D u_velocityField;

out vec4 fragColor;

// ─── Noise ────────────────────────────────────────────────────────────────────
vec2 hash(vec2 p) {
  p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
  return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(dot(hash(i + vec2(0,0)), f - vec2(0,0)),
        dot(hash(i + vec2(1,0)), f - vec2(1,0)), u.x),
    mix(dot(hash(i + vec2(0,1)), f - vec2(0,1)),
        dot(hash(i + vec2(1,1)), f - vec2(1,1)), u.x),
    u.y);
}

float fbm(vec2 p) {
  float v = 0.0, a = 0.5;
  for (int i = 0; i < 3; i++) {
    v += a * noise(p);
    p  = p * 2.1 + vec2(100.0);
    a *= 0.5;
  }
  return v;
}

float fluidLayer(vec2 p, float t) {
  vec2 q = vec2(fbm(p + t), fbm(p + vec2(1.7, 9.2) + t));
  vec2 r = vec2(
    fbm(p + 2.0 * q + vec2(1.7, 9.2) + t * 0.8),
    fbm(p + 2.0 * q + vec2(8.3, 2.8) + t * 0.6)
  );
  return fbm(p + 2.5 * r + t * 0.4);
}

// ─── Color ────────────────────────────────────────────────────────────────────
vec3 fluidColor(float f) {
  vec3 c = vec3(0.0);
  c = mix(c, vec3(0.25, 0.05, 0.65), smoothstep(0.0,  0.35, f));
  c = mix(c, vec3(0.55, 0.28, 1.00), smoothstep(0.3,  0.65, f));
  c = mix(c, vec3(0.94, 0.84, 1.00), smoothstep(0.6,  1.0,  f));
  return c;
}

// ─── Smooth gaussian blob — pure math, zero texture, zero blocks ──────────────
float gaussBlob(vec2 uv, vec2 center, float aspect, float radius) {
  vec2  d = (uv - center) * vec2(aspect, 1.0);
  float r = length(d) / radius;
  return exp(-r * r * 4.0);   // gaussian, falls to ~0 at r=1
}

// ─── Trail mask — 8 historical points, all pure math ─────────────────────────
// Each point is a gaussian blob whose radius and opacity scale with age.
// age=0 → full size + full opacity. age=1 → tiny + transparent.
// No texture lookups. No grid. Cannot produce blocks.
float trailMask(vec2 uv, float aspect) {
  float mask = 0.0;
  // Macro to avoid repeating 8× — unrolled for GLSL compatibility
  #define TRAIL_POINT(px, py, pa) \
    { float age = pa; \
      float r   = mix(0.12, 0.03, age); \
      float op  = (1.0 - age) * (1.0 - age); \
      mask = max(mask, gaussBlob(uv, vec2(px, py), aspect, r) * op); }

  TRAIL_POINT(u_t0x, u_t0y, u_t0a)
  TRAIL_POINT(u_t1x, u_t1y, u_t1a)
  TRAIL_POINT(u_t2x, u_t2y, u_t2a)
  TRAIL_POINT(u_t3x, u_t3y, u_t3a)
  TRAIL_POINT(u_t4x, u_t4y, u_t4a)
  TRAIL_POINT(u_t5x, u_t5y, u_t5a)
  TRAIL_POINT(u_t6x, u_t6y, u_t6a)
  TRAIL_POINT(u_t7x, u_t7y, u_t7a)

  #undef TRAIL_POINT
  return mask;
}

// ─── Gaussian smear — shifts UV analytically for drag direction ───────────────
vec2 touchSmear(vec2 uv, vec2 touch, vec2 vel, float force, float aspect) {
  vec2  d       = (uv - touch) * vec2(aspect, 1.0);
  float dist    = length(d);
  if (dist < 0.0001 || force < 0.001) return vec2(0.0);
  float velLen  = length(vel);
  vec2  velDir  = velLen > 0.0001 ? vel / velLen : vec2(0.0);
  float dragF   = exp(-dist * dist * 18.0);
  vec2  drag    = velDir * force * dragF * 0.05;
  vec2  perp    = vec2(-velDir.y, velDir.x);
  float swirlF  = exp(-dist * dist * 30.0);
  float swirlA  = sin(dist * 40.0 - u_time * 3.0) * 0.007;
  vec2  swirl   = perp * swirlA * force * swirlF;
  vec2  dir     = d / (dist + 0.0001);
  float radialF = exp(-dist * dist * 50.0);
  vec2  radial  = -dir * force * radialF * 0.022 / vec2(aspect, 1.0);
  return drag + swirl + radial;
}

// ─── Main ─────────────────────────────────────────────────────────────────────
void main() {
  vec2  uv     = FlutterFragCoord().xy / u_resolution;
  float aspect = u_resolution.x / u_resolution.y;

  // ── Live finger gaussian ──────────────────────────────────────────────────
  float touchBlob = gaussBlob(uv, u_touch, aspect, 0.13) * u_touchForce;

  // ── Trail — 8 historical gaussians, pure math ─────────────────────────────
  float trail = trailMask(uv, aspect);

  // ── Combined mask — 100% analytical, zero grid involvement ───────────────
  float mask = clamp(touchBlob + trail, 0.0, 1.0);

  // Early exit — pure black costs almost nothing
  if (mask < 0.001) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }

  // ── fBm fluid — sampled inside mask region only ───────────────────────────
  vec2 smear  = touchSmear(uv, u_touch, u_velocity, u_touchForce, aspect);
  vec2 baseUV = clamp(uv + smear, vec2(0.01), vec2(0.99));

  float driftX = u_time * 0.018;
  float driftY = u_time * 0.09;

  vec2  midUV  = baseUV * 2.8 + u_gyro * 0.4 + vec2(driftX * 0.5, -driftY * 0.28);
  float midF   = fluidLayer(midUV, u_time * 0.22);
  midF         = pow(0.5 + 0.5 * midF, 1.25);

  vec2  fgUV   = baseUV * 4.5 + u_gyro * 0.9 + vec2(driftX, -driftY * 0.55);
  float fgF    = fluidLayer(fgUV + vec2(3.7, 5.1), u_time * 0.16);
  fgF          = pow(0.5 + 0.5 * fgF, 1.45);

  vec3 fluidCol = fluidColor(midF) * 0.65 + fluidColor(fgF) * 0.38;

  // ── Glow — driven by trail age and live blob, both smooth ─────────────────
  float glow      = clamp(trail * 1.4 + touchBlob * 1.6, 0.0, 1.0);
  vec3  glowColor = mix(
    vec3(0.28, 0.06, 0.72),
    vec3(0.96, 0.90, 1.00),
    pow(glow, 1.5)
  );

  vec3 color = mix(fluidCol, glowColor, glow * 0.68) * mask;
  color *= 1.0 + (u_breath - 0.5) * 0.10;

  fragColor = vec4(color, 1.0);
}
