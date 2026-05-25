#include <flutter/runtime_effect.glsl>

uniform float     u_time;
uniform vec2      u_resolution;
uniform vec2      u_touch;
uniform float     u_touchForce;
uniform vec2      u_velocity;
uniform float     u_breath;
uniform vec2      u_gyro;
uniform sampler2D u_velocityField;

out vec4 fragColor;

// ─── Noise primitives ────────────────────────────────────────────────────────
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

// 3 octaves — Task 3.1 cost reduction kept
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

vec3 fluidColor(float f) {
  vec3 colorDark  = vec3(0.04, 0.03, 0.10);
  vec3 colorMid   = vec3(0.25, 0.12, 0.60);
  vec3 colorLight = vec3(0.50, 0.35, 0.90);
  vec3 colorBloom = vec3(0.82, 0.75, 1.00);

  vec3 color = colorDark;
  color = mix(color, colorMid,   smoothstep(0.0, 0.4, f));
  color = mix(color, colorLight, smoothstep(0.3, 0.7, f));
  color = mix(color, colorBloom, smoothstep(0.6, 1.0, f));
  return color;
}

// ─── Task 3.2 — Curl noise ───────────────────────────────────────────────────
// Curl is the rotation of a scalar noise field.
// It produces divergence-free flow — fluid that swirls organically
// without compressing or expanding. This is what real fluid looks like.
//
// Formula: curl(f) = (df/dy, -df/dx)
// We compute it with finite differences — sample noise slightly offset
// in x and y, subtract to get the gradient, then rotate 90 degrees.
//
// Result: a 2D vector field that swirls around high-noise regions.
// Feed a touch-influenced noise field into this → organic fluid reaction.

vec2 curl(vec2 p, float t) {
  const float eps = 0.003;

  // Sample noise slightly offset in each axis to get gradient
  float nx0 = fbm(vec2(p.x - eps, p.y) + t);
  float nx1 = fbm(vec2(p.x + eps, p.y) + t);
  float ny0 = fbm(vec2(p.x, p.y - eps) + t);
  float ny1 = fbm(vec2(p.x, p.y + eps) + t);

  // Finite difference gradient
  float dfdx = (nx1 - nx0) / (2.0 * eps);
  float dfdy = (ny1 - ny0) / (2.0 * eps);

  // Rotate 90 degrees = curl
  return vec2(dfdy, -dfdx);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv        = fragCoord / u_resolution;

  uv = (uv - 0.5) * (1.0 + u_breath * 0.008) + 0.5;

  // ─── Task 3.2 — curl-based drag ──────────────────────────────────────────
  //
  // How it works:
  // 1. Compute distance from this pixel to touch point
  // 2. Apply inverse-square falloff — strong near finger, fades with distance
  // 3. Compute curl at a noise field that's been offset by touch velocity
  // 4. Use that curl to displace the UV before fBm sampling
  //
  // This means drag creates real swirling motion — not a rigid grid shift.
  // No texture sampling involved = no blocks possible at any drag speed.

  vec2  toTouch  = uv - u_touch;
  float dist     = length(toTouch);

  // Influence: strong within ~30% of screen, fades beyond
  float influence = u_touchForce * 0.12 / (dist * dist + 0.02);
  influence = clamp(influence, 0.0, 1.0);

  // Noise field offset by velocity direction — makes curl align with drag
  vec2 curlSeed = uv * 3.0 + u_velocity * 4.0 + u_time * 0.15;
  vec2 curlVec  = curl(curlSeed, u_time * 0.2);

  // Apply curl displacement — strength tuned so fast drag = visible swirl
  vec2 baseUV = uv + curlVec * influence * 0.18;

  // Also keep a tiny amount of grid velocity for ambient drift feel
  // Decoded from texture but at very low strength — no blocks at 0.02
  vec2 gridVel = texture(u_velocityField, uv).rg * 2.0 - 1.0;
  baseUV += gridVel * 0.02;

  // ─── Drift ───────────────────────────────────────────────────────────────
  float driftX = u_time * 0.02;
  float driftY = u_time * 0.12;

  // ─── Two depth layers (Task 3.1) ─────────────────────────────────────────
  vec2  bgUV = baseUV * 1.8 + u_gyro * 0.3 + vec2(driftX * 0.3, -driftY * 0.15);
  float bgT  = u_time * 0.3 * 0.25;
  float bgF  = fluidLayer(bgUV, bgT);
  bgF        = 0.5 + 0.5 * bgF;
  bgF        = pow(bgF, 1.9);

  vec2  midUV = baseUV * 2.8 + u_gyro * 0.7 + vec2(driftX * 0.7, -driftY * 0.40);
  float midT  = u_time * 0.8 * 0.25;
  float midF  = fluidLayer(midUV + vec2(3.7, 5.1), midT);
  midF        = 0.5 + 0.5 * midF;
  midF        = pow(midF, 1.6);

  // ─── Composite ───────────────────────────────────────────────────────────
  vec3 color = vec3(0.04, 0.03, 0.10);
  color += fluidColor(bgF)  * 0.45;
  color += fluidColor(midF) * 0.90;

  color = color / (1.0 + color);

  float breathMod = 1.0 + (u_breath - 0.5) * 0.16;
  color *= breathMod;

  fragColor = vec4(color, 1.0);
}
