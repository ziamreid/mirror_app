#include <flutter/runtime_effect.glsl>

uniform float u_time;
uniform vec2 u_resolution;
uniform vec2 u_touch;
uniform float u_touchForce;
uniform vec2 u_velocity;
uniform float u_breath;

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

// Reduced to 4 octaves — 33% cheaper, still looks beautiful
float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  vec2 shift = vec2(100.0);
  for (int i = 0; i < 4; i++) {
    value += amplitude * noise(p);
    p = p * 2.1 + shift;
    amplitude *= 0.5;
  }
  return value;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / u_resolution;
  float t = u_time * 0.25;

  // --- TOUCH ---
  // Use aspect-corrected distance only for falloff
  // Do NOT use normalize(uv - touch) — causes star artifact
  float aspect = u_resolution.x / u_resolution.y;
  vec2 uvA = vec2(uv.x * aspect, uv.y);
  vec2 tA  = vec2(u_touch.x * aspect, u_touch.y);
  float d  = length(uvA - tA);

  // Smooth gaussian falloff — no hard edge
  float influence = u_touchForce * exp(-d * d * 4.0);

  // Offset using velocity direction only — no radial push
  // This sweeps the fluid in the direction of finger movement
  // without creating geometric artifacts
  vec2 touchWarp = u_velocity * influence * 0.8;

  // Add a small rotational swirl — organic, not radial
  vec2 swirl = vec2(-d, d) * influence * 0.15;
  touchWarp += swirl;

  // --- SINGLE LAYER DOMAIN WARP (cheaper) ---
  vec2 p = uv + touchWarp;

  vec2 q = vec2(
    fbm(p + t),
    fbm(p + vec2(1.7, 9.2) + t * 0.8)
  );

  float f = fbm(p + 2.0 * q + t * 0.2);

  f = 0.5 + 0.5 * f;
  f = pow(f, 1.6);

  // --- COLOR ---
  vec3 colorDark  = vec3(0.04, 0.03, 0.10);
  vec3 colorMid   = vec3(0.25, 0.12, 0.60);
  vec3 colorLight = vec3(0.50, 0.35, 0.90);
  vec3 colorBloom = vec3(0.82, 0.75, 1.00);

  vec3 color = colorDark;
  color = mix(color, colorMid,   smoothstep(0.0, 0.4, f));
  color = mix(color, colorLight, smoothstep(0.3, 0.7, f));
  color = mix(color, colorBloom, smoothstep(0.6, 1.0, f));
  color += vec3(0.02, 0.01, 0.05);

  // --- BREATHING ---
  float breathMod = 1.0 + (u_breath - 0.5) * 0.14;
  color *= breathMod;

  fragColor = vec4(color, 1.0);
}