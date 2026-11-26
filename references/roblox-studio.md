# Roblox Studio Implementation Guide

## Hybrid Voxel + Photorealistic VFX in Roblox

Roblox engine does not permit low-level custom fragment shaders, so we achieve real-time voxel realism through a specialized hybrid approach:

### 1. Voxel Destruction Architecture
- **Base World**: Modeled with Roblox `Terrain` API (`workspace.Terrain:FillBall`, `FillBlock`, `SubtractBlock`) or high-density `Part` grids.
- **Micro-Destruction**:
  - When an explosion or projectile hits, invoke `Terrain:SubtractBlock()` or `Terrain:FillBall()` with air.
  - Instantiate localized physical voxel debris using pre-meshed cubes with `AssemblyLinearVelocity` and physical impulses.
  - Automatically weld or cleanup debris after 10-15 seconds to maintain 60 FPS.

### 2. Photorealistic Water
- Use Roblox `Terrain:SetMaterialColor(Enum.Material.Water, Color3.fromRGB(15, 60, 80))`.
- Configure `Terrain.WaterTransparency = 0.85`, `Terrain.WaterWaveSize = 0.35`, `Terrain.WaterWaveSpeed = 12`.
- Place animated underwater caustics via `Beam` or `SurfaceGui` projectors.
- Add screen-space depth distortion using `Atmosphere` and `ColorCorrectionEffect` when camera is underwater.

### 3. Photorealistic Fire, Smoke & Sparks
- Stack 3 distinct `ParticleEmitter` layers per combustion site:
  - **Layer 1: Fire Core**: Short lifetime (0.2s - 0.5s), high emission speed, emissive texture, LightEmission = 1.0, color gradient 2200K yellow -> 1400K orange.
  - **Layer 2: Dense Smoke**: Long lifetime (2s - 5s), slow rise with drag, dark absorbing texture, LightEmission = 0.0, opacity ramp.
  - **Layer 3: Embers / Sparks**: Point particles, high velocity variance, bounce physics, glowing orange, size 0.05.
