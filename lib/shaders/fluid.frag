#version 460 core
#include <flutter/runtime_effect.glsl>

// Uniform declarations - individual floats instead of arrays
uniform float uTime;
uniform vec2 uResolution;
// Touch positions (3-12)
uniform float uTouch1x; uniform float uTouch1y;
uniform float uTouch2x; uniform float uTouch2y;
uniform float uTouch3x; uniform float uTouch3y;
uniform float uTouch4x; uniform float uTouch4y;
uniform float uTouch5x; uniform float uTouch5y;
// Touch strengths (13-17)
uniform float uTouchStrength1;
uniform float uTouchStrength2;
uniform float uTouchStrength3;
uniform float uTouchStrength4;
uniform float uTouchStrength5;
// Touch velocity vectors (18-27) - 2 floats per touch
uniform float uVelX1; uniform float uVelY1;
uniform float uVelX2; uniform float uVelY2;
uniform float uVelX3; uniform float uVelY3;
uniform float uVelX4; uniform float uVelY4;
uniform float uVelX5; uniform float uVelY5;
// Touch trail lengths (28-32)
uniform float uTrailLength1;
uniform float uTrailLength2;
uniform float uTrailLength3;
uniform float uTrailLength4;
uniform float uTrailLength5;
// Scalar uniforms (33+)
uniform float uTouchCount;
uniform float uFlowSpeed;
uniform float uTurbulence;
uniform float uGlowIntensity;
uniform float uEmotionalState;  // 0=fog, 1=processing, 2=clarity, 3=conviction
uniform float uIdleBreath;      // breathing pulse when idle
uniform float uTouchActivity;   // 0→1 on touch, back to 0 when idle

out vec4 fragColor;

// ===== Inlined fluid_utils.glsl functions =====

// Simple 2D hash returning a pseudo-random float in [0,1]
float hash(vec2 p) {
    p = fract(p * vec2(123.45, 678.90));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D value noise - interpolated random values on a grid
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    float lerpX1 = mix(a, b, u.x);
    float lerpX2 = mix(c, d, u.x);
    return mix(lerpX1, lerpX2, u.y);
}

// Rotation matrix helper
mat2 rot(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

// Fractional Brownian Motion - 8 octaves with rotation
float fbm(vec2 p) {
    float total = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 8; i++) {
        float angle = float(i) * 0.785398;
        vec2 rotated = p * rot(angle);
        total += amplitude * noise(rotated * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return total;
}

// ===== End inlined functions =====

// Emotional state palette - changes based on app state
vec3 appPalette(float t, float state) {
    // FOG state — deep cold blues and greys
    vec3 fog_a = vec3(0.01, 0.01, 0.03);
    vec3 fog_b = vec3(0.05, 0.08, 0.18);
    vec3 fog_c = vec3(0.10, 0.15, 0.35);
    
    // PROCESSING state — deep indigo and violet (default)
    vec3 proc_a = vec3(0.01, 0.01, 0.04);
    vec3 proc_b = vec3(0.08, 0.03, 0.22);
    vec3 proc_c = vec3(0.25, 0.06, 0.45);
    
    // CLARITY state — warm amber gold emerging from dark
    vec3 clar_a = vec3(0.02, 0.01, 0.01);
    vec3 clar_b = vec3(0.20, 0.08, 0.02);
    vec3 clar_c = vec3(0.45, 0.22, 0.04);
    
    // CONVICTION state — soft teal/emerald, calm and resolved
    vec3 conv_a = vec3(0.01, 0.02, 0.02);
    vec3 conv_b = vec3(0.02, 0.12, 0.14);
    vec3 conv_c = vec3(0.04, 0.30, 0.28);
    
    // Blend between states
    vec3 a, b, c;
    if (state < 1.0) {
        a = mix(fog_a, proc_a, state);
        b = mix(fog_b, proc_b, state);
        c = mix(fog_c, proc_c, state);
    } else if (state < 2.0) {
        a = mix(proc_a, clar_a, state - 1.0);
        b = mix(proc_b, clar_b, state - 1.0);
        c = mix(proc_c, clar_c, state - 1.0);
    } else {
        a = mix(clar_a, conv_a, state - 2.0);
        b = mix(clar_b, conv_b, state - 2.0);
        c = mix(clar_c, conv_c, state - 2.0);
    }
    
    return a + b * cos(6.28318 * (c * t + vec3(0.0, 0.33, 0.67)));
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;
    
    // SWIPE TRAIL DISTURBANCE - elongated along velocity direction
    vec2 warp = vec2(0.0);
    vec2 aspect = vec2(uResolution.x / uResolution.y, 1.0);
    vec2 aspectCorrectedUV = uv * aspect;

    // Touch 1
    if (uTouchCount > 0.0) {
        vec2 touchPos = vec2(uTouch1x, uTouch1y) * aspect;
        vec2 vel = vec2(uVelX1, uVelY1);
        float trail = uTrailLength1;
        
        vec2 toTouch = aspectCorrectedUV - touchPos;
        vec2 velDir = length(vel) > 0.001 ? normalize(vel) : vec2(0.0);
        vec2 perpDir = vec2(-velDir.y, velDir.x);
        
        float along = dot(toTouch, velDir);
        float perp = dot(toTouch, perpDir);
        
        // Elliptical falloff — wide along swipe, narrow across
        float distEllipse = sqrt(
            (perp * perp) / 0.04 +
            (along * along) / max(0.04, 0.04 + trail * 0.3)
        );
        
        float pressure = uTouchStrength1 * exp(-distEllipse * 4.0);
        warp += velDir * pressure * 0.5;
        warp += toTouch * pressure * 0.2;
    }
    
    // Touch 2
    if (uTouchCount > 1.0) {
        vec2 touchPos = vec2(uTouch2x, uTouch2y) * aspect;
        vec2 vel = vec2(uVelX2, uVelY2);
        float trail = uTrailLength2;
        
        vec2 toTouch = aspectCorrectedUV - touchPos;
        vec2 velDir = length(vel) > 0.001 ? normalize(vel) : vec2(0.0);
        vec2 perpDir = vec2(-velDir.y, velDir.x);
        
        float along = dot(toTouch, velDir);
        float perp = dot(toTouch, perpDir);
        
        float distEllipse = sqrt(
            (perp * perp) / 0.04 +
            (along * along) / max(0.04, 0.04 + trail * 0.3)
        );
        
        float pressure = uTouchStrength2 * exp(-distEllipse * 4.0);
        warp += velDir * pressure * 0.5;
        warp += toTouch * pressure * 0.2;
    }
    
    // Touch 3
    if (uTouchCount > 2.0) {
        vec2 touchPos = vec2(uTouch3x, uTouch3y) * aspect;
        vec2 vel = vec2(uVelX3, uVelY3);
        float trail = uTrailLength3;
        
        vec2 toTouch = aspectCorrectedUV - touchPos;
        vec2 velDir = length(vel) > 0.001 ? normalize(vel) : vec2(0.0);
        vec2 perpDir = vec2(-velDir.y, velDir.x);
        
        float along = dot(toTouch, velDir);
        float perp = dot(toTouch, perpDir);
        
        float distEllipse = sqrt(
            (perp * perp) / 0.04 +
            (along * along) / max(0.04, 0.04 + trail * 0.3)
        );
        
        float pressure = uTouchStrength3 * exp(-distEllipse * 4.0);
        warp += velDir * pressure * 0.5;
        warp += toTouch * pressure * 0.2;
    }
    
    // Touch 4
    if (uTouchCount > 3.0) {
        vec2 touchPos = vec2(uTouch4x, uTouch4y) * aspect;
        vec2 vel = vec2(uVelX4, uVelY4);
        float trail = uTrailLength4;
        
        vec2 toTouch = aspectCorrectedUV - touchPos;
        vec2 velDir = length(vel) > 0.001 ? normalize(vel) : vec2(0.0);
        vec2 perpDir = vec2(-velDir.y, velDir.x);
        
        float along = dot(toTouch, velDir);
        float perp = dot(toTouch, perpDir);
        
        float distEllipse = sqrt(
            (perp * perp) / 0.04 +
            (along * along) / max(0.04, 0.04 + trail * 0.3)
        );
        
        float pressure = uTouchStrength4 * exp(-distEllipse * 4.0);
        warp += velDir * pressure * 0.5;
        warp += toTouch * pressure * 0.2;
    }
    
    // Touch 5
    if (uTouchCount > 4.0) {
        vec2 touchPos = vec2(uTouch5x, uTouch5y) * aspect;
        vec2 vel = vec2(uVelX5, uVelY5);
        float trail = uTrailLength5;
        
        vec2 toTouch = aspectCorrectedUV - touchPos;
        vec2 velDir = length(vel) > 0.001 ? normalize(vel) : vec2(0.0);
        vec2 perpDir = vec2(-velDir.y, velDir.x);
        
        float along = dot(toTouch, velDir);
        float perp = dot(toTouch, perpDir);
        
        float distEllipse = sqrt(
            (perp * perp) / 0.04 +
            (along * along) / max(0.04, 0.04 + trail * 0.3)
        );
        
        float pressure = uTouchStrength5 * exp(-distEllipse * 4.0);
        warp += velDir * pressure * 0.5;
        warp += toTouch * pressure * 0.2;
    }
    
    vec2 p = uv * 3.5;
    
    // Apply touch-induced warp with turbulence
    p += warp * uTurbulence * 1.5;
    
    // IDLE BREATHING - subtle scale pulse when idle
    float breathScale = 1.0 + uIdleBreath * 0.08;
    vec2 p_breathed = p * breathScale;
    
    // Static base domain warping
    vec2 q = vec2(fbm(p_breathed), fbm(p_breathed + vec2(5.2, 1.3)));
    vec2 r = vec2(fbm(p_breathed + 4.0 * q + vec2(1.7, 9.2)), 
                  fbm(p_breathed + 4.0 * q + vec2(8.3, 2.8)));
    vec2 s = vec2(fbm(p_breathed + 3.0 * r + vec2(5.8, 1.2)), 
                  fbm(p_breathed + 3.0 * r + vec2(2.1, 7.4)));
    
    float f = fbm(p_breathed + 3.5 * s * uTurbulence);
    
    float f_r = (f > 0.55) ? fbm(p_breathed + 3.5 * (s + vec2(0.005, 0.0)) * uTurbulence) : f;
    float f_b = (f > 0.55) ? fbm(p_breathed + 3.5 * (s - vec2(0.005, 0.0)) * uTurbulence) : f;
    
    // Base fluid color using emotional state palette
    // Only show when touching - otherwise pure black background
    float base_glow_r = appPalette(f_r * 0.5, uEmotionalState).r * 0.3;
    float mid_core_r  = appPalette(f_r * 0.8 + 0.2, uEmotionalState).r * pow(max(f_r, 0.0), 2.0) * 0.6;
    float peak_r      = 0.4 * pow(max(f_r - 0.6, 0.0), 2.0) * 2.0;
    float col_r       = ((base_glow_r + mid_core_r + peak_r) * uGlowIntensity) * uTouchActivity;

    float base_glow_g = appPalette(f * 0.5, uEmotionalState).g * 0.3;
    float mid_core_g  = appPalette(f * 0.8 + 0.2, uEmotionalState).g * pow(max(f, 0.0), 2.0) * 0.6;
    float peak_g      = 0.2 * pow(max(f - 0.6, 0.0), 2.0) * 2.0;
    float col_g       = ((base_glow_g + mid_core_g + peak_g) * uGlowIntensity) * uTouchActivity;

    float base_glow_b = appPalette(f_b * 0.5, uEmotionalState).b * 0.3;
    float mid_core_b  = appPalette(f_b * 0.8 + 0.2, uEmotionalState).b * pow(max(f_b, 0.0), 2.0) * 0.6;
    float peak_b      = 0.5 * pow(max(f_b - 0.6, 0.0), 2.0) * 2.0;
    float col_b       = ((base_glow_b + mid_core_b + peak_b) * uGlowIntensity) * uTouchActivity;
    
    vec3 color = vec3(col_r, col_g, col_b);
    
    // TOUCH GLOW AURA - bright at finger position
    vec3 touchGlow = vec3(0.0);
    
    if (uTouchCount > 0.0) {
        float d = length(uv - vec2(uTouch1x, uTouch1y));
        float strength = uTouchStrength1;
        float core = exp(-d * 60.0) * strength * 2.0;
        float mid = exp(-d * 20.0) * strength * 1.2;
        float bloom = exp(-d * 6.0) * strength * 0.4;
        touchGlow += vec3(0.9, 0.8, 1.0) * core;
        touchGlow += vec3(0.3, 0.1, 0.8) * mid;
        touchGlow += vec3(0.1, 0.05, 0.3) * bloom;
    }
    
    if (uTouchCount > 1.0) {
        float d = length(uv - vec2(uTouch2x, uTouch2y));
        float strength = uTouchStrength2;
        float core = exp(-d * 60.0) * strength * 2.0;
        float mid = exp(-d * 20.0) * strength * 1.2;
        float bloom = exp(-d * 6.0) * strength * 0.4;
        touchGlow += vec3(0.9, 0.8, 1.0) * core;
        touchGlow += vec3(0.3, 0.1, 0.8) * mid;
        touchGlow += vec3(0.1, 0.05, 0.3) * bloom;
    }
    
    if (uTouchCount > 2.0) {
        float d = length(uv - vec2(uTouch3x, uTouch3y));
        float strength = uTouchStrength3;
        float core = exp(-d * 60.0) * strength * 2.0;
        float mid = exp(-d * 20.0) * strength * 1.2;
        float bloom = exp(-d * 6.0) * strength * 0.4;
        touchGlow += vec3(0.9, 0.8, 1.0) * core;
        touchGlow += vec3(0.3, 0.1, 0.8) * mid;
        touchGlow += vec3(0.1, 0.05, 0.3) * bloom;
    }
    
    if (uTouchCount > 3.0) {
        float d = length(uv - vec2(uTouch4x, uTouch4y));
        float strength = uTouchStrength4;
        float core = exp(-d * 60.0) * strength * 2.0;
        float mid = exp(-d * 20.0) * strength * 1.2;
        float bloom = exp(-d * 6.0) * strength * 0.4;
        touchGlow += vec3(0.9, 0.8, 1.0) * core;
        touchGlow += vec3(0.3, 0.1, 0.8) * mid;
        touchGlow += vec3(0.1, 0.05, 0.3) * bloom;
    }
    
    if (uTouchCount > 4.0) {
        float d = length(uv - vec2(uTouch5x, uTouch5y));
        float strength = uTouchStrength5;
        float core = exp(-d * 60.0) * strength * 2.0;
        float mid = exp(-d * 20.0) * strength * 1.2;
        float bloom = exp(-d * 6.0) * strength * 0.4;
        touchGlow += vec3(0.9, 0.8, 1.0) * core;
        touchGlow += vec3(0.3, 0.1, 0.8) * mid;
        touchGlow += vec3(0.1, 0.05, 0.3) * bloom;
    }
    
    color += touchGlow;
    
    // PURE BLACK BACKGROUND - only touch glow visible when not touching
    // Ensure background is pure black except for touch interactions
    color = mix(vec3(0.0), color, uTouchActivity);
    
    // Subtle grain only visible when touching
    float grain = hash(fragCoord * 0.5) * 0.01 * uTouchActivity;
    color += vec3(grain);
    
    color = pow(max(color, 0.0), vec3(0.5));
    
    fragColor = vec4(color, 1.0);
}
