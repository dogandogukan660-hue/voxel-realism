# Realistic Water Simulation & Shaders

## 1. Wave Model: Sum of Gerstner Waves

A single Gerstner wave displaces vertices horizontally and vertically:

$$P(x, y, t) = \begin{pmatrix} x + \sum Q_i A_i D_{i,x} \cos(k_i (D_i \cdot (x, y)) - \omega_i t) \\ y + \sum Q_i A_i D_{i,y} \cos(k_i (D_i \cdot (x, y)) - \omega_i t) \\ \sum A_i \sin(k_i (D_i \cdot (x, y)) - \omega_i t) \end{pmatrix}$$

- $D_i$: Normalized wave travel direction
- $A_i$: Wave amplitude
- $k_i = \frac{2\pi}{L_i}$: Wave number ($L_i$ = wavelength)
- $\omega_i = \sqrt{g \cdot k_i}$: Dispersion relation ($g = 9.81$)
- $Q_i$: Wave steepness ($Q_i \in [0, 1 / (k_i A_i \cdot N)]$)

Analytic normals are calculated directly from derivatives to guarantee pixel-perfect reflection and refraction without geometric artifacts.

---

## 2. Optical Properties

### Beer-Lambert Law (Absorption & Extinction)
$$I(d) = I_0 \cdot \exp(-\beta \cdot d)$$
- $\beta = (\beta_R, \beta_G, \beta_B)$: Water absorption coefficients.
- Standard oceanic water: $\beta \approx (0.22, 0.04, 0.01) \text{ m}^{-1}$. Red light extinguishes rapidly, leaving blue-green hues in deep water.

### Snell's Law & Refraction
Sample scene color buffer at:
$$\text{UV}_{\text{refr}} = \text{ScreenUV} + \text{Normal}_{\text{tangent}} \cdot \text{distortion} \cdot \min(1.0, \text{depthDelta})$$
Check depth at refracted sample: if sample is in front of water plane, discard distortion to prevent bleeding on underwater objects.

### Dynamic Foam & Shoreline Blending
- **Depth Foam**: When $\Delta d < 0.25\text{m}$, blend procedural foam texture modulated by Perlin noise.
- **Wave Crest Foam**: When Jacobian determinant of Gerstner wave $< 0.3$, wave is breaking: add foam mask.

### Caustics
Project 2 animated scrolling voronoi / simplex noise textures along sun direction onto submerged voxel surfaces.
