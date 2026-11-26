# WebGPU & Three.js Implementation Guide

## Architecture Overview

```
[Three.js Scene] 
     │
     ├── Fullscreen Quad / Compute Pass (WebGPU)
     │       ├── Voxel World Storage Buffer / 3D Texture
     │       ├── Dynamic Smoke/Fire Volume Buffer (128x128x128)
     │       └── Compute Particles Buffer (100k particles)
     │
     └── Render Passes:
             1. Voxel DDA Compute Raymarch -> Color + Depth
             2. Water Surface Mesh + Gerstner Displacement
             3. Volumetric Raymarching Pass (Smoke/Fire)
             4. GPU Particle Billboards / Points
             5. Post-Processing (Bloom + ACES Tone Mapping)
```

## Key WebGPU Components

1. **3D Texture Allocation**:
   ```javascript
   const voxelTexture = device.createTexture({
     size: [256, 256, 256],
     format: 'r32uint',
     usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.COPY_DST,
   });
   ```

2. **Compute Pipeline for DDA Raymarching**:
   - Write rays from inverse View-Projection matrix.
   - Run 3D DDA traversal per pixel.
   - Output directly to color texture and depth attachment.

3. **Integrating with Three.js**:
   - Use `WebGPURenderer` (Three.js r160+).
   - Use `StorageBufferNode` and `ComputeNode` for GPU-side simulation of fluid particles and voxel edits.
