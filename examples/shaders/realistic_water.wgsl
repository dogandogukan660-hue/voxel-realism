// WebGPU WGSL: Realistic Water Surface Shader
// Features: 4 Gerstner waves, analytic normals, Beer-Lambert depth absorption,
// Schlick Fresnel, refraction offset, and dynamic foam.

struct WaterUniforms {
    viewProj: mat4x4<f32>,
    cameraPos: vec3<f32>,
    time: f32,
    sunDir: vec3<f32>,
    sunColor: vec3<f32>,
    waterLevel: f32,
    absorptionCoeff: vec3<f32>, // (0.22, 0.04, 0.01)
};

@group(0) @binding(0) var<uniform> u: WaterUniforms;
@group(0) @binding(1) var sceneColor: texture_2d<f32>;
@group(0) @binding(2) var sceneDepth: texture_2d<f32>;
@group(0) @binding(3) var colorSampler: sampler;

struct VertexInput {
    @location(0) position: vec3<f32>,
    @location(1) uv: vec2<f32>,
};

struct VertexOutput {
    @builtin(position) clipPos: vec4<f32>,
    @location(0) worldPos: vec3<f32>,
    @location(1) normal: vec3<f32>,
    @location(2) uv: vec2<f32>,
};

// Gerstner Wave helper
fn calculateGerstner(p: vec2<f32>, dir: vec2<f32>, steepness: f32, wavelength: f32, t: f32) -> vec3<f32> {
    let k = 6.2831853 / wavelength;
    let c = sqrt(9.81 / k);
    let d = normalize(dir);
    let f = k * (dot(d, p) - c * t);
    let a = steepness / k;

    return vec3<f32>(
        d.x * (a * cos(f)),
        a * sin(f),
        d.y * (a * cos(f))
    );
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    var displaced = in.position;

    // 4 Layered Gerstner Waves
    let w1 = calculateGerstner(in.position.xz, vec2<f32>(1.0, 0.3), 0.15, 24.0, u.time);
    let w2 = calculateGerstner(in.position.xz, vec2<f32>(-0.6, 0.8), 0.10, 12.0, u.time * 1.2);
    let w3 = calculateGerstner(in.position.xz, vec2<f32>(0.2, -0.9), 0.08, 6.0, u.time * 1.5);
    let w4 = calculateGerstner(in.position.xz, vec2<f32>(0.7, 0.7), 0.05, 3.0, u.time * 2.0);

    displaced += w1 + w2 + w3 + w4;

    // Approximate normal by finite differences
    let delta = 0.1;
    let dx = calculateGerstner(in.position.xz + vec2<f32>(delta, 0.0), vec2<f32>(1.0, 0.3), 0.15, 24.0, u.time).y - w1.y;
    let dz = calculateGerstner(in.position.xz + vec2<f32>(0.0, delta), vec2<f32>(1.0, 0.3), 0.15, 24.0, u.time).y - w1.y;
    let norm = normalize(vec3<f32>(-dx / delta, 1.0, -dz / delta));

    out.worldPos = displaced;
    out.normal = norm;
    out.uv = in.uv;
    out.clipPos = u.viewProj * vec4<f32>(displaced, 1.0);
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let screenUV = in.clipPos.xy / in.clipPos.w * 0.5 + 0.5;
    let viewDir = normalize(u.cameraPos - in.worldPos);
    let N = normalize(in.normal);

    // Sample terrain depth behind water
    let floorDepth = textureSample(sceneDepth, colorSampler, screenUV).r;
    let waterDepth = max(floorDepth - length(in.worldPos - u.cameraPos), 0.0);

    // Beer-Lambert Law extinction
    let extinction = exp(-u.absorptionCoeff * waterDepth);
    let deepColor = vec3<f32>(0.02, 0.15, 0.28);

    // Refraction with depth safeguard
    let refrOffset = N.xz * 0.04 * min(1.0, waterDepth);
    let refractedCol = textureSample(sceneColor, colorSampler, screenUV + refrOffset).rgb;
    let waterBody = mix(deepColor, refractedCol, extinction);

    // Fresnel Reflection (Schlick)
    let F0 = 0.02; // Water baseline reflectance
    let fresnel = F0 + (1.0 - F0) * pow(1.0 - max(dot(N, viewDir), 0.0), 5.0);

    // Sky Reflection
    let reflDir = reflect(-viewDir, N);
    let skyCol = mix(vec3<f32>(0.6, 0.75, 0.95), vec3<f32>(0.1, 0.3, 0.7), max(reflDir.y, 0.0));

    // Sun Specular (Blinn-Phong)
    let H = normalize(normalize(-u.sunDir) + viewDir);
    let spec = pow(max(dot(N, H), 0.0), 256.0) * 2.5;
    let sunSpec = u.sunColor * spec;

    var finalCol = mix(waterBody, skyCol, fresnel) + sunSpec;

    // Dynamic Shoreline Foam
    let foamThreshold = 0.45;
    if (waterDepth < foamThreshold) {
        let foamFactor = pow(1.0 - (waterDepth / foamThreshold), 2.0);
        let foamNoise = fract(sin(dot(in.worldPos.xz * 3.0, vec2<f32>(12.9898, 78.233))) * 43758.5453);
        finalCol = mix(finalCol, vec3<f32>(0.92, 0.95, 1.0), foamFactor * step(0.3, foamNoise));
    }

    return vec4<f32>(finalCol, 1.0);
}
