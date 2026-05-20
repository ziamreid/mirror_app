// fluid_utils.glsl – Reusable GLSL math helpers
// Provides hash, noise, fbm, and rotation utilities for the fluid shader.

// Simple 2‑D hash returning a pseudo‑random float in [0,1]
float hash(vec2 p) {
    p = fract(p * vec2(123.45, 678.90));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2‑D value noise – interpolated random values on a grid
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // Four corner hash values
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    // Smooth interpolation weights
    vec2 u = f * f * (3.0 - 2.0 * f);
    // Interpolate along x then y
    float lerpX1 = mix(a, b, u.x);
    float lerpX2 = mix(c, d, u.x);
    return mix(lerpX1, lerpX2, u.y);
}

// Rotation matrix helper – used per fbm octave to avoid axis‑aligned artifacts
mat2 rot(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

// Fractional Brownian Motion – 8 octaves with per‑octave rotation
float fbm(vec2 p) {
    float total = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    const float angles[8] = float[8](0.0, 0.785398, 1.570796, 2.356194, 3.141593, 3.926991, 4.712389, 5.497787);
    for (int i = 0; i < 8; i++) {
        vec2 rotated = p * rot(angles[i]);
        total += amplitude * noise(rotated * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return total;
}

// Advect coordinates by velocity field
// Creates smooth flow patterns by pushing coordinates backward in velocity space
vec2 advectCoordinates(vec2 p, vec2 velocity, float dt) {
    // Advect by tracing backward along velocity
    vec2 advected = p - velocity * dt * 0.5;
    return advected;
}

// Temporal smoothing for velocity
// Smooths out jittery velocity updates
vec2 smoothVelocity(vec2 currentVelocity, vec2 lastVelocity, float alpha) {
    return mix(lastVelocity, currentVelocity, alpha);
}

// Dummy main guard – compiled only when this file is treated as a full shader (Flutter asset compiler requires an entry point).
#ifdef GL_ES
void main() {
    gl_FragColor = vec4(0.0);
}
#endif
