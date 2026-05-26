#include <flutter/runtime_effect.glsl>

// ─── Uniforms ────────────────────────────────────────────────────────────────
// 0        u_time
// 1, 2     u_resolution
// 3        u_breath
// 4, 5     u_gyro
// 6, 7     u_touch
// 8, 9     u_velocity
// 10       u_touchForce
// sampler0 u_velocityField

uniform float     u_time;
uniform vec2      u_resolution;
uniform float     u_breath;
uniform vec2      u_gyro;
uniform vec2      u_touch;
uniform vec2      u_velocity;
uniform float     u_touchForce;
uniform sampler2D u_velocityField;

out vec4 fragColor;

// ─── Noise ───────────────────────────────────────────────────────────────────
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
  float value = 0.0, amplitude = 0.5;
  for (int i = 0; i < 3; i++) {
    value     += amplitude * noise(p);
    p          = p * 2.1 + vec2(100.0);
    amplitude *= 0.5;
  }
  return value;
}

float fluidLayer(vec2 p, float t) {
  vec2 q = vec2(fbm(p + t), fbm(p + vec2(1.7, 9.2) + t));
  vec2 r = vec2(
    fbm(p + 2.0 * q + vec2(1.7, 9.2) + t * 0.8),
    fbm(p + 2.0 * q + vec2(8.3, 2.8) + t * 0.6)
  );
  return fbm(p + 2.5 * r + t * 0.4);
}

// ─── Color — violet to white ──────────────────────────────────────────────────
vec3 fluidColor(float f) {
  vec3 c = vec3(0.0);
  c = mix(c, vec3(0.30, 0.10, 0.70), smoothstep(0.0, 0.4, f));
  c = mix(c, vec3(0.60, 0.40, 1.00), smoothstep(0.3, 0.7, f));
  c = mix(c, vec3(0.95, 0.88, 1.00), smoothstep(0.6, 1.0, f));
  return c;
}

// ─── Main ─────────────────────────────────────────────────────────────────────
void main() {
  vec2 uv = FlutterFragCoord().xy / u_resolution;

  // ── Physics grid — how much velocity exists at this pixel ─────────────────
  // This is the ONLY use of the grid — for masking and glow magnitude.
  // Never used for UV displacement (that caused the Minecraft blocks).
  vec2  gridVel   = texture(u_velocityField, uv).rg * 2.0 - 1.0;
  float gridSpeed = length(gridVel);

  // Touch proximity — gaussian blob centered on finger
  float aspect    = u_resolution.x / u_resolution.y;
  vec2  td        = (uv - u_touch) * vec2(aspect, 1.0);
  float touchDist = length(td);
  float touchBlob = exp(-touchDist * touchDist * 20.0) * u_touchForce;

  // ── Visibility mask — BLACK everywhere the finger hasn't been ─────────────
  // gridSpeed carries the trail (decays over ~1s via physics decay)
  // touchBlob carries the live finger position
  // smoothstep gives soft edges — no hard cutoff
  float trail = smoothstep(0.02, 0.15, gridSpeed);   // grid trail
  float blob  = touchBlob;                            // live finger blob
  float mask  = clamp(trail + blob, 0.0, 1.0);       // combined visibility

  // Early exit — pure black if nothing is happening here
  if (mask < 0.001) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }

  // ── fBm fluid — only computed where mask > 0 ──────────────────────────────
  // UV shifted by velocity direction for smear effect
  vec2 velDir = length(u_velocity) > 0.0001
    ? u_velocity / length(u_velocity)
    : vec2(0.0);
  vec2 baseUV = uv + velDir * touchBlob * 0.06;
  baseUV = clamp(baseUV, vec2(0.01), vec2(0.99));

  float driftX = u_time * 0.02;
  float driftY = u_time * 0.10;

  // Two layers — cheaper, masked anyway so quality is fine
  vec2  midUV = baseUV * 2.5 + u_gyro * 0.5 + vec2(driftX * 0.6, -driftY * 0.3);
  float midF  = fluidLayer(midUV, u_time * 0.25);
  midF        = pow(0.5 + 0.5 * midF, 1.3);

  vec2  fgUV  = baseUV * 4.0 + u_gyro * 1.0 + vec2(driftX * 1.1, -driftY * 0.6);
  float fgF   = fluidLayer(fgUV + vec2(3.7, 5.1), u_time * 0.18);
  fgF         = pow(0.5 + 0.5 * fgF, 1.5);

  vec3 fluidCol = fluidColor(midF) * 0.7 + fluidColor(fgF) * 0.4;

  // ── Glow hot spot — bright white-violet at finger ─────────────────────────
  float glow      = smoothstep(0.08, 0.35, gridSpeed) + touchBlob * 1.2;
  glow            = clamp(glow, 0.0, 1.0);
  vec3  glowColor = mix(
    vec3(0.35, 0.10, 0.80),   // violet trail
    vec3(0.95, 0.88, 1.00),   // white-violet hot spot
    glow
  );

  // ── Composite — fluid pattern tinted by glow, masked to touch area ────────
  vec3 color = mix(fluidCol, glowColor, glow * 0.6) * mask;

  // Breath — very subtle, only affects visible fluid
  color *= 1.0 + (u_breath - 0.5) * 0.12;

  fragColor = vec4(color, 1.0);
}
