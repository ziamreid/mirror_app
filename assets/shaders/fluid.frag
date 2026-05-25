#include <flutter/runtime_effect.glsl>

// ─── Uniforms ────────────────────────────────────────────────────────────────
uniform float     u_time;
uniform vec2      u_resolution;
uniform vec2      u_touch;        // kept alive — removed in Phase 4.3
uniform float     u_touchForce;   // kept alive — removed in Phase 4.3
uniform vec2      u_velocity;     // kept alive — removed in Phase 4.3
uniform float     u_breath;
uniform vec2      u_gyro;         // Phase 3 — zero until gyro connected
uniform sampler2D u_velocityField; // Phase 4.2 — 32×32 velocity grid texture

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

float fbm(vec2 p) {
  float value     = 0.0;
  float amplitude = 0.5;
  vec2  shift     = vec2(100.0);
  for (int i = 0; i < 4; i++) {
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

// ─── Main ─────────────────────────────────────────────────────────────────────
void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv        = fragCoord / u_resolution;

  // --- BREATH: scale pulse ---
  uv = (uv - 0.5) * (1.0 + u_breath * 0.008) + 0.5;

  // ─── PHASE 4.2 — VELOCITY FIELD ADVECTION ────────────────────────────────
  //
  // Sample the 32×32 velocity texture at this pixel's UV.
  // R channel = velX, G channel = velY.
  // Encoded as 0..1 in texture, decode back to -1..1.
  //
  vec2 encodedVel = texture(u_velocityField, uv).rg;
  vec2 vel        = encodedVel * 2.0 - 1.0;  // 0..1 → -1..1

  // Advect the base UV — shift fBm sampling point by velocity.
  // This is what makes the fluid visibly move where you drag.
  // Strength 0.15 — strong enough to see, not so strong it tears.
  vec2 baseUV = uv + vel * 0.15;

  // ─── DRIFT ───────────────────────────────────────────────────────────────
  float driftX = u_time * 0.02;
  float driftY = u_time * 0.12;  // upward scroll

  // ─── THREE DEPTH LAYERS ──────────────────────────────────────────────────
  // Background: slow, large scale
  vec2  bgUV  = baseUV * 1.8 + u_gyro * 0.3 + vec2(driftX * 0.3, -driftY * 0.15);
  float bgT   = u_time * 0.3 * 0.25;
  float bgF   = fluidLayer(bgUV + vec2(0.0, 0.0), bgT);
  bgF         = 0.5 + 0.5 * bgF;
  bgF         = pow(bgF, 1.9);

  // Midground: medium speed, medium scale
  vec2  midUV = baseUV * 2.4 + u_gyro * 0.6 + vec2(driftX * 0.6, -driftY * 0.30);
  float midT  = u_time * 0.6 * 0.25;
  float midF  = fluidLayer(midUV + vec2(3.7, 5.1), midT);
  midF        = 0.5 + 0.5 * midF;
  midF        = pow(midF, 1.7);

  // Foreground: fast, fine detail
  vec2  fgUV  = baseUV * 3.2 + u_gyro * 1.0 + vec2(driftX * 1.0, -driftY * 0.50);
  float fgT   = u_time * 1.0 * 0.25;
  float fgF   = fluidLayer(fgUV + vec2(7.3, 2.8), fgT);
  fgF         = 0.5 + 0.5 * fgF;
  fgF         = pow(fgF, 1.6);

  // ─── COMPOSITE ───────────────────────────────────────────────────────────
  vec3 color = vec3(0.04, 0.03, 0.10);
  color += fluidColor(bgF)  * 0.40;
  color += fluidColor(midF) * 0.65;
  color += fluidColor(fgF)  * 0.85;

  // Soft tonemap — prevents additive blowout
  color = color / (1.0 + color);

  // Breathing luminosity
  float breathMod = 1.0 + (u_breath - 0.5) * 0.16;
  color *= breathMod;

  fragColor = vec4(color, 1.0);
}
