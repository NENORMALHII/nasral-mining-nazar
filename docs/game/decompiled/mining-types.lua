-- Script Path: game:GetService("ReplicatedStorage").Modules.Mining.Types
-- Took 0s to decompile.
-- Executor: Delta (1.0.745.1142)

local v1 = require(game.ReplicatedStorage.Lib.Typecheck)
local v2 = v1.strictInterface
local v3 = {
    ["Id"] = v1.integer,
    ["Name"] = v1.string,
    ["DisplayName"] = v1.string,
    ["Lighting"] = v1.strictInterface({
        ["Ambient"] = v1.optional(v1.Color3),
        ["Brightness"] = v1.number,
        ["ColorShift_Bottom"] = v1.optional(v1.Color3),
        ["ColorShift_Top"] = v1.optional(v1.Color3),
        ["OutdoorAmbient"] = v1.optional(v1.Color3),
        ["ClockTime"] = v1.optional(v1.number),
        ["FogColor"] = v1.optional(v1.Color3),
        ["FogStart"] = v1.optional(v1.number),
        ["FogEnd"] = v1.optional(v1.number),
        ["Sky"] = v1.optional(v1.instanceOf("Sky"))
    }),
    ["GrassColor"] = v1.Color3,
    ["GrassMaterial"] = v1.optional(v1.enum(Enum.Material)),
    ["SnowyLeavesEnabled"] = v1.optional(v1.boolean),
    ["Soundtrack"] = v1.table,
    ["Mine"] = v1.table,
    ["PrimarySpawnLocations"] = v1.array(v1.instanceOf("SpawnLocation")),
    ["ComputeTeleportSpawnLocation"] = v1.callback,
    ["ComputeFog"] = v1.callback
}
return {
    ["IWorld"] = v2(v3)
}
