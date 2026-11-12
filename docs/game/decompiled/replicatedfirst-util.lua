-- Script Path: game:GetService("ReplicatedFirst").Util
-- Took 0.02s to decompile.
-- Executor: Lynx (0.747)

local t = {}
t.MineralIcons = {
    Coal = 203341191,
    Dirt = 203364153,
    Stone = 203364199,
    ["Copper Ore"] = 203364231,
    ["Iron Ore"] = 203364248,
    Hellstone = 203364297,
    Emerald = 203364337,
    Ruby = 203364344,
    Sapphire = 203364359,
    ["Gold Ore"] = 203364395,
    Amethyst = 203364442,
    Diamond = 203364472,
    ["Silver Ore"] = 203367648,
    ["Gold Bar"] = 203958913,
    ["Silver Bar"] = 203958917,
    ["Iron Bar"] = 203958922,
    ["Copper Bar"] = 203958926,
    Quartz = 319588818,
    ["Slime Block"] = 365215797,
    Sulfur = 215782652,
    ["Uranium Ore"] = 215782583,
    ["Uranium Bar"] = 215792412,
    ["Promethium Ore"] = 215782766,
    ["Promethium Bar"] = 215792443,
    Ignis = 215782846,
    Obsidian = 234499684,
    ["Mithril Ore"] = 215782508,
    ["Mithril Bar"] = 215792341,
    ["Malachite Ore"] = 15171543476,
    ["Malachite Bar"] = 15171545011,
    ["Azurite Ore"] = 15171544265,
    ["Azurite Bar"] = 15171545583,
    Sanctite = 84398715552449,
    ["Oak Log"] = 215746667,
    ["Oak Plank"] = 215758794,
    ["Oak Stick"] = 215764494,
    ["Birch Log"] = 215746753,
    ["Birch Plank"] = 215758834,
    ["Birch Stick"] = 215764512,
    ["Ash Log"] = 215746904,
    ["Ash Plank"] = 215758840,
    ["Ash Stick"] = 215764539,
    ["Pine Log"] = 215746939,
    ["Pine Plank"] = 215758860,
    ["Pine Stick"] = 215764579,
    ["Silverwood Log"] = 215746977,
    ["Silverwood Plank"] = 215758884,
    ["Silverwood Stick"] = 215764604,
    ["Goldbranch Log"] = 262289689,
    ["Goldbranch Plank"] = 262289688,
    ["Goldbranch Stick"] = 262289686,
    ["Cinderbark Log"] = 262289681,
    ["Cinderbark Plank"] = 262289683,
    ["Cinderbark Stick"] = 262289694,
    ["Witchwood Log"] = 15146802904,
    ["Witchwood Plank"] = 15146803696,
    ["Witchwood Stick"] = 15146804284,
    ["Giant Mushroom Log"] = 136338756186320,
    ["Giant Mushroom Plank"] = 78242064773550,
    ["Giant Mushroom Stick"] = 108548039054783,
    Log = 215746667,
    Plank = 215758794,
    ["Oil Barrel"] = 234473733,
    ["Lava Barrel"] = 234473767,
    Oil = 234473733,
    Lava = 234473767
}
t.ResourceOrder = {
    "Red Shroom",
    "Brown Shroom",
    "Witchcap",
    "Magmaspore",
    "Soul Shroom",
    "Cursed Key",
    "Soul Shard",
    "Empty Barrel",
    "Oil Barrel",
    "Lava Barrel",
    "Oil",
    "Lava",
    "Dirt",
    "Coal",
    "Copper Ore",
    "Copper Bar",
    "Stone",
    "Sulfur",
    "Iron Ore",
    "Iron Bar",
    "Silver Ore",
    "Silver Bar",
    "Emerald",
    "Ruby",
    "Sapphire",
    "Gold Ore",
    "Gold Bar",
    "Amethyst",
    "Quartz",
    "Diamond",
    "Obsidian",
    "Hellstone",
    "Ignis",
    "Promethium Ore",
    "Promethium Bar",
    "Mithril Ore",
    "Mithril Bar",
    "Slime Block",
    "Sanctite",
    "Malachite Ore",
    "Malachite Bar",
    "Azurite Ore",
    "Azurite Bar",
    "Oak",
    "Oak Log",
    "Oak Plank",
    "Oak Stick",
    "Ash",
    "Ash Log",
    "Ash Plank",
    "Ash Stick",
    "Pine",
    "Pine Log",
    "Pine Plank",
    "Pine Stick",
    "Birch",
    "Birch Log",
    "Birch Plank",
    "Birch Stick",
    "Cinderbark",
    "Cinderbark Log",
    "Cinderbark Plank",
    "Cinderbark Stick",
    "Silverwood",
    "Silverwood Log",
    "Silverwood Plank",
    "Silverwood Stick",
    "Goldbranch",
    "Goldbranch Log",
    "Goldbranch Plank",
    "Goldbranch Stick",
    "Witchwood",
    "Witchwood Log",
    "Witchwood Plank",
    "Witchwood Stick",
    "Giant Mushroom",
    "Giant Mushroom Log",
    "Giant Mushroom Plank",
    "Giant Mushroom Stick"
}
t.ResourceToIndexMap = {}

for key, val in ipairs(t.ResourceOrder) do
    t.ResourceToIndexMap[val] = key
end

function t.GetResourceIndex(t1: table, s1: string) -- line: 100
    if t1.ResourceToIndexMap[s1] ~= nil then
        return t1.ResourceToIndexMap[s1]
    end

    return 0
end

t.DeveloperProducts = {
    ThirdProductionBar = 22464584,
    FourthProductionBar = 22465273,
    SawmillThirdProductionBar = 22760866,
    SawmillFourthProductionBar = 22760879
}
t.POSITIONS = {
    FRONT = Vector3.new(1, 0, 0),
    BACK = Vector3.new(-1, 0, 0),
    LEFT = Vector3.new(0, 0, 1),
    RIGHT = Vector3.new(0, 0, -1),
    UP = Vector3.new(0, -1, 0),
    DOWN = Vector3.new(0, 1, 0)
}
t.BASEPLATE_ALTITUDE = 7998.5

function t.GetSurfaceGuiVerticalOffset(_, arg2) -- line: 120
    return arg2 * -8E-05
end

function t.GetMineralIcon(_, arg4) -- line: 124
    -- upvalues:
    --  [1] t (copy)

    if t.MineralIcons[arg4] then
        return "http://www.roblox.com/asset/?id=" .. t.MineralIcons[arg4]
    end

    return ""
end

function t.PreloadAssets(_, arg6) -- line: 133
    local ContentProvider = game:GetService("ContentProvider")

    for _, val_1 in pairs(arg6) do
        ContentProvider:Preload("http://www.roblox.com/asset/?id=" .. val_1)
    end
end

function t.startsWith(_, arg8, arg9) -- line: 141
    return if string.sub(arg8, 1, #arg9) ~= arg9 then false else true
end

function t.split(_, arg11, arg12) -- line: 145
    local t_3 = {}
    local v3 = "(.-)" .. arg12
    local v4 = 1
    local v5, v6, v7 = arg11:find(v3, 1)

    while v5 do
        if v5 ~= 1 or v7 ~= "" then
            table.insert(t_3, v7)
        end

        v4 = v6 + 1
        local v8, v9, v10 = arg11:find(v3, v4)
        v5 = v8
        v6 = v9
        v7 = v10
    end

    if v4 <= #arg11 then
        table.insert(t_3, (arg11:sub(v4)))
    end

    return t_3
end

function t.vec3_tostring(_, arg14) -- line: 164
    if not arg14 then
        return ""
    end

    return arg14.x .. "," .. arg14.y .. "," .. arg14.z
end

function t.vec3_parse(_, arg16) -- line: 169
    -- upvalues:
    --  [1] t (copy)

    local v12 = t:split(arg16, ",")
    local num = tonumber(v12[1])
    local num_1 = tonumber(v12[2])
    local num_2 = tonumber(v12[3])

    return (Vector3.new(num, num_1, num_2))
end

function t.GetChargeCFrame(_, arg18, arg19) -- line: 175
    if arg19 == Enum.NormalId.Top then
        return arg18 + Vector3.new(0, 3.8, 0)
    end

    if arg19 == Enum.NormalId.Bottom then
        return (arg18 + Vector3.new(0, -3.8, 0)) * CFrame.fromEulerAnglesXYZ(
            3.141592653589793,
            0,
            0
        )
    end

    if arg19 == Enum.NormalId.Front then
        return (arg18 + Vector3.new(0, 0, -3.8)) * CFrame.fromEulerAnglesXYZ(
            -1.5707963267948966,
            1.5707963267948966,
            0
        )
    end

    if arg19 == Enum.NormalId.Back then
        return (arg18 + Vector3.new(0, 0, 3.8)) * CFrame.fromEulerAnglesXYZ(
            1.5707963267948966,
            -1.5707963267948966,
            0
        )
    end

    if arg19 == Enum.NormalId.Left then
        return (arg18 + Vector3.new(-3.8, 0, 0)) * CFrame.fromEulerAnglesXYZ(
            3.141592653589793,
            0,
            1.5707963267948966
        )
    end

    if arg19 == Enum.NormalId.Right then
        return (arg18 + Vector3.new(3.8, 0, 0)) * CFrame.fromEulerAnglesXYZ(
            0,
            0,
            -1.5707963267948966
        )
    end

    return arg18
end

function t.GetBlockCoords(arg20, arg21, arg22, arg23) -- line: 192
    local floorValue = math.floor((arg21 - 61.5) / 7 + 0.5)
    local v18 = -math.floor((arg22 - arg20.BASEPLATE_ALTITUDE) / 7 + 0.5)
    local floorValue_2 = math.floor((arg23 + 56.5) / 7 + 0.5)

    return (Vector3.new(floorValue, v18, floorValue_2))
end

function t.GetWorldCoords(arg24, arg25, arg26, arg27) -- line: 199
    return (Vector3.new(61.5 + 7 * arg25, arg24.BASEPLATE_ALTITUDE - 7 * arg26, -56.5 + 7 * arg27))
end

function t.table_shallow_copy(_, arg29) -- line: 206
    local t_4 = {}

    for key_2, val_2 in pairs(arg29) do
        t_4[key_2] = val_2
    end

    return t_4
end

function t.table_deep_copy(_, arg31) -- line: 216
    -- upvalues:
    --  [1] t (copy)

    local t_5 = {}

    for key_3, val_3 in pairs(arg31) do
        if type(val_3) == "table" then
            t_5[key_3] = t:table_deep_copy(val_3)
        else
            t_5[key_3] = val_3
        end
    end

    return t_5
end

function t.printTable(_, arg33, arg34) -- line: 228
    -- upvalues:
    --  [1] t (copy)

    arg34 = arg34 or 0

    for key_4, val_4 in pairs(arg33) do
        if type(val_4) == "table" then
            print(string.rep("     ", arg34) .. key_4 .. ": ")
            t:printTable(val_4, arg34 + 1)
        else
            print(string.rep("     ", arg34) .. key_4 .. ": " .. tostring(val_4))
        end
    end
end

function t.printTable2(_, arg36, arg37) -- line: 241
    -- upvalues:
    --  [1] t (copy)

    arg37 = arg37 or 0

    for key_5, val_5 in pairs(arg36) do
        if type(val_5) == "table" then
            print(string.rep("     ", arg37) .. key_5 .. " [" .. tostring(val_5) .. "]: ")
            t:printTable2(val_5, arg37 + 1)
        else
            print(string.rep("     ", arg37) .. key_5 .. ": " .. tostring(val_5))
        end
    end
end

function t.IsPlayerWithinRange(_: table, u1: userdata, arg38: any, n1: number) -- line: 253
    local v24 = if typeof(arg38) == "Instance" then arg38:IsA("BasePart") or (if typeof(arg38) ~= "Vector3" then false else true) else if typeof(
        arg38
    ) ~= "Vector3" then false else true
    assert(
        v24,
        "Target must be a BasePart or Vector3, but was a " .. (if typeof(arg38) == "Instance" then arg38.ClassName else typeof(
            arg38
        )) .. " for " .. u1.Name
    )

    if u1.Character == nil then
        return false
    end

    if typeof(arg38) == "Instance" then
        arg38 = arg38.Position
    end

    local HumanoidRootPart = u1.Character:FindFirstChild("HumanoidRootPart")

    if HumanoidRootPart ~= nil then
        return n1 >= (HumanoidRootPart.Position - arg38).Magnitude
    end

    return false
end

function t.PlayerToString(_: table, u2: userdata) -- line: 273
    if u2 == nil then
        return "nil"
    end

    return string.format("%s (%d)", u2.Name, u2.UserId)
end

function t.IsLumberResource(_: table, s2: string) -- line: 279
    if s2 == nil or type(s2) ~= "string" then
        return false
    end

    return string.match(s2, " Log$") ~= nil or string.match(s2, " Plank$") ~= nil or string.match(
        s2,
        " Stick$"
    ) ~= nil
end

function t.IsFilledBarrelResource(_: table, s3: string) -- line: 289
    if s3 == nil or type(s3) ~= "string" then
        return false
    end

    return if s3 == "Empty Barrel" then false else string.match(s3, " Barrel$") ~= nil
end

return t
