# Realistic Voxel Shaders & PBR Pipeline

## 1. Triplanar PBR Mapping on Voxels

Voxels do not have explicit UV unwrapping. Triplanar projection projects texture coordinates along X, Y, and Z axes based on world-space normals:

```hlsl
vec3 blend = abs(normal);
blend = pow(blend, vec3(8.0)); // Sharpen projection boundary
blend /= (blend.x + blend.y + blend.z);

vec4 colX = sampleTexture(tex, worldPos.yz * uvScale);
vec4 colY = sampleTexture(tex, worldPos.xz * uvScale);
vec4 colZ = sampleTexture(tex, worldPos.xy * uvScale);

vec4 albedo = colX * blend.x + colY * blend.y + colZ * blend.z;
```

---

## 2. Voxel Ambient Occlusion (VAO)

To achieve realistic depth in crevices and corners without heavy ray tracing:
- Sample 8 corner neighbors around the impacted voxel face.
- Calculate corner occlusion using formula:
  $$\text{AO} = \frac{\text{side}_1 + \text{side}_2 + \text{corner}}{3}$$
- When raymarching: shoot 4-8 hemispherical AO rays with maximum distance of 2-4 voxel units.

---

## 3. Soft Contact Shadows (Cone Tracing)

When a primary ray hits a voxel, trace a shadow ray towards light:
- Advance ray using DDA or Sphere Tracing.
- Track minimum distance to closest solid voxel along ray path:
  $$\text{Shadow} = \min\left(1.0, k \cdot \frac{d_{\min}}{t}\right)$$
- Softens shadows dynamically as distance from caster increases.

---

## 4. Screen-Space Reflections (SSR) & Voxel Reflections

- For high-gloss voxels (polished metal, wet tiles, glass):
  - Primary reflection: Screen-space raymarching against depth buffer.
  - Fallback: Low-resolution secondary DDA ray step into voxel grid.
