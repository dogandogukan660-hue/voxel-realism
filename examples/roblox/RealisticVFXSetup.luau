--!strict
-- RealisticVFXSetup.luau
-- Production cinematic particle & atmospheric setup for Roblox Studio
-- Covers: Multi-layered Photorealistic Fire, Volumetric Smoke, Physical Sparks, and Realistic Water params.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local RealisticVFXSetup = {}

-- Configure cinematic atmospheric lighting and realistic water
function RealisticVFXSetup.ConfigureAtmosphere()
    -- Realistic Terrain Water
    local terrain = Workspace.Terrain
    terrain.WaterColor = Color3.fromRGB(18, 55, 75)
    terrain.WaterReflectance = 0.85
    terrain.WaterTransparency = 0.88
    terrain.WaterWaveSize = 0.32
    terrain.WaterWaveSpeed = 14

    -- Physical Lighting
    Lighting.Technology = Enum.Technology.Future
    Lighting.GlobalShadows = true
    Lighting.ShadowSoftness = 0.2
    Lighting.Brightness = 2.4
    Lighting.OutdoorAmbient = Color3.fromRGB(70, 75, 85)

    -- Atmosphere
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
    atmosphere.Density = 0.32
    atmosphere.Offset = 0.25
    atmosphere.Color = Color3.fromRGB(190, 205, 220)
    atmosphere.Decay = Color3.fromRGB(105, 115, 130)
    atmosphere.Glare = 0.35
    atmosphere.Haze = 1.2
end

-- Create a multi-layered realistic fire and volumetric smoke emitter
function RealisticVFXSetup.CreateFireAndSmokeEmitter(parent: Instance): Attachment
    local attachment = Instance.new("Attachment")
    attachment.Name = "RealisticCombustionVFX"
    attachment.Parent = parent

    -- Layer 1: Core Flame (Hot, bright, short-lived)
    local flame = Instance.new("ParticleEmitter")
    flame.Name = "FlameCore"
    flame.Rate = 35
    flame.Lifetime = NumberRange.new(0.25, 0.45)
    flame.Speed = NumberRange.new(5, 9)
    flame.SpreadAngle = Vector2.new(12, 12)
    flame.LightEmission = 0.95
    flame.LightInfluence = 0.0
    flame.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 255, 220)), -- 2500K Core
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 140, 25)),  -- 1600K Flame
        ColorSequenceKeypoint.new(1.0, Color3.fromRGB(180, 40, 5)),    -- 1000K Tip
    })
    flame.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 1.2),
        NumberSequenceKeypoint.new(0.5, 2.0),
        NumberSequenceKeypoint.new(1.0, 0.2),
    })
    flame.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.1),
        NumberSequenceKeypoint.new(0.7, 0.2),
        NumberSequenceKeypoint.new(1.0, 1.0),
    })
    flame.Parent = attachment

    -- Layer 2: Volumetric Smoke (Turbulent, absorbing, long-lived)
    local smoke = Instance.new("ParticleEmitter")
    smoke.Name = "VolumetricSmoke"
    smoke.Rate = 22
    smoke.Lifetime = NumberRange.new(3.0, 5.5)
    smoke.Speed = NumberRange.new(2, 4)
    smoke.Drag = 0.8
    smoke.SpreadAngle = Vector2.new(25, 25)
    smoke.LightEmission = 0.0 -- Absorbing, not glowing
    smoke.LightInfluence = 0.9 -- Reacts to sun and world lighting
    smoke.Color = ColorSequence.new(Color3.fromRGB(35, 33, 32))
    smoke.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 1.5),
        NumberSequenceKeypoint.new(0.5, 5.0),
        NumberSequenceKeypoint.new(1.0, 9.0),
    })
    smoke.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.8),
        NumberSequenceKeypoint.new(0.3, 0.25),
        NumberSequenceKeypoint.new(1.0, 1.0),
    })
    smoke.Parent = attachment

    -- Layer 3: Physical Sparks / Embers
    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "Embers"
    sparks.Rate = 18
    sparks.Lifetime = NumberRange.new(1.0, 2.2)
    sparks.Speed = NumberRange.new(8, 16)
    sparks.SpreadAngle = Vector2.new(45, 45)
    sparks.LightEmission = 1.0
    sparks.LightInfluence = 0.0
    sparks.Color = ColorSequence.new(Color3.fromRGB(255, 170, 40))
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0.0, 0.15),
        NumberSequenceKeypoint.new(0.8, 0.12),
        NumberSequenceKeypoint.new(1.0, 0.0),
    })
    sparks.Parent = attachment

    return attachment
end

return RealisticVFXSetup
