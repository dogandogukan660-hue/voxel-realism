---
name: voxel-realism
description: "Build volumetric destructible voxel engines with photorealistic PBR shaders, physical water (Gerstner waves, refraction, foam), volumetric smoke & fire (Henyey-Greenstein, blackbody emission), and GPU particles across Web (Three.js/WebGPU/Rust Wasm), Native (C++/Vulkan/OpenGL), and Roblox Studio."
---

# Voxel Realism Engine & VFX Skill

Specialized engineering skill for building hybrid volumetric voxel worlds with AAA photorealistic visuals. The world is made of destructible voxels; water, lighting, fire, smoke, and particles are rendered with real-time physical simulation and photorealistic shaders.

## Target Architectures

1. **Web (WebGPU / Three.js / Rust Wasm)**
   - Voxel representation: 3D texture atlas (`texture_3d<u32>`) or hierarchical brick maps.
   - Renderer: WGSL compute raymarcher (Digital Differential Analyzer - 3D DDA).
   - Water: Dual-depth extinction shader with Gerstner wave displacement, Snell refraction, and screen-space reflections (SSR).
   - Fire & Smoke: Volumetric raymarcher with 3D simplex/Worley noise, Beer's law extinction, and Henyey-Greenstein scattering.
   - Particles: WebGPU compute storage buffer driven particle system.

2. **Native (C++ / Vulkan / OpenGL)**
   - Voxel representation: Sparse Voxel Octree (SVO) or 2-level Clipmap / Indirection Paged Grid.
   - Raymarching: Fast ray traversal on compute queue with sub-group ballot optimizations.
   - Physics: Voxelized collision islands, stress analysis for structural collapse, convex hull decomposition for detached debris.
   - Post-Processing: Temporal Anti-Aliasing (TAA), screen-space ambient occlusion (SSAO), bloom, tone mapping (ACES).

3. **Roblox Studio (Luau Engine)**
   - Voxel handling: Hybrid system using `Terrain` API + dynamic `EditableMesh` / greedy meshed `Part` clusters for localized micro-destruction.
   - VFX: Custom layered `ParticleEmitter` systems with realistic PBR textures, flipbooks, emission curves, and light emission.
   - Water: Realistic water surface with custom SurfaceAppearance, normal map animation, refraction simulation, and underwater post-processing effects.

---

## Core Algorithms & Math Reference

### 1. 3D Digital Differential Analyzer (DDA)
Fastest ray-voxel grid traversal without skipping:
```
tDeltaX = abs(1.0 / rayDir.x)
stepX   = sign(rayDir.x)
tMaxX   = (nextVoxelBoundaryX - rayOrigin.x) / rayDir.x
```
Each iteration steps exactly one voxel along the axis with the minimum `tMax`:
```
if (tMaxX < tMaxY && tMaxX < tMaxZ) {
    voxelPos.x += stepX;
    tMaxX += tDeltaX;
    hitNormal = vec3(-stepX, 0.0, 0.0);
}
```

### 2. Physical Water Shader Pipeline
- **Wave Displacement**: Sum of 4-8 Gerstner waves calculating position offset and analytic tangent/binormal vectors.
- **Beer-Lambert Law (Absorption)**:
  `T = exp(-extinction_coefficient * water_depth)`
  Deep water turns deep blue/green; shallow water remains transparent.
- **Fresnel Reflectance (Schlick's Approximation)**:
  `R = F0 + (1 - F0) * pow(1 - dot(N, V), 5)` (with `F0 = 0.02` for water).
- **Refraction**: Sample scene color buffer with UV offset along normal vector, clamped by depth delta to eliminate boundary bleed.
- **Foam**: Foam texture blended where `water_depth < foam_threshold` or wave crest curvature exceeds threshold.

### 3. Volumetric Smoke & Fire Raymarching
- **Density Sampling**: Dynamic fluid grid or animated 3D curl/Worley noise.
- **Light Extinction (Beer's Law)**:
  `transmittance *= exp(-density * step_size * absorption_coeff)`
- **In-Scattering (Henyey-Greenstein Phase Function)**:
  `P(theta) = (1 - g^2) / (4 * pi * pow(1 + g^2 - 2 * g * cos(theta), 1.5))`
  Forward scattering for smoke: `g = 0.3 - 0.7`.
- **Fire Emission (Blackbody Radiation)**:
  Convert combustion temperature (1000K - 3000K) to emissive RGB spectrum, blended with soot absorption.

---

## Skill Files & Resources

- **[Architecture & Data Structures](references/architecture.md)**: SVO, 3D textures, memory layout, and chunk paging.
- **[Realistic Shaders & Lighting](references/realistic-shaders.md)**: Triplanar mapping, voxel ambient occlusion, SSR, contact shadows.
- **[Realistic Water Simulation](references/realistic-water.md)**: Gerstner math, depth extinction, SSR, caustics, and foam.
- **[Realistic Fire, Smoke & VFX](references/realistic-fire-smoke.md)**: Volumetric media, phase functions, curl noise, and GPU particles.
- **[WebGPU & Three.js Guide](references/webgpu-threejs.md)**: Web-based implementation runbook.
- **[Native C++ & Vulkan Guide](references/native-cpp-vulkan.md)**: Desktop high-performance compute runbook.
- **[Roblox Studio Implementation](references/roblox-studio.md)**: Luau destruction and cinematic VFX setup.

## Ready-to-Use Code Assets

- `examples/shaders/voxel_raymarch.wgsl`: Complete WebGPU WGSL voxel DDA compute raymarcher with PBR & soft shadows.
- `examples/shaders/realistic_water.wgsl`: Production-grade WGSL water surface shader.
- `examples/shaders/volumetric_smoke_fire.wgsl`: Volumetric heterogeneous smoke/fire raymarcher.
- `examples/shaders/voxel_dda.glsl`: OpenGL / Vulkan GLSL DDA shader.
- `examples/roblox/VoxelDestruction.luau`: Real-time voxel damage & fragment spawner for Roblox.
- `examples/roblox/RealisticVFXSetup.luau`: Cinematic fire, smoke, and water particle instantiator for Roblox.
