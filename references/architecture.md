# Volumetric Voxel Architecture & Data Structures

## 1. Storage Schemes

### Scheme A: Paged Brick Map (Hierarchical Grid)
- World divided into $16 \times 16 \times 16$ or $8 \times 8 \times 8$ voxel bricks.
- Top level: Indirection grid (pointer / index buffer).
- Leaves: Dense 3D texture containing actual voxel data (Material ID, Roughness, Metalness, Emissive).
- Advantages: Zero overhead for empty space, fast spatial lookups ($O(1)$ to locate brick, $O(1)$ to read voxel), seamless streaming.

### Scheme B: Sparse Voxel Octree (SVO)
- Hierarchical tree up to depth 10 (giving $1024^3$ resolution).
- Node: 64-bit child descriptor with child mask and pointer offset.
- Traversal: Ray-box intersection with bitwise stack push/pop.
- Advantages: Extreme memory efficiency for large static worlds; automatic Level of Detail (LOD).

### Scheme C: 3D Texture Clipmaps
- Concentric 3D grids centered around player camera ($256^3$ per clipmap level).
- Fast scrolling via modulo wrapping.
- Ideal for WebGPU/Mobile where pointer chasing in compute shaders hurts latency.

---

## 2. Voxel Material Format (Packed 32-bit uint)

| Bits | Field | Description |
|---|---|---|
| `[7:0]` | Material ID | Lookup index for PBR material table |
| `[15:8]` | Normal Variance | Micro-roughness / surface variation |
| `[23:16]` | Health / Integrity | Structural integrity for physics and destruction |
| `[31:24]` | Flags | Bit 0: Emissive, Bit 1: Dynamic/Debris, Bit 2: Glass/Transparent |

---

## 3. Real-Time Voxel Destruction & Physics

1. **Voxel Carving**:
   - Sphere/AABB brush clears voxels in target coordinate range.
   - Triggers dirty flag on modified bricks.
2. **Connected Component Analysis (Flood Fill)**:
   - Identify detached clusters of voxels.
   - If cluster has no ground connection, convert into a dynamic rigid body.
3. **Rigid Body Conversion**:
   - Compute center of mass and moment of inertia directly from voxel coordinates.
   - Approximate collision with bounding boxes or convex hull decomposition.
