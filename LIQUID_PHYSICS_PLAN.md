# Real Liquid Physics Simulation Plan

Convert the Liquid Ether fluid simulation from procedural warping to realistic physics-based liquid dynamics.

---

## 🌊 Phase 1: Velocity Field Simulation

### Objective
Replace procedural warping with a **velocity field** that advects over time, creating natural flowing patterns instead of immediate warping.

### Implementation Details

**Velocity Field Texture:**
- Create a framebuffer texture to store 2D velocity (RG channels)
- Use ping-pong technique: read from one texture, write to another each frame
- Resolution: match canvas resolution or use half-resolution for performance

**Velocity Injection (Touch Input):**
- When user touches, calculate **velocity vector** (dx/dt based on finger movement)
- Splat velocity onto the velocity texture at touch position
- Apply falloff using Gaussian kernel

**Velocity Advection:**
- Advect velocity field backwards in time using Euler/MacCormack integration
- Sample velocity at current position and trace back to previous position
- This creates self-sustaining flow patterns

**Viscous Diffusion:**
- Apply diffusion pass to smooth velocity (simulates viscosity)
- Use Gauss-Seidel iteration or simple blurring
- Adjustable via `turbulence` parameter

### Files to Modify
- `lib/widgets/liquid_ether.dart` - Add velocity framebuffer management
- `lib/shaders/fluid.frag` - Add velocity field sampling and advection
- `lib/widgets/touch_point.dart` - Track velocity instead of just strength
- `lib/widgets/liquid_ether_painter.dart` - Update framebuffer each frame

---

## 🌊 Phase 2: Surface Height/Wave Simulation

### Objective
Add a **height field** layer for realistic wave and splash physics.

### Implementation Details

**Height Field Texture:**
- Store water surface elevation in a texture (single channel)
- Initialize to flat (0.5 for normalized coordinates)
- Update each frame based on shallow water equations

**Wave Physics:**
- Implement shallow water wave equation: ∂²h/∂t² = c² ∇²h
- Use Laplacian operator on height texture to compute acceleration
- Integrate using velocity (two-pass integration for stability)

**Touch-Induced Splashes:**
- When user touches, directly displace height at touch position
- Displacement magnitude based on touch velocity/strength
- Creates ripples that propagate outward

**Wave Damping:**
- Apply velocity damping to waves to dissipate energy over time
- Adjustable damping coefficient (related to `glowIntensity` parameter)
- Prevents infinite wave resonance

**Interference Patterns:**
- Multiple touch points create wave interference
- Waves reinforce where peaks meet, cancel where out-of-phase
- Creates realistic multi-touch surface patterns

### Files to Modify
- `lib/widgets/liquid_ether.dart` - Add height field framebuffer
- `lib/shaders/fluid_utils.glsl` - Add Laplacian and wave propagation functions
- `lib/shaders/fluid.frag` - Implement shallow water wave equation

---

## 🌊 Phase 3: Realistic Visuals

### Objective
Enhance rendering to look like real liquid with lighting, refraction, and caustics.

### Color & Transparency

**Depth-Based Coloring:**
- Sample height field to determine water depth at each pixel
- Deeper areas: darker blue/teal
- Shallower areas (waves): lighter, more translucent
- Color gradient: `vec3 color = mix(deepBlue, shallowTeal, height);`

**Palette Update:**
```glsl
vec3 deepBlue = vec3(0.05, 0.2, 0.5);      // Dark ocean depth
vec3 midTeal = vec3(0.1, 0.4, 0.6);         // Mid-depth
vec3 shallowCyan = vec3(0.3, 0.8, 0.9);    // Wave crests
```

### Caustics (Light Patterns)

**Caustic Generation:**
- Use layered Voronoi or simplex noise with time offset
- Create moving light patterns that simulate underwater caustics
- Apply to final color with additive blending

```glsl
vec3 caustics = causticPattern(uv + time * 0.1);
color += caustics * 0.2;
```

**Multiple Caustic Layers:**
- Layer 2-3 caustic patterns at different scales and speeds
- Creates complexity and realism

### Refraction (Surface Distortion)

**Normal Map from Height Field:**
- Calculate surface normals from height field gradients
- Normal = normalize(vec3(-dh/dx, -dh/dy, 1.0))
- Use normals to distort background/underlying pattern

```glsl
vec2 normal = getHeightFieldNormal(uv);
vec2 refractedUv = uv + normal * 0.05;
```

### Specular Highlights

**Wave Peak Lighting:**
- Calculate surface normal from height field
- Apply Phong/Blinn-Phong lighting with light direction
- Highlight peaks where normal faces light source

```glsl
vec3 normal = getHeightFieldNormal(uv);
float specular = pow(max(dot(normal, lightDir), 0.0), 32.0);
color += specular * vec3(1.0, 0.95, 0.9) * 0.5;
```

### Film Grain & Anti-Aliasing

**Subtle Noise:**
- Add procedural film grain to avoid flat appearance
- Use high-frequency noise with low amplitude (0.01-0.02)

**Smooth Blending:**
- Apply slight blur to height field normals for smoother transitions
- Prevents aliasing artifacts

### Files to Modify
- `lib/shaders/fluid.frag` - Complete rewrite of color/lighting calculation
- `lib/shaders/fluid_utils.glsl` - Add caustic, normal, and specular functions

---

## 🌊 Phase 4: Touch Interaction Polish

### Objective
Make touches feel like physically interacting with liquid.

### Velocity-Based Momentum

**Track Finger Velocity:**
- Calculate velocity from frame-to-frame position change
- Store velocity history in `TouchPoint`
- Update: `velocity = (currentPos - lastPos) / deltaTime`

**Momentum Carry-Through:**
- When finger lifts, velocity doesn't instantly stop
- Continue injecting velocity for a few frames with exponential decay
- Creates "afterflow" effect

**Pressure from Velocity:**
- Base touch strength on finger speed, not just presence
- Fast swipes = stronger disturbance
- Slow hovers = gentle waves

### Multi-Touch Interference

**Wave Superposition:**
- Multiple fingers create overlapping waves
- Height field naturally handles interference (peaks add, troughs subtract)
- No special code needed—physics handles it

**Velocity Field Interaction:**
- Multiple velocity sources mix in velocity field
- Creates swirling patterns where different velocities meet

### Visual Feedback

**Touch Point Trails:**
- Render subtle glow at touch positions
- Trails fade as momentum decays
- Shows where user is manipulating liquid

**Ripple Animation:**
- Immediate visible wave at touch point
- Ripple expands outward, interferes with other waves
- User sees direct cause-and-effect

### Files to Modify
- `lib/widgets/touch_point.dart` - Add velocity tracking and momentum
- `lib/widgets/liquid_ether.dart` - Calculate velocity from pointer deltas
- `lib/shaders/fluid.frag` - Visualize touch trails (optional)

---

## 📊 Implementation Strategy

### Step-by-Step Approach

1. **Start with Phase 1 (Velocity Field)**
   - Implement framebuffer ping-pong in `liquid_ether.dart`
   - Rewrite shader advection logic
   - Test: velocity should flow and dampen smoothly

2. **Add Phase 2 (Waves)**
   - Add height field framebuffer
   - Implement wave equation
   - Test: ripples should propagate and dampen

3. **Polish with Phase 3 (Visuals)**
   - Update color palette
   - Add caustics
   - Add refraction
   - Add specular highlights

4. **Enhance with Phase 4 (Interaction)**
   - Track touch velocity
   - Implement momentum decay
   - Add visual feedback

### Performance Considerations

**Optimization Points:**
- Use half-resolution framebuffers for velocity/height fields (then upscale in shader)
- Use simple Laplacian operator (3x3 kernel) for wave propagation
- Limit caustic detail (2 layers max)
- Cache normal calculations when possible

**Estimated Cost:**
- Velocity advection: ~5-10ms per frame
- Wave propagation: ~5-8ms per frame
- Caustics & lighting: ~3-5ms per frame
- Total: ~15-25ms on typical mobile GPU (60fps target: 16.67ms budget)

---

## 🎯 Success Criteria

- [ ] Liquid responds smoothly to touch with visible momentum
- [ ] Multiple touches create realistic wave interference patterns
- [ ] Fluid flows naturally with visible velocity currents
- [ ] Caustics and refraction create depth perception
- [ ] Maintains 55-60 FPS on mobile devices
- [ ] No visual artifacts or aliasing
- [ ] Touch trails and ripples are intuitive

---

## 📝 Notes

- **Shader Compilation**: Ensure GLSL syntax matches Flutter's Impeller compiler (version 460 core)
- **Framebuffer Management**: Use `ui.Image` or raw texture bindings for ping-pong technique
- **Uniform Order**: Maintain exact order when calling `shader.setFloat()` in Dart
- **Testing**: Test on both emulator and physical device (different performance profiles)
