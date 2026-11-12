-- Script Path: game:GetService("ReplicatedStorage").Modules.Resources
-- Took 0.03s to decompile.
-- Executor: Lynx (0.747)

local Typecheck_m = require(game.ReplicatedStorage.Lib.Typecheck)
local t = {
    Natural = Typecheck_m.optional(Typecheck_m.boolean),
    AppearsInShop = Typecheck_m.optional(Typecheck_m.boolean),
    Placeable = Typecheck_m.optional(Typecheck_m.boolean),
    ExtendedPlaceable = Typecheck_m.optional(Typecheck_m.boolean),
    IsAutoSmeltable = Typecheck_m.optional(Typecheck_m.boolean),
    Indestructable = Typecheck_m.optional(Typecheck_m.boolean),
    MineTimeModifier = Typecheck_m.optional(Typecheck_m.number),
    LiquidResource = Typecheck_m.optional(Typecheck_m.boolean),
    MushroomResource = Typecheck_m.optional(Typecheck_m.boolean),
    UtilityResource = Typecheck_m.optional(Typecheck_m.boolean),
    Name = Typecheck_m.string,
    NotPurchasable = Typecheck_m.optional(Typecheck_m.boolean),
    AppearsInLiquidRefinery = Typecheck_m.optional(Typecheck_m.boolean),
    Unobtainable = Typecheck_m.optional(Typecheck_m.boolean),
    BasePrice = Typecheck_m.optional(Typecheck_m.integer),
    Min = Typecheck_m.optional(Typecheck_m.integer),
    Max = Typecheck_m.optional(Typecheck_m.integer),
    Increment = Typecheck_m.optional(Typecheck_m.integer),
    LumberResource = Typecheck_m.optional(Typecheck_m.boolean),
    BaseType = Typecheck_m.optional(Typecheck_m.string),
    SubType = Typecheck_m.optional(Typecheck_m.string),
    Multiplier = Typecheck_m.optional(Typecheck_m.number),
    ChildResources = Typecheck_m.optional(Typecheck_m.table)
}
local v1 = Typecheck_m.strictInterface(t)
local t_1 = {
    Dirt = {
        Natural = true,
        BasePrice = 3,
        Min = 2,
        Max = 4,
        Increment = 1,
        AppearsInShop = true,
        MineTimeModifier = 0.6,
        Placeable = true
    },
    Stone = {
        Natural = true,
        BasePrice = 5,
        Min = 3,
        Max = 6,
        Increment = 2,
        AppearsInShop = true,
        MineTimeModifier = 1.2,
        Placeable = true
    },
    Coal = {
        Natural = true,
        BasePrice = 12,
        Min = 10,
        Max = 16,
        Increment = 3,
        AppearsInShop = true,
        Placeable = true
    }
}
local t_2 = {
    Natural = true,
    BasePrice = 20,
    Min = 17,
    Max = 23,
    Increment = 4,
    ChildResources = { "Copper Bar" },
    AppearsInShop = true,
    MineTimeModifier = 1.2,
    ExtendedPlaceable = true,
    IsAutoSmeltable = true
}
t_1["Copper Ore"] = t_2
t_1["Copper Bar"] = { Multiplier = 1.5, NotPurchasable = true, AppearsInShop = false }
local t_4 = {
    Natural = true,
    BasePrice = 32,
    Min = 27,
    Max = 37,
    Increment = 4,
    ChildResources = { "Iron Bar" },
    AppearsInShop = true,
    MineTimeModifier = 1.5,
    ExtendedPlaceable = true,
    IsAutoSmeltable = true
}
t_1["Iron Ore"] = t_4
t_1["Iron Bar"] = { Multiplier = 1.5, NotPurchasable = true, AppearsInShop = false }
t_1.Sulfur = {
    Natural = true,
    BasePrice = 38,
    Min = 30,
    Max = 70,
    Increment = 5,
    AppearsInShop = true,
    ExtendedPlaceable = true
}
local t_6 = {
    Natural = true,
    BasePrice = 45,
    Min = 34,
    Max = 52,
    Increment = 4,
    ChildResources = { "Silver Bar" },
    AppearsInShop = true,
    MineTimeModifier = 0.9,
    ExtendedPlaceable = true,
    IsAutoSmeltable = true
}
t_1["Silver Ore"] = t_6
t_1["Silver Bar"] = { Multiplier = 1.4, NotPurchasable = true, AppearsInShop = false }
t_1.Emerald = {
    Natural = true,
    BasePrice = 65,
    Min = 55,
    Max = 75,
    Increment = 5,
    AppearsInShop = true,
    ExtendedPlaceable = true
}
t_1.Ruby = {
    Natural = true,
    BasePrice = 85,
    Min = 70,
    Max = 100,
    Increment = 6,
    AppearsInShop = true,
    MineTimeModifier = 1.3,
    ExtendedPlaceable = true
}
t_1.Sapphire = {
    Natural = true,
    BasePrice = 110,
    Min = 95,
    Max = 130,
    Increment = 8,
    AppearsInShop = true,
    MineTimeModifier = 1.4,
    ExtendedPlaceable = true
}
local t_8 = {
    Natural = true,
    BasePrice = 150,
    Min = 130,
    Max = 170,
    Increment = 10,
    ChildResources = { "Gold Bar" },
    AppearsInShop = true,
    MineTimeModifier = 0.9,
    ExtendedPlaceable = true,
    IsAutoSmeltable = true
}
t_1["Gold Ore"] = t_8
t_1["Gold Bar"] = { Multiplier = 1.3, NotPurchasable = true, AppearsInShop = false }
t_1.Amethyst = {
    Natural = true,
    BasePrice = 300,
    Min = 270,
    Max = 322,
    Increment = 20,
    AppearsInShop = true,
    MineTimeModifier = 1.5,
    ExtendedPlaceable = true
}
t_1.Diamond = {
    Natural = true,
    BasePrice = 400,
    Min = 350,
    Max = 450,
    Increment = 25,
    AppearsInShop = true,
    MineTimeModifier = 3,
    NotPurchasable = true,
    ExtendedPlaceable = true
}
t_1.Obsidian = {
    Natural = true,
    BasePrice = 300,
    Min = 250,
    Max = 350,
    Increment = 15,
    AppearsInShop = true,
    MineTimeModifier = 5,
    NotPurchasable = true,
    ExtendedPlaceable = true
}
local t_10 = {
    Natural = true,
    BasePrice = 600,
    Min = 500,
    Max = 700,
    Increment = 15,
    AppearsInShop = false,
    MineTimeModifier = 4,
    NotPurchasable = true,
    ChildResources = { "Mithril Bar" },
    IsAutoSmeltable = true
}
t_1["Mithril Ore"] = t_10
t_1["Mithril Bar"] = { Multiplier = 1.5, NotPurchasable = true, AppearsInShop = false }
local t_12 = {
    Natural = true,
    BasePrice = 300,
    Min = 250,
    Max = 400,
    Increment = 10,
    AppearsInShop = false,
    MineTimeModifier = 4.5,
    NotPurchasable = true,
    ChildResources = { "Promethium Bar" },
    ExtendedPlaceable = true,
    IsAutoSmeltable = true
}
t_1["Promethium Ore"] = t_12
t_1["Promethium Bar"] = { Multiplier = 1.5, NotPurchasable = true, AppearsInShop = false }
t_1.Ignis = {
    Natural = true,
    BasePrice = 90,
    Min = 80,
    Max = 120,
    Increment = 10,
    AppearsInShop = false,
    MineTimeModifier = 1.4,
    NotPurchasable = true,
    ExtendedPlaceable = true
}
t_1.Hellstone = {
    Natural = true,
    BasePrice = 18,
    Min = 10,
    Max = 24,
    Increment = 2,
    AppearsInShop = false,
    MineTimeModifier = 1.8,
    NotPurchasable = true,
    Placeable = true
}
t_1.Bedrock = {
    AppearsInShop = false,
    NotPurchasable = true,
    Placeable = false,
    Unobtainable = true
}
t_1["Soulful Bedrock"] = {
    AppearsInShop = false,
    NotPurchasable = true,
    Placeable = false,
    Unobtainable = true
}
t_1.Grass = {
    Indestructable = true,
    AppearsInShop = false,
    NotPurchasable = true,
    Placeable = false,
    Unobtainable = true
}
t_1.Void = {
    Indestructable = true,
    AppearsInShop = false,
    NotPurchasable = true,
    Placeable = false,
    Unobtainable = true
}
t_1.Cobweb = {
    Indestructable = true,
    AppearsInShop = false,
    NotPurchasable = true,
    Placeable = false,
    Unobtainable = true
}
t_1.Quartz = {
    Natural = true,
    BasePrice = 225,
    Min = 200,
    Max = 300,
    Increment = 10,
    AppearsInShop = true,
    MineTimeModifier = 1.7,
    NotPurchasable = true,
    ExtendedPlaceable = true
}
t_1.Sanctite = {
    Natural = true,
    BasePrice = 20,
    Min = 16,
    Max = 24,
    Increment = 2,
    AppearsInShop = true,
    MineTimeModifier = 2.5,
    NotPurchasable = true,
    Placeable = true
}
local t_14 = {
    Natural = true,
    BasePrice = 450,
    Min = 400,
    Max = 500,
    Increment = 10,
    AppearsInShop = true,
    MineTimeModifier = 2,
    NotPurchasable = true,
    ExtendedPlaceable = true,
    ChildResources = { "Malachite Bar" }
}
t_1["Malachite Ore"] = t_14
t_1["Malachite Bar"] = { Multiplier = 1.5, NotPurchasable = true, AppearsInShop = false }
local t_16 = {
    Natural = true,
    BasePrice = 550,
    Min = 500,
    Max = 600,
    Increment = 10,
    AppearsInShop = true,
    MineTimeModifier = 2,
    NotPurchasable = true,
    ExtendedPlaceable = true,
    ChildResources = { "Azurite Bar" }
}
t_1["Azurite Ore"] = t_16
t_1["Azurite Bar"] = { Multiplier = 1.5, NotPurchasable = true, AppearsInShop = false }
t_1["Slime Block"] = {
    Natural = false,
    BasePrice = 150,
    Min = 120,
    Max = 180,
    Increment = 8,
    AppearsInShop = false,
    MineTimeModifier = 3,
    NotPurchasable = true,
    Placeable = false
}
t_1.Oak = { AppearsInShop = false, Unobtainable = true }
local t_18 = {
    LumberResource = true,
    BaseType = "Oak",
    SubType = "Log",
    BasePrice = 15,
    Min = 10,
    Max = 20,
    Increment = 3,
    ChildResources = { "Oak Plank", "Oak Stick" }
}
t_1["Oak Log"] = t_18
t_1["Oak Plank"] = { LumberResource = true, BaseType = "Oak", SubType = "Plank", Multiplier = 0.6 }
t_1["Oak Stick"] = { LumberResource = true, BaseType = "Oak", SubType = "Stick", Multiplier = 0.4 }
t_1.Ash = { AppearsInShop = false, Unobtainable = true }
local t_20 = {
    LumberResource = true,
    BaseType = "Ash",
    SubType = "Log",
    BasePrice = 20,
    Min = 15,
    Max = 25,
    Increment = 3,
    ChildResources = { "Ash Plank", "Ash Stick" }
}
t_1["Ash Log"] = t_20
t_1["Ash Plank"] = { LumberResource = true, BaseType = "Ash", SubType = "Plank", Multiplier = 0.6 }
t_1["Ash Stick"] = { LumberResource = true, BaseType = "Ash", SubType = "Stick", Multiplier = 0.4 }
t_1.Birch = { AppearsInShop = false, Unobtainable = true }
local t_22 = {
    LumberResource = true,
    BaseType = "Birch",
    SubType = "Log",
    BasePrice = 30,
    Min = 25,
    Max = 35,
    Increment = 3,
    ChildResources = { "Birch Plank", "Birch Stick" }
}
t_1["Birch Log"] = t_22
t_1["Birch Plank"] = {
    LumberResource = true,
    BaseType = "Birch",
    SubType = "Plank",
    Multiplier = 0.6
}
t_1["Birch Stick"] = {
    LumberResource = true,
    BaseType = "Birch",
    SubType = "Stick",
    Multiplier = 0.4
}
t_1.Pine = { AppearsInShop = false, Unobtainable = true }
local t_24 = {
    LumberResource = true,
    BaseType = "Pine",
    SubType = "Log",
    BasePrice = 25,
    Min = 20,
    Max = 30,
    Increment = 3,
    ChildResources = { "Pine Plank", "Pine Stick" }
}
t_1["Pine Log"] = t_24
t_1["Pine Plank"] = {
    LumberResource = true,
    BaseType = "Pine",
    SubType = "Plank",
    Multiplier = 0.6
}
t_1["Pine Stick"] = {
    LumberResource = true,
    BaseType = "Pine",
    SubType = "Stick",
    Multiplier = 0.4
}
t_1.Silverwood = { AppearsInShop = false, Unobtainable = true }
local t_26 = {
    LumberResource = true,
    BaseType = "Silverwood",
    SubType = "Log",
    BasePrice = 100,
    Min = 80,
    Max = 120,
    Increment = 10,
    ChildResources = { "Silverwood Plank", "Silverwood Stick" }
}
t_1["Silverwood Log"] = t_26
t_1["Silverwood Plank"] = {
    LumberResource = true,
    BaseType = "Silverwood",
    SubType = "Plank",
    Multiplier = 0.6
}
t_1["Silverwood Stick"] = {
    LumberResource = true,
    BaseType = "Silverwood",
    SubType = "Stick",
    Multiplier = 0.4
}
t_1.Goldbranch = { AppearsInShop = false, Unobtainable = true }
local t_28 = {
    LumberResource = true,
    BaseType = "Goldbranch",
    SubType = "Log",
    BasePrice = 140,
    Min = 110,
    Max = 160,
    Increment = 10,
    ChildResources = { "Goldbranch Plank", "Goldbranch Stick" }
}
t_1["Goldbranch Log"] = t_28
t_1["Goldbranch Plank"] = {
    LumberResource = true,
    BaseType = "Goldbranch",
    SubType = "Plank",
    Multiplier = 0.6
}
t_1["Goldbranch Stick"] = {
    LumberResource = true,
    BaseType = "Goldbranch",
    SubType = "Stick",
    Multiplier = 0.4
}
t_1.Cinderbark = { AppearsInShop = false, Unobtainable = true }
local t_30 = {
    LumberResource = true,
    BaseType = "Cinderbark",
    SubType = "Log",
    BasePrice = 50,
    Min = 30,
    Max = 65,
    Increment = 5,
    ChildResources = { "Cinderbark Plank", "Cinderbark Stick" }
}
t_1["Cinderbark Log"] = t_30
t_1["Cinderbark Plank"] = {
    LumberResource = true,
    BaseType = "Cinderbark",
    SubType = "Plank",
    Multiplier = 0.6
}
t_1["Cinderbark Stick"] = {
    LumberResource = true,
    BaseType = "Cinderbark",
    SubType = "Stick",
    Multiplier = 0.4
}
t_1.Witchwood = { AppearsInShop = false, Unobtainable = true }
local t_32 = {
    LumberResource = true,
    BaseType = "Witchwood",
    SubType = "Log",
    BasePrice = 40,
    Min = 30,
    Max = 50,
    Increment = 5,
    ChildResources = { "Witchwood Plank", "Witchwood Stick" }
}
t_1["Witchwood Log"] = t_32
t_1["Witchwood Plank"] = {
    LumberResource = true,
    BaseType = "Witchwood",
    SubType = "Plank",
    Multiplier = 0.6
}
t_1["Witchwood Stick"] = {
    LumberResource = true,
    BaseType = "Witchwood",
    SubType = "Stick",
    Multiplier = 0.4
}
t_1["Giant Mushroom"] = { AppearsInShop = false, Unobtainable = true }
local t_34 = {
    LumberResource = true,
    BaseType = "Giant Mushroom",
    SubType = "Log",
    BasePrice = 40,
    Min = 30,
    Max = 50,
    Increment = 5,
    ChildResources = { "Giant Mushroom Plank", "Giant Mushroom Stick" }
}
t_1["Giant Mushroom Log"] = t_34
t_1["Giant Mushroom Plank"] = {
    LumberResource = true,
    BaseType = "Giant Mushroom",
    SubType = "Plank",
    Multiplier = 0.6
}
t_1["Giant Mushroom Stick"] = {
    LumberResource = true,
    BaseType = "Giant Mushroom",
    SubType = "Stick",
    Multiplier = 0.4
}
t_1.Oil = { LiquidResource = true, AppearsInShop = false, Unobtainable = true }
t_1.Lava = { LiquidResource = true, AppearsInShop = false, Unobtainable = true }
t_1["Empty Barrel"] = {
    UtilityResource = true,
    AppearsInShop = false,
    Min = 80,
    Max = 100,
    Increment = 5,
    BasePrice = 90,
    NotPurchasable = true,
    AppearsInLiquidRefinery = true
}
t_1["Oil Barrel"] = {
    BasePrice = 150,
    Min = 125,
    Max = 200,
    Increment = 10,
    UtilityResource = true,
    AppearsInShop = false,
    AppearsInLiquidRefinery = true,
    NotPurchasable = true
}
t_1["Lava Barrel"] = {
    BasePrice = 300,
    Min = 250,
    Max = 350,
    Increment = 15,
    UtilityResource = true,
    AppearsInShop = false,
    AppearsInLiquidRefinery = true,
    NotPurchasable = true
}
t_1["Soul Shard"] = {
    AppearsInShop = false,
    NotPurchasable = true,
    BasePrice = 500,
    Min = 400,
    Max = 600
}
t_1["Cursed Key"] = { UtilityResource = true, NotPurchasable = true }
t_1["Red Shroom"] = {
    MushroomResource = true,
    UtilityResource = true,
    NotPurchasable = true,
    BasePrice = 50,
    Min = 40,
    Max = 60,
    Increment = 5
}
t_1["Brown Shroom"] = {
    MushroomResource = true,
    UtilityResource = true,
    NotPurchasable = true,
    BasePrice = 50,
    Min = 40,
    Max = 60,
    Increment = 5
}
t_1["Soul Shroom"] = {
    MushroomResource = true,
    UtilityResource = true,
    NotPurchasable = true,
    BasePrice = 200,
    Min = 180,
    Max = 220,
    Increment = 10
}
t_1.Witchcap = {
    MushroomResource = true,
    UtilityResource = true,
    NotPurchasable = true,
    BasePrice = 80,
    Min = 60,
    Max = 100,
    Increment = 10
}
t_1.Magmaspore = {
    MushroomResource = true,
    UtilityResource = true,
    NotPurchasable = true,
    BasePrice = 120,
    Min = 100,
    Max = 140,
    Increment = 10
}

local _ = function(s1: string, u1: userdata) --[[ ValidateResourceData ]] -- line: 743
    -- upvalues:
    --  [1] v1 (copy)

    local v2, v3 = v1(u1)

    if not v2 then
        error(("Error validating resource %s: %s"):format(s1, v3))
    end
end

for key, val in t_1 do
    val.Name = key

    if val.BasePrice and val.ChildResources then
        for _, val_1 in pairs(val.ChildResources) do
            local v5 = t_1[val_1]
            v5.BasePrice = math.floor(val.BasePrice * v5.Multiplier + 0.5)
            v5.Max = math.floor(val.Max * v5.Multiplier + 0.5)
            v5.Min = math.floor(val.Min * v5.Multiplier + 0.5)
        end
    end

    local v6, v7 = v1(val)

    if not v6 then
        error(("Error validating resource %s: %s"):format(key, v7))
    end
end

table.freeze(t_1)

return t_1
