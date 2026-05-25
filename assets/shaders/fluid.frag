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

// 3x3 gaussian smooth — eliminates grid edges at any displacement strength
vec2 sampleVelocitySmooth(vec2 uv) {
  vec2 t = vec2(1.0 / 32.0);

  vec2 s00 = texture(u_velocityField, uv + vec2(-t.x, -t.y)).rg;
  vec2 s10 = texture(u_velocityField, uv + vec2( 0.0, -t.y)).rg;
  vec2 s20 = texture(u_velocityField, uv + vec2( t.x, -t.y)).rg;
  vec2 s01 = texture(u_velocityField, uv + vec2(-t.x,  0.0)).rg;
  vec2 s11 = texture(u_velocityField, uv                   ).rg;
  vec2 s21 = texture(u_velocityField, uv + vec2( t.x,  0.0)).rg;
  vec2 s02 = texture(u_velocityField, uv + vec2(-t.x,  t.y)).rg;
  vec2 s12 = texture(u_velocityField, uv + vec2( 0.0,  t.y)).rg;
  vec2 s22 = texture(u_velocityField, uv + vec2( t.x,  t.y)).rg;

  // Gaussian weights: corners=1, edges=2, centre=4 — sum=16
  vec2 smoothed = (
    s00 * 1.0 + s10 * 2.0 + s20 * 1.0 +
    s01 * 2.0 + s11 * 4.0 + s21 * 2.0 +
    s02 * 1.0 + s12 * 2.0 + s22 * 1.0
  ) / 16.0;

  return smoothed * 2.0 - 1.0;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv        = fragCoord / u_resolution;

  uv = (uv - 0.5) * (1.0 + u_breath * 0.008) + 0.5;

  // Reduced from 0.15 to 0.06 — less grid stretching = blocks disappear
  vec2 vel    = sampleVelocitySmooth(uv);
  vec2 baseUV = uv + vel * 0.06;

  float driftX = u_time * 0.02;
  float driftY = u_time * 0.12;

  vec2  bgUV  = baseUV * 1.8 + u_gyro * 0.3 + vec2(driftX * 0.3, -driftY * 0.15);
  float bgT   = u_time * 0.3 * 0.25;
  float bgF   = fluidLayer(bgUV + vec2(0.0, 0.0), bgT);
  bgF         = 0.5 + 0.5 * bgF;
  bgF         = pow(bgF, 1.9);

  vec2  midUV = baseUV * 2.4 + u_gyro * 0.6 + vec2(driftX * 0.6, -driftY * 0.30);
  float midT  = u_time * 0.6 * 0.25;
  float midF  = fluidLayer(midUV + vec2(3.7, 5.1), midT);
  midF        = 0.5 + 0.5 * midF;
  midF        = pow(midF, 1.7);

  vec2  fgUV  = baseUV * 3.2 + u_gyro * 1.0 + vec2(driftX * 1.0, -driftY * 0.50);
  float fgT   = u_time * 1.0 * 0.25;
  float fgF   = fluidLayer(fgUV + vec2(7.3, 2.8), fgT);
  fgF         = 0.5 + 0.5 * fgF;
  fgF         = pow(fgF, 1.6);

  vec3 color = vec3(0.04, 0.03, 0.10);
  color += fluidColor(bgF)  * 0.40;
  color += fluidColor(midF) * 0.65;
  color += fluidColor(fgF)  * 0.85;

  color = color / (1.0 + color);

  float breathMod = 1.0 + (u_breath - 0.5) * 0.16;
  color *= breathMod;

  fragColor = vec4(color, 1.0);
}
