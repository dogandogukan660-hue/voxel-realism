# Realistic Fire, Volumetric Smoke & Particle Systems

## 1. Volumetric Smoke Simulation & Rendering

### Radiative Transfer Equation (RTE)
For light traveling through participating media along ray $r(t) = O + t D$:

$$\frac{d L(t)}{d t} = -\sigma_t(t) L(t) + \sigma_s(t) \int_{4\pi} P(\theta) L_i(t, \omega_i) d\omega_i + L_e(t)$$

- $\sigma_a$: Absorption coefficient
- $\sigma_s$: Scattering coefficient
- $\sigma_t = \sigma_a + \sigma_s$: Extinction coefficient
- $L_e$: Emissive radiance (fire / flame glow)
- $P(\theta)$: Phase function (Henyey-Greenstein)

### Henyey-Greenstein Phase Function
$$P(\theta) = \frac{1 - g^2}{4\pi (1 + g^2 - 2g \cos\theta)^{1.5}}$$
- $g \in (-1, 1)$: Anisotropy factor.
- For smoke: $g \approx 0.35$ (slight forward scattering gives soft edges and dramatic sun backlight glows).

---

## 2. Realistic Fire & Combustion

- **Temperature Field**: Advected upward via buoyant force ($F = \alpha (T - T_0) \vec{u}_{up}$).
- **Blackbody Color Mapping**:
  Convert temperature (Kelvin) to RGB radiance using Planck's radiation law approximation:
  - 1000K: Dark red/cherry glow
  - 1500K: Bright orange flame
  - 2200K: Vibrant yellow-white core
- **Soot Density**: When fuel burns out, density transitions from emissive flame into dark absorbing smoke.

---

## 3. High-Performance GPU Particles

- Compute shader updates $100,000+$ sparks, embers, and water splashes in storage buffers.
- Physics:
  - Velocity integration: $\vec{v}_{t+1} = \vec{v}_t + (\vec{g} - C_d |\vec{v}|\vec{v}) \Delta t$
  - Voxel grid collision: Sample voxel grid at particle position; reflect velocity along hit normal with restitution coefficient ($\epsilon = 0.4$).
- Embers: Curl noise velocity perturbation + exponential decay of temperature and emissive intensity.
