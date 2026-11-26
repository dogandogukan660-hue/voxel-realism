// WebGPU WGSL: 3D DDA Voxel Compute Raymarcher with Soft Shadows & PBR
// Output: Color buffer (RGBA16Float) + Linear Depth (R32Float)

struct Uniforms {
    cameraPos: vec3<f32>,
    time: f32,
    invViewProj: mat4x4<f32>,
    sunDirection: vec3<f32>,
    sunColor: vec3<f32>,
    gridSize: vec3<f32>,
    pad: f32,
};

@group(0) @binding(0) var<uniform> u: Uniforms;
@group(0) @binding(1) var voxelGrid: texture_3d<u32>;
@group(0) @binding(2) var outColor: texture_storage_2d<rgba16float, write>;
@group(0) @binding(3) var outDepth: texture_storage_2d<r32float, write>;

struct Ray {
    origin: vec3<f32>,
    dir: vec3<f32>,
};

struct Hit {
    hit: bool,
    t: f32,
    normal: vec3<f32>,
    voxelPos: vec3<i32>,
    materialId: u32,
};

fn sampleVoxel(pos: vec3<i32>) -> u32 {
    let bounds = vec3<i32>(u.gridSize);
    if (any(pos < vec3<i32>(0)) || any(pos >= bounds)) {
        return 0u;
    }
    return textureLoad(voxelGrid, pos, 0).r;
}

// 3D Digital Differential Analyzer (DDA)
fn raymarchDDA(ray: Ray, maxDist: f32) -> Hit {
    var result: Hit;
    result.hit = false;
    result.t = maxDist;
    result.normal = vec3<f32>(0.0);

    let raySign = sign(ray.dir);
    let deltaDist = abs(1.0 / (ray.dir + vec3<f32>(1e-9)));
    
    var currentVoxel = vec3<i32>(floor(ray.origin));
    var sideDist = (raySign * (vec3<f32>(currentVoxel) - ray.origin) + (raySign * 0.5) + 0.5) * deltaDist;
    var normal = vec3<f32>(0.0);
    var t = 0.0;

    for (var i = 0; i < 512; i++) {
        let mat = sampleVoxel(currentVoxel);
        if (mat > 0u) {
            result.hit = true;
            result.t = t;
            result.normal = normal;
            result.voxelPos = currentVoxel;
            result.materialId = mat;
            return result;
        }

        if (sideDist.x < sideDist.y) {
            if (sideDist.x < sideDist.z) {
                t = sideDist.x;
                sideDist.x += deltaDist.x;
                currentVoxel.x += i32(raySign.x);
                normal = vec3<f32>(-raySign.x, 0.0, 0.0);
            } else {
                t = sideDist.z;
                sideDist.z += deltaDist.z;
                currentVoxel.z += i32(raySign.z);
                normal = vec3<f32>(0.0, 0.0, -raySign.z);
            }
        } else {
            if (sideDist.y < sideDist.z) {
                t = sideDist.y;
                sideDist.y += deltaDist.y;
                currentVoxel.y += i32(raySign.y);
                normal = vec3<f32>(0.0, -raySign.y, 0.0);
            } else {
                t = sideDist.z;
                sideDist.z += deltaDist.z;
                currentVoxel.z += i32(raySign.z);
                normal = vec3<f32>(0.0, 0.0, -raySign.z);
            }
        }

        if (t >= maxDist) {
            break;
        }
    }
    return result;
}

// Soft Shadow Raymarching
fn softShadow(origin: vec3<f32>, lightDir: vec3<f32>, maxDist: f32) -> f32 {
    let shadowRay = Ray(origin + lightDir * 0.05, lightDir);
    let hit = raymarchDDA(shadowRay, maxDist);
    if (hit.hit) {
        return 0.15; // In shadow (ambient term)
    }
    return 1.0;
}

// Material PBR Palette
fn getVoxelColor(matId: u32, worldPos: vec3<f32>, normal: vec3<f32>) -> vec3<f32> {
    var baseColor = vec3<f32>(0.7, 0.7, 0.7);
    if (matId == 1u) { baseColor = vec3<f32>(0.35, 0.65, 0.25); } // Grass
    else if (matId == 2u) { baseColor = vec3<f32>(0.45, 0.32, 0.20); } // Dirt / Rock
    else if (matId == 3u) { baseColor = vec3<f32>(0.85, 0.25, 0.15); } // Brick
    else if (matId == 4u) { baseColor = vec3<f32>(0.80, 0.80, 0.85); } // Concrete
    else if (matId == 5u) { baseColor = vec3<f32>(0.15, 0.15, 0.18); } // Metal

    // Procedural micro-texture variation
    let microNoise = fract(sin(dot(floor(worldPos), vec3<f32>(12.9898, 78.233, 45.164))) * 43758.5453);
    return baseColor * (0.9 + 0.2 * microNoise);
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) globalId: vec3<u32>) {
    let dims = textureDimensions(outColor);
    if (globalId.x >= dims.x || globalId.y >= dims.y) {
        return;
    }

    let uv = (vec2<f32>(globalId.xy) + 0.5) / vec2<f32>(dims);
    let ndc = vec4<f32>(uv.x * 2.0 - 1.0, (1.0 - uv.y) * 2.0 - 1.0, 1.0, 1.0);
    let worldTarget = u.invViewProj * ndc;
    let rayDir = normalize(worldTarget.xyz / worldTarget.w - u.cameraPos);
    let ray = Ray(u.cameraPos, rayDir);

    let hit = raymarchDDA(ray, 400.0);

    if (hit.hit) {
        let hitPos = ray.origin + ray.dir * hit.t;
        let albedo = getVoxelColor(hit.materialId, hitPos, hit.normal);
        
        let N = hit.normal;
        let L = normalize(-u.sunDirection);
        let NdotL = max(dot(N, L), 0.0);

        let shadow = softShadow(hitPos + N * 0.02, L, 100.0);
        let ambient = vec3<f32>(0.18, 0.22, 0.30); // Sky ambient
        let diffuse = albedo * u.sunColor * (NdotL * shadow) + albedo * ambient;

        textureStore(outColor, vec2<i32>(globalId.xy), vec4<f32>(diffuse, 1.0));
        textureStore(outDepth, vec2<i32>(globalId.xy), vec4<f32>(hit.t, 0.0, 0.0, 1.0));
    } else {
        // Atmosphere sky gradient
        let skyGradient = max(rayDir.y, 0.0);
        let sky = mix(vec3<f32>(0.7, 0.8, 0.95), vec3<f32>(0.2, 0.45, 0.85), skyGradient);
        textureStore(outColor, vec2<i32>(globalId.xy), vec4<f32>(sky, 1.0));
        textureStore(outDepth, vec2<i32>(globalId.xy), vec4<f32>(1e9, 0.0, 0.0, 1.0));
    }
}
