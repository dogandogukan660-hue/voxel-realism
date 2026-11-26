# Native C++ & Vulkan / OpenGL Implementation Guide

## Engine Architecture

1. **Memory Subsystem**:
   - `VmaAllocator` (Vulkan Memory Allocator) managing 3D sparse image memory.
   - Paged virtual memory mapping: allocate physical pages only for occupied voxel chunks.

2. **Compute Dispatch Configuration**:
   - Local workgroup size: $8 \times 8 \times 1$ threads.
   - Subgroup operations (`VK_KHR_shader_subgroup_ballot`) to dynamically skip ray traversal steps when neighboring threads hit empty bricks.

3. **Frame Pipeline**:
   - **Pass 1: Voxel DDA Traversal** (Compute Queue)
     - Outputs: G-Buffer (Albedo, Normal, Material ID, Linear Depth).
   - **Pass 2: Screen-Space Ambient Occlusion (SSAO) & Contact Shadows**
   - **Pass 3: Realistic Water Shading** (Forward+ with screen-space refraction and depth extinction)
   - **Pass 4: Volumetric Smoke & Fire** (Raymarched half-resolution with bilateral upsampling)
   - **Pass 5: TAA & Motion Blur**
   - **Pass 6: HDR Bloom & ACES Tone Mapping**

4. **Multi-threading**:
   - Physics & Destruction on worker threads (Job System).
   - GPU staging buffers updated via Vulkan Transfer Queue asynchronous copy.
