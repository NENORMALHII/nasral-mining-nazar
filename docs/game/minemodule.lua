-- Script Path: game:GetService("ReplicatedStorage").Modules.Mining.Mine
-- Took 0s to decompile.
-- Executor: Lynx (0.747)

local _ = game:GetService("CollectionService")
local _ = require(game.ReplicatedStorage.Modules.Constants)
local t = {
    EventType = { MINE_START = 0, MINE_COMPLETE = 1, MINE_STOP = 2 },
    BLOCK_SIZE = 7,
    LIQUID_BLOCK_HEIGHT = 5,
    BASE_MINE_HEIGHT = -16,
    MINE_WORLDSPACE_OFFSET = Vector3.new(-31, -16, -98.5),
    MAX_MINING_RANGE = 30,
    ATTRIBUTE_RESOURCE_ID = "Resource",
    ATTRIBUTE_MINE_POSITION = "MinePosition",
    OFFSETS = {
        LEFT = Vector3.new(-1, 0, 0),
        RIGHT = Vector3.new(1, 0, 0),
        UP = Vector3.new(0, -1, 0),
        DOWN = Vector3.new(0, 1, 0),
        FRONT = Vector3.new(0, 0, 1),
        BACK = Vector3.new(0, 0, -1)
    },
    GetWorld = function(arg1) --[[ GetWorld ]] -- line: 36
        return arg1._world
    end,
    ConvertBlockPosToWorld = function(t1: table, vec1: Vector3) --[[ ConvertBlockPosToWorld ]] -- line: 40
        return vec1 * t1.BLOCK_SIZE * Vector3.new(1, -1, 1) + t1._world.Mine.WorldspaceOffset
    end,
    ConvertWorldPosToBlock = function(t2: table, vec2: Vector3) --[[ ConvertWorldPosToBlock ]] -- line: 44
        local v1 = (vec2 - t2._world.Mine.WorldspaceOffset) / t2.BLOCK_SIZE * Vector3.new(1, -1, 1)
        local floorValue = math.floor(v1.X + 0.5)
        local floorValue_1 = math.floor(v1.Y + 0.5)
        local floorValue_2 = math.floor(v1.Z + 0.5)

        return (Vector3.new(floorValue, floorValue_1, floorValue_2))
    end,
    GetResourceFromBlock = function(_: table, _: userdata) --[[ GetResourceFromBlock ]] -- line: 49
    end
}

function t.GetResource(_: table, vec3: Vector3) -- line: 54
    -- upvalues:
    --  [1] t (copy)

    return t:GetResourceFromBlock(t:GetBlock(vec3))
end

function t.IsBlockBesideLiquid(t5: table, vec4: Vector3) -- line: 58
    for _, val in pairs(t5.OFFSETS) do
        if val.Y ~= 1 then
            local v4 = t5:GetResource(vec4 + val)

            if v4 and v4.Liquid then
                return true, v4
            end
        end
    end

    return false, nil
end

return t
