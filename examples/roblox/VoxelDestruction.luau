--!strict
-- VoxelDestruction.luau
-- Real-time localized voxel carving & physical debris spawner for Roblox Studio.

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local VoxelDestruction = {}
VoxelDestruction.__index = VoxelDestruction

export type DestructionConfig = {
    Radius: number,
    VoxelDebrisSize: number,
    MaxDebrisCount: number,
    DebrisLifetime: number,
    ImpulseForce: number,
}

local DEFAULT_CONFIG: DestructionConfig = {
    Radius = 6.0,
    VoxelDebrisSize = 1.0,
    MaxDebrisCount = 28,
    DebrisLifetime = 6.0,
    ImpulseForce = 45.0,
}

-- Carve spherical crater in Roblox Terrain and spawn physical voxel debris cubes
function VoxelDestruction.Explode(center: Vector3, config: DestructionConfig?)
    local cfg = config or DEFAULT_CONFIG
    local terrain = Workspace.Terrain

    -- 1. Carve terrain voxels
    terrain:FillBall(center, cfg.Radius, Enum.Material.Air)

    -- 2. Spawn physical micro-voxel fragments
    local debrisFolder = Workspace:FindFirstChild("VoxelDebris")
    if not debrisFolder then
        debrisFolder = Instance.new("Folder")
        debrisFolder.Name = "VoxelDebris"
        debrisFolder.Parent = Workspace
    end

    local count = math.min(cfg.MaxDebrisCount, 40)
    for i = 1, count do
        local offset = Vector3.new(
            math.random() * 2 - 1,
            math.random() * 2 - 1,
            math.random() * 2 - 1
        ).Unit * (math.random() * (cfg.Radius * 0.75))

        local spawnPos = center + offset

        local cube = Instance.new("Part")
        cube.Size = Vector3.new(cfg.VoxelDebrisSize, cfg.VoxelDebrisSize, cfg.VoxelDebrisSize)
        cube.Position = spawnPos
        cube.Material = Enum.Material.Concrete
        cube.Color = Color3.fromRGB(120, 115, 110)
        cube.CanCollide = true
        cube.CastShadow = true
        cube.Parent = debrisFolder

        -- Physical outward velocity impulse
        local dir = (spawnPos - center).Unit + Vector3.new(0, 0.4, 0)
        local force = dir.Unit * (cfg.ImpulseForce * (0.6 + math.random() * 0.8))
        cube.AssemblyLinearVelocity = force
        cube.AssemblyAngularVelocity = Vector3.new(
            math.random(-15, 15),
            math.random(-15, 15),
            math.random(-15, 15)
        )

        Debris:AddItem(cube, cfg.DebrisLifetime + math.random() * 2)
    end
end

return VoxelDestruction
