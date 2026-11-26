// GLSL: 3D DDA Voxel Traversal for OpenGL 4.5+ / Vulkan
#version 450 core

layout(location = 0) in vec2 v_TexCoord;
layout(location = 0) out vec4 out_Color;

layout(binding = 0) uniform usampler3D u_VoxelTexture;

layout(std140, binding = 1) uniform CameraData {
    mat4 u_InvViewProj;
    vec3 u_CameraPos;
    float u_MaxDist;
    vec3 u_SunDir;
    float u_Time;
};

struct RayHit {
    bool hit;
    float t;
    vec3 normal;
    ivec3 voxelCoord;
    uint material;
};

RayHit traceVoxelDDA(vec3 rayOrigin, vec3 rayDir, float maxDist) {
    RayHit result;
    result.hit = false;
    result.t = maxDist;
    result.normal = vec3(0.0);

    ivec3 currentVoxel = ivec3(floor(rayOrigin));
    vec3 raySign = sign(rayDir);
    vec3 deltaDist = abs(1.0 / (rayDir + vec3(1e-9)));
    vec3 sideDist = (raySign * (vec3(currentVoxel) - rayOrigin) + (raySign * 0.5) + 0.5) * deltaDist;
    vec3 normal = vec3(0.0);
    float t = 0.0;

    ivec3 texSize = textureSize(u_VoxelTexture, 0);

    for (int step = 0; step < 512; ++step) {
        if (all(greaterThanEqual(currentVoxel, ivec3(0))) && all(lessThan(currentVoxel, texSize))) {
            uint mat = texelFetch(u_VoxelTexture, currentVoxel, 0).r;
            if (mat > 0u) {
                result.hit = true;
                result.t = t;
                result.normal = normal;
                result.voxelCoord = currentVoxel;
                result.material = mat;
                return result;
            }
        }

        if (sideDist.x < sideDist.y) {
            if (sideDist.x < sideDist.z) {
                t = sideDist.x;
                sideDist.x += deltaDist.x;
                currentVoxel.x += int(raySign.x);
                normal = vec3(-raySign.x, 0.0, 0.0);
            } else {
                t = sideDist.z;
                sideDist.z += deltaDist.z;
                currentVoxel.z += int(raySign.z);
                normal = vec3(0.0, 0.0, -raySign.z);
            }
        } else {
            if (sideDist.y < sideDist.z) {
                t = sideDist.y;
                sideDist.y += deltaDist.y;
                currentVoxel.y += int(raySign.y);
                normal = vec3(0.0, -raySign.y, 0.0);
            } else {
                t = sideDist.z;
                sideDist.z += deltaDist.z;
                currentVoxel.z += int(raySign.z);
                normal = vec3(0.0, 0.0, -raySign.z);
            }
        }

        if (t >= maxDist) break;
    }

    return result;
}

void main() {
    vec4 ndc = vec4(v_TexCoord * 2.0 - 1.0, 1.0, 1.0);
    vec4 worldTarget = u_InvViewProj * ndc;
    vec3 rayDir = normalize(worldTarget.xyz / worldTarget.w - u_CameraPos);

    RayHit hit = traceVoxelDDA(u_CameraPos, rayDir, u_MaxDist);

    if (hit.hit) {
        vec3 albedo = vec3(0.7);
        if (hit.material == 1u) albedo = vec3(0.2, 0.7, 0.3); // Grass
        else if (hit.material == 2u) albedo = vec3(0.5, 0.35, 0.2); // Dirt
        else if (hit.material == 3u) albedo = vec3(0.8, 0.3, 0.2); // Brick

        vec3 N = hit.normal;
        vec3 L = normalize(-u_SunDir);
        float diff = max(dot(N, L), 0.0);
        vec3 ambient = vec3(0.15, 0.18, 0.25);

        out_Color = vec4(albedo * (diff * vec3(1.0, 0.95, 0.8) + ambient), 1.0);
    } else {
        vec3 sky = mix(vec3(0.7, 0.8, 0.95), vec3(0.2, 0.45, 0.85), max(rayDir.y, 0.0));
        out_Color = vec4(sky, 1.0);
    }
}
