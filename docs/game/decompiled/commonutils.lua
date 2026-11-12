-- Script Path: game:GetService("ReplicatedStorage").Modules.CommonUtils
-- Took 0.01s to decompile.
-- Executor: Lynx (0.747)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollisionGroups_m = require(game.ReplicatedStorage.Modules.CollisionGroups)
local Constants_m = require(game.ReplicatedStorage.Modules.Constants)
local TextUtils_m = require(game.ReplicatedStorage.Modules.TextUtils)
local t = {
    CopyTable = function(_: table, u1: userdata) --[[ CopyTable ]] -- line: 12
        assert(if typeof(u1) ~= "table" then false else true, "Expected table, got " .. typeof(u1))
        local t_1 = {}

        for key, val in pairs(u1) do
            t_1[key] = val
        end

        return t_1
    end,
    CreateValue = function(
        _: table,
        s1: string,
        s2: string,
        u2: userdata,
        arg1: any
    ) --[[ CreateValue ]] -- line: 23
        local v2 = Instance.new(s1)
        v2.Name = s2
        v2.Parent = u2

        if arg1 then
            v2.Value = arg1
        end

        return v2
    end,
    IsPrivateServer = function(_) --[[ IsPrivateServer ]] -- line: 36
        -- upvalues:
        --  [1] RunService (copy)

        local PrivateServerOwnerId = workspace:GetAttribute("PrivateServerOwnerId")

        return if PrivateServerOwnerId ~= nil then if PrivateServerOwnerId == 0 then RunService:IsStudio() else true else RunService:IsStudio()
    end,
    ToColor3 = function(_, arg4) --[[ ToColor3 ]] -- line: 42
        if typeof(arg4) == "BrickColor" then
            return arg4.Color
        end

        return arg4
    end,
    SetModelCollisionGroup = function(_: table, u3: userdata, s3: string) --[[ SetModelCollisionGroup ]] -- line: 50
        if u3:IsA("BasePart") then
            u3.CollisionGroup = s3
        end

        for _, descendant in pairs(u3:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.CollisionGroup = s3
            end
        end
    end,
    IsPlayerWithinRange = function(_: table, u4: userdata, arg5: any, n1: number) --[[ IsPlayerWithinRange ]] -- line: 62
        local v5 = if typeof(arg5) == "Instance" then arg5:IsA("BasePart") or (if typeof(arg5) ~= "Vector3" then false else true) else if typeof(
            arg5
        ) ~= "Vector3" then false else true
        assert(v5, "Target must be a BasePart or Vector3")

        if u4.Character == nil then
            return false
        end

        if arg5 == nil then
            warn("Called IsPlayerWithinRange with nil target")

            return false
        end

        if typeof(arg5) == "Instance" then
            arg5 = arg5.Position
        end

        local HumanoidRootPart = u4.Character:FindFirstChild("HumanoidRootPart")

        if HumanoidRootPart ~= nil then
            return n1 >= (HumanoidRootPart.Position - arg5).Magnitude
        end

        return false
    end
}

function t.GetPlayersWithinRange(_: table, arg6: any, n2: number) -- line: 87
    -- upvalues:
    --  [1] Players (copy)
    --  [2] t (copy)

    local t_2 = {}

    for _, val_1 in Players:GetPlayers() do
        if t:IsPlayerWithinRange(val_1, arg6, n2) then
            table.insert(t_2, val_1)
        end
    end

    return t_2
end

function t.IsInRange(_: table, vec1: Vector3, vec2: Vector3, n3: number) -- line: 99
    return n3 >= (vec1 - vec2).Magnitude
end

function t.RaycastFromViewportPoint(t7: table, u5: Vector2, n4: number, u6: userdata?) -- line: 104
    return t7:Raycast(workspace.CurrentCamera:ViewportPointToRay(u5.X, u5.Y), n4, u6)
end

function t.RaycastFromScreenPoint(t8: table, u7: Vector2, n5: number, u8: userdata?) -- line: 108
    return t8:Raycast(workspace.CurrentCamera:ScreenPointToRay(u7.X, u7.Y), n5, u8)
end

local raycastParams = RaycastParams.new()
raycastParams.CollisionGroup = CollisionGroups_m.RAYCAST

function t.Raycast(_: table, u9: Ray, n6: number, u10: userdata?) -- line: 115
    -- upvalues:
    --  [1] raycastParams (copy)

    assert(if typeof(u9) ~= "Ray" then false else true, "Expected Ray, received " .. typeof(Ray))
    assert(if typeof(n6) ~= "number" then false else true, "Distance must be a number")
    local v9 = u9.Direction * n6
    local v10 = u10
    local v11 = workspace
    local Origin = u9.Origin

    if not v10 then
        v10 = raycastParams
    end

    local raycastResult = v11:Raycast(Origin, v9, v10)

    if raycastResult ~= nil then
        return raycastResult.Instance, raycastResult.Normal
    end

    return nil
end

function t.FormatTime(_: table, n7: number) -- line: 128
    local floorValue = math.floor(n7 / 60)

    return ("%2d:%02d"):format(floorValue, n7 - floorValue * 60)
end

function t.FormatTimeLong(_: table, n8: number, b1: boolean?) -- line: 134
    -- upvalues:
    --  [1] TextUtils_m (copy)

    local floorValue_1 = math.floor(n8 / 86400)
    local v13 = n8 - floorValue_1 * 86400
    local floorValue_2 = math.floor(v13 / 3600)
    v13 -= floorValue_2 * 3600
    local floorValue_3 = math.floor(v13 / 60)
    v13 -= floorValue_3 * 60

    if b1 then
        return ("%2d %s %2d %s %2d %s"):format(
            floorValue_1,
            TextUtils_m:Plural("day", floorValue_1),
            floorValue_2,
            TextUtils_m:Plural("hour", floorValue_2),
            floorValue_3,
            TextUtils_m:Plural("minute", floorValue_3)
        )
    end

    return ("%2d %s %2d %s %2d %s %2d %s"):format(
        floorValue_1,
        TextUtils_m:Plural("day", floorValue_1),
        floorValue_2,
        TextUtils_m:Plural("hour", floorValue_2),
        floorValue_3,
        TextUtils_m:Plural("minute", floorValue_3),
        v13,
        TextUtils_m:Plural("second", v13)
    )
end

function t.FormatWithOrdinalSuffix(_: table, n9: number) -- line: 158
    local v19 = n9 % 100

    if v19 >= 10 and v19 <= 19 then
        return n9 .. "th"
    end

    local v20 = n9 % 10

    if v20 == 1 then
        return n9 .. "st"
    end

    if v20 == 2 then
        return n9 .. "nd"
    end

    if v20 == 3 then
        return n9 .. "rd"
    end

    return n9 .. "th"
end

function t.DeepCopyTable(_: table, t14: table) -- line: 176
    -- upvalues:
    --  [1] t (copy)

    local t_3 = {}

    for key_3, val_2 in pairs(t14) do
        if typeof(val_2) == "table" then
            t_3[key_3] = t:DeepCopyTable(val_2)
        else
            t_3[key_3] = val_2
        end
    end

    return t_3
end

function t.IsDevPlace(_) -- line: 191
    -- upvalues:
    --  [1] Constants_m (copy)

    return game.PlaceId == Constants_m.PLACE_ID_STAGING or game.PlaceId == Constants_m.PLACE_ID_TESTING
end

function t.JSONPrettify(_: table, s4: string) -- line: 195
    local v22 = ""
    local v23 = 0

    local _ = function() --[[ startNewLine ]] -- line: 200
        -- upvalues:
        --  [1] v22 (ref)
        --  [2] v23 (ref)

        v22 ..= "\n"
        v22 = v22 .. string.rep(" ", v23 * 2)
    end

    for index = 1, #s4 do
        local v25 = s4:sub(index, index)

        if v25 == "{" or v25 == "[" then
            v22 ..= v25
            v23 += 1
            v22 ..= "\n"
            v22 ..= string.rep(" ", v23 * 2)
        elseif v25 == "}" or v25 == "]" then
            v23 -= 1
            v22 ..= "\n"
            v22 ..= string.rep(" ", v23 * 2)
            v22 ..= v25
        elseif v25 == ":" then
            v22 ..= ": "
        elseif v25 == "," then
            v22 ..= ","
            v22 ..= "\n"
            v22 ..= string.rep(" ", v23 * 2)
        else
            v22 ..= v25
        end
    end

    return v22
end

function t.CalculateNextStorageUpdateCost(_: table, n10: number) -- line: 230
    -- upvalues:
    --  [1] Constants_m (copy)

    return 50 * (n10 // Constants_m.STORAGE_UPGRADE_NUM_SLOTS - 1) + 500
end

return (table.freeze(t))
