# Voxel Realism Engine & VFX Skill

Antigravity agent skill for building volumetric voxel environments with physically based rendering, realistic water surfaces, volumetric fire & smoke, and GPU particle physics.

## Supported Platforms
- **Web**: WebGPU / Three.js / Rust Wasm (WGSL compute raymarching)
- **Native**: C++ / Vulkan / OpenGL (3D DDA traversal, SVO)
- **Roblox Studio**: Luau engine (Terrain destruction, micro-debris, multi-layer particle systems)

## Skill Structure
- `SKILL.md`: Main Antigravity skill definition.
- `references/`: Architectural and mathematical implementation guides.
- `examples/`: Shaders (WGSL, GLSL) and Luau scripts.

## Installation
Clone or copy into your Antigravity skills directory:
```bash
git clone https://github.com/<your-username>/voxel-realism.git ~/.agents/skills/voxel-realism
```

## License
MIT
