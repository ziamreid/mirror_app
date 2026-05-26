#include <flutter/runtime_effect.glsl>

uniform float     u_time;
uniform vec2      u_resolution;
uniform float     u_breath;
uniform vec2      u_gyro;
uniform vec2      u_touch;
uniform vec2      u_velocity;
uniform float     u_touchForce;
uniform float     u_touchBurst;

uniform float u_t0x;  uniform float u_t0y;  uniform float u_t0a;
uniform float u_t1x;  uniform float u_t1y;  uniform float u_t1a;
uniform float u_t2x;  uniform float u_t2y;  uniform float u_t2a;
uniform float u_t3x;  uniform float u_t3y;  uniform float u_t3a;
uniform float u_t4x;  uniform float u_t4y;  uniform float u_t4a;
uniform float u_t5x;  uniform float u_t5y;  uniform float u_t5a;
uniform float u_t6x;  uniform float u_t6y;  uniform float u_t6a;
uniform float u_t7x;  uniform float u_t7y;  uniform float u_t7a;
uniform float u_t8x;  uniform float u_t8y;  uniform float u_t8a;
uniform float u_t9x;  uniform float u_t9y;  uniform float u_t9a;
uniform float u_t10x; uniform float u_t10y; uniform float u_t10a;
uniform float u_t11x; uniform float u_t11y; uniform float u_t11a;

uniform sampler2D u_velocityField;
out vec4 fragColor;

// ── Noise ─────────────────────────────────────────────────────────────────────
vec2 hash2(vec2 p) {
  p = vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3)));
  return -1.0+2.0*fract(sin(p)*43758.5453123);
}
float noise(vec2 p){
  vec2 i=floor(p),f=fract(p),u=f*f*(3.0-2.0*f);
  return mix(mix(dot(hash2(i),f),dot(hash2(i+vec2(1,0)),f-vec2(1,0)),u.x),
             mix(dot(hash2(i+vec2(0,1)),f-vec2(0,1)),dot(hash2(i+vec2(1,1)),f-vec2(1,1)),u.x),u.y);
}
float fbm(vec2 p){
  float v=0.0,a=0.5;
  mat2 m=mat2(0.8,0.6,-0.6,0.8);
  for(int i=0;i<6;i++){v+=a*noise(p);p=m*p*2.0+vec2(5.2,1.3);a*=0.5;}
  return v;
}

void main(){
  vec2  uv  = FlutterFragCoord().xy / u_resolution;
  float asp = u_resolution.x / u_resolution.y;

  // Unpack trail
  vec2 tp[12]; float ta[12];
  tp[0]=vec2(u_t0x,u_t0y);    ta[0]=u_t0a;
  tp[1]=vec2(u_t1x,u_t1y);    ta[1]=u_t1a;
  tp[2]=vec2(u_t2x,u_t2y);    ta[2]=u_t2a;
  tp[3]=vec2(u_t3x,u_t3y);    ta[3]=u_t3a;
  tp[4]=vec2(u_t4x,u_t4y);    ta[4]=u_t4a;
  tp[5]=vec2(u_t5x,u_t5y);    ta[5]=u_t5a;
  tp[6]=vec2(u_t6x,u_t6y);    ta[6]=u_t6a;
  tp[7]=vec2(u_t7x,u_t7y);    ta[7]=u_t7a;
  tp[8]=vec2(u_t8x,u_t8y);    ta[8]=u_t8a;
  tp[9]=vec2(u_t9x,u_t9y);    ta[9]=u_t9a;
  tp[10]=vec2(u_t10x,u_t10y); ta[10]=u_t10a;
  tp[11]=vec2(u_t11x,u_t11y); ta[11]=u_t11a;

  // ── LARGE fluid presence field ────────────────────────────────────────────
  // Key insight from reference: fluid is BIG, extends 0.4+ screen units from finger
  // Use soft gaussian with large radius, not tight capsule
  float presence = 0.0;

  // Trail segments — large soft radius
  for(int i=0;i<11;i++){
    if(ta[i]>=1.0&&ta[i+1]>=1.0) continue;
    float age = (ta[i]+ta[i+1])*0.5;
    float op  = pow(max(0.0,1.0-age),0.8); // slow fade
    float r   = mix(0.45, 0.12, age);       // LARGE radius — 0.45 of screen height
    vec2 a2=tp[i], b2=tp[i+1];
    vec2 sc=vec2(asp,1.0);
    vec2 pa=(uv-a2)*sc, ba=(b2-a2)*sc;
    float h=clamp(dot(pa,ba)/max(dot(ba,ba),1e-4),0.0,1.0);
    float d=length(pa-ba*h);
    presence=max(presence, exp(-d*d/(r*r*0.5))*op);
  }
  // Trail points
  for(int i=0;i<12;i++){
    if(ta[i]>=1.0) continue;
    float op = pow(max(0.0,1.0-ta[i]),0.8);
    float r  = mix(0.40,0.10,ta[i]);
    vec2 d=(uv-tp[i])*vec2(asp,1.0);
    presence=max(presence, exp(-dot(d,d)/(r*r*0.5))*op);
  }
  // Live finger — largest blob, instant full presence
  vec2 ftd=(uv-u_touch)*vec2(asp,1.0);
  float fingerBlob = exp(-dot(ftd,ftd)/(0.35*0.35*0.5))*u_touchForce;
  presence=clamp(presence+fingerBlob,0.0,1.0);

  if(presence<0.003){fragColor=vec4(0,0,0,1);return;}

  // ── Velocity ──────────────────────────────────────────────────────────────
  float velMag = clamp(length(u_velocity)*120.0, 0.0, 1.0);
  vec2  velDir = velMag>0.001 ? normalize(u_velocity) : vec2(0.0);

  // ── UV distortion driven by drag — this is what creates the taffy stretch ─
  // Pull UVs along drag direction near the touch, creating dumbbell/streak shape
  vec2 toTouch = u_touch - uv;
  float distToTouch = length(toTouch*vec2(asp,1.0));
  // Warp strength falls off with distance but covers a LARGE area
  float warpStrength = exp(-distToTouch*distToTouch/(0.5*0.5)) * velMag;
  vec2 warpedUV = uv + velDir * warpStrength * 0.35;

  // Time — flows faster with drag
  float t2 = u_time*0.12 + velMag*2.0;

  // ── Multi-layer fBm ───────────────────────────────────────────────────────
  // Layer 1: large scale swirling body (like the outer green/yellow in reference)
  vec2 p1 = warpedUV*3.0 + vec2(t2*0.7, u_time*0.05) + u_gyro*0.4;
  vec2 q1 = vec2(fbm(p1), fbm(p1+vec2(3.7,1.9)));
  float body = fbm(p1 + 2.5*q1 + velDir*velMag*2.0);
  body = body*0.5+0.5;

  // Layer 2: fine internal detail (the hot core swirls)
  vec2 p2 = warpedUV*5.5 + vec2(u_time*0.18, t2*0.4) + u_gyro*0.6;
  vec2 q2 = vec2(fbm(p2+u_time*0.1), fbm(p2+vec2(5.2,1.3)+u_time*0.08));
  float detail = fbm(p2 + 1.8*q2);
  detail = detail*0.5+0.5;

  // ── Shape: fBm defines the fluid boundary, presence gates it ─────────────
  // body controls outer shape — low body = transparent (dark voids between lobes)
  float outerMask = smoothstep(0.28, 0.65, body) * presence;
  // detail punches holes inside for inner texture
  float innerMask = smoothstep(0.35, 0.72, detail) * outerMask;
  // Allow outer lobes to extend slightly beyond tight presence (like reference tendrils)
  float tendrils  = smoothstep(0.55, 0.80, body) * smoothstep(0.15, 0.60, presence);
  float fluidMask = clamp(max(innerMask, tendrils*0.85), 0.0, 1.0);

  // Drag streaking — fast drags let bright filaments bleed further
  fluidMask = clamp(fluidMask + velMag*0.3*smoothstep(0.62,0.88,body)*presence, 0.0,1.0);

  if(fluidMask<0.004){fragColor=vec4(0,0,0,1);return;}

  // ── Color: two-layer like reference (outer cool + hot core) ───────────────
  // Outer layer color (cooler, larger) — deep violet to bright violet
  vec3 outerCol;
  outerCol  = mix(vec3(0.03,0.01,0.18), vec3(0.28,0.05,0.75), smoothstep(0.25,0.55,body));
  outerCol  = mix(outerCol, vec3(0.55,0.25,1.00), smoothstep(0.50,0.72,body));
  outerCol  = mix(outerCol, vec3(0.88,0.70,1.00), smoothstep(0.68,0.92,body));

  // Inner/hot layer — brighter, detail-driven (like orange core in reference)
  vec3 hotCol;
  hotCol  = mix(vec3(0.20,0.02,0.60), vec3(0.70,0.30,1.00), smoothstep(0.35,0.65,detail));
  hotCol  = mix(hotCol, vec3(0.95,0.85,1.00), smoothstep(0.62,0.90,detail));

  // Blend: core detail shows through on top of outer body
  float hotBlend = smoothstep(0.40,0.70,detail) * smoothstep(0.45,0.75,outerMask);
  vec3 col = mix(outerCol, hotCol, hotBlend*0.75);

  // Drag glow — the bright hot streak along drag direction (like orange in reference)
  vec3 streakCol = mix(vec3(0.85,0.65,1.0), vec3(1.0,0.97,1.0), velMag);
  col = mix(col, streakCol, velMag*0.7*warpStrength*smoothstep(0.45,0.75,body));

  // Live finger contact — hottest point
  float fg = exp(-dot(ftd,ftd)/(0.08*0.08))*u_touchForce;
  col = mix(col, vec3(1.0,0.97,1.0), fg*0.9);

  // Entry burst
  col *= 1.0 + u_touchBurst*0.5;

  // Breath
  col *= 1.0 + (u_breath-0.5)*0.14;

  // Gamma lift — luminous not flat
  col = pow(max(col,vec3(0.0)), vec3(0.85));

  fragColor = vec4(col*fluidMask, 1.0);
}
