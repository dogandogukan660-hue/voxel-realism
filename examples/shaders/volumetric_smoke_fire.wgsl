// WebGPU WGSL: Volumetric Heterogeneous Smoke & Fire Raymarcher
// Features: Henyey-Greenstein scattering, Beer's law extinction,
// Blackbody radiation color ramp, and 3D procedural noise advection.

struct VolumeParams {
    cameraPos: vec3<f32>,
    time: f32,
    invViewProj: mat4x4<f32>,
    lightPos: vec3<f32>,
    lightColor: vec3<f32>,
    volumeMin: vec3<f32>,
    volumeMax: vec3<f32>,
    absorptionCoeff: f32, // e.g. 1.2 for smoke
    scatteringCoeff: f32, // e.g. 0.8
};

@group(0) @binding(0) var<uniform> v: VolumeParams;
@group(0) @binding(1) var inColor: texture_2d<f32>;
@group(0) @binding(2) var outVolume: texture_storage_2d<rgba16float, write>;

// Henyey-Greenstein Phase Function
fn henyeyGreenstein(cosTheta: f32, g: f32) -> f32 {
    let g2 = g * g;
    return (1.0 - g2) / (4.0 * 3.14159265 * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
}

// Pseudo-3D Perlin Noise
fn hash3(p: vec3<f32>) -> f32 {
    let q = fract(p * 0.3183099 + vec3<f32>(0.1));
    let q2 = q * 17.0;
    return fract(q2.x * q2.y * q2.z * (q2.x + q2.y + q2.z));
}

fn noise3D(x: vec3<f32>) -> f32 {
    let p = floor(x);
    let f = fract(x);
    let u = f * f * (3.0 - 2.0 * f);

    let n000 = hash3(p + vec3<f32>(0.0, 0.0, 0.0));
    let n100 = hash3(p + vec3<f32>(1.0, 0.0, 0.0));
    let n010 = hash3(p + vec3<f32>(0.0, 1.0, 0.0));
    let n110 = hash3(p + vec3<f32>(1.0, 1.0, 0.0));
    let n001 = hash3(p + vec3<f32>(0.0, 0.0, 1.0));
    let n101 = hash3(p + vec3<f32>(1.0, 0.0, 1.0));
    let n011 = hash3(p + vec3<f32>(0.0, 1.0, 1.0));
    let n111 = hash3(p + vec3<f32>(1.0, 1.0, 1.0));

    return mix(
        mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
        mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
        u.z
    );
}

// Blackbody radiation color temperature ramp
fn blackbody(temperature: f32) -> vec3<f32> {
    // Temp normalized 0.0 (cold smoke) to 1.0 (white hot flame)
    let t = clamp(temperature, 0.0, 1.0);
    let fireColor = vec3<f32>(
        pow(t, 0.8) * 3.5,
        pow(t, 2.2) * 2.0,
        pow(t, 4.0) * 1.0
    );
    return fireColor;
}

// Ray-AABB intersection
fn intersectAABB(rayOrigin: vec3<f32>, rayDir: vec3<f32>, bMin: vec3<f32>, bMax: vec3<f32>) -> vec2<f32> {
    let invD = 1.0 / rayDir;
    let t0 = (bMin - rayOrigin) * invD;
    let t1 = (bMax - rayOrigin) * invD;
    let tmin = max(max(min(t0.x, t1.x), min(t0.y, t1.y)), min(t0.z, t1.z));
    let tmax = min(min(max(t0.x, t1.x), max(t0.y, t1.y)), max(t0.z, t1.z));
    return vec2<f32>(max(tmin, 0.0), tmax);
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) globalId: vec3<u32>) {
    let dims = textureDimensions(outVolume);
    if (globalId.x >= dims.x || globalId.y >= dims.y) {
        return;
    }

    let uv = (vec2<f32>(globalId.xy) + 0.5) / vec2<f32>(dims);
    let ndc = vec4<f32>(uv.x * 2.0 - 1.0, (1.0 - uv.y) * 2.0 - 1.0, 1.0, 1.0);
    let worldTarget = v.invViewProj * ndc;
    let rayDir = normalize(worldTarget.xyz / worldTarget.w - v.cameraPos);

    let hit = intersectAABB(v.cameraPos, rayDir, v.volumeMin, v.volumeMax);
    var baseColor = textureLoad(inColor, vec2<i32>(globalId.xy), 0).rgb;

    if (hit.y <= hit.x) {
        textureStore(outVolume, vec2<i32>(globalId.xy), vec4<f32>(baseColor, 1.0));
        return;
    }

    let steps = 48;
    let stepSize = (hit.y - hit.x) / f32(steps);
    var t = hit.x + stepSize * 0.5;

    var transmittance = 1.0;
    var accumulatedRadiance = vec3<f32>(0.0);
    let g = 0.4; // Forward scattering smoke

    for (var i = 0; i < steps; i++) {
        let p = v.cameraPos + rayDir * t;
        let animatedCoord = (p * 0.4) - vec3<f32>(0.0, v.time * 0.8, 0.0);
        
        let densityNoise = noise3D(animatedCoord) * 0.7 + noise3D(animatedCoord * 2.1) * 0.3;
        let distFromCenter = length(p.xz - (v.volumeMin.xz + v.volumeMax.xz) * 0.5);
        let radialFalloff = max(0.0, 1.0 - distFromCenter * 0.25);
        let density = max(0.0, densityNoise * radialFalloff - 0.2) * 4.0;

        if (density > 0.001) {
            let extinction = density * (v.absorptionCoeff + v.scatteringCoeff);
            let stepTransmittance = exp(-extinction * stepSize);

            // Combustion core (Fire at bottom, smoke at top)
            let heightNorm = clamp((p.y - v.volumeMin.y) / (v.volumeMax.y - v.volumeMin.y), 0.0, 1.0);
            let temperature = max(0.0, (1.0 - heightNorm * 1.5) * density);
            let flameEmission = blackbody(temperature);

            // Sun / Light In-Scattering
            let toLight = normalize(v.lightPos - p);
            let phase = henyeyGreenstein(dot(rayDir, toLight), g);
            let inScattering = v.lightColor * phase * v.scatteringCoeff * density;

            let currentRadiance = flameEmission + inScattering;
            accumulatedRadiance += currentRadiance * (1.0 - stepTransmittance) * transmittance;
            transmittance *= stepTransmittance;

            if (transmittance < 0.01) {
                break;
            }
        }

        t += stepSize;
    }

    let finalColor = baseColor * transmittance + accumulatedRadiance;
    textureStore(outVolume, vec2<i32>(globalId.xy), vec4<f32>(finalColor, 1.0));
}
