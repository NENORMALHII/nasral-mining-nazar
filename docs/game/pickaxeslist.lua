-- Script Path: game:GetService("ReplicatedStorage").Modules.Tools.Pickaxes
-- Took 0s to decompile.
-- Executor: Lynx (0.747)

local Assets_m = require(game.ReplicatedFirst.Assets)
local t = {}
t["Stone Pickaxe"] = {
    Material = Enum.Material.Slate,
    Color = BrickColor.new("Medium stone grey"),
    Icon = Assets_m.Images.PICKAXE_HEAD_STONE,
    BaseMineTime = 4,
    DoubleDropChance = 0,
    Tier = 1
}
t["Copper Pickaxe"] = {
    Material = Enum.Material.Metal,
    Color = BrickColor.new("Dark orange"),
    Icon = Assets_m.Images.PICKAXE_HEAD_COPPER,
    BaseMineTime = 3.4,
    DoubleDropChance = 1.25,
    Tier = 2
}
t["Iron Pickaxe"] = {
    Material = Enum.Material.Metal,
    Color = BrickColor.new("Medium stone grey"),
    Icon = Assets_m.Images.PICKAXE_HEAD_IRON,
    BaseMineTime = 3,
    DoubleDropChance = 2.5,
    Tier = 3
}
t["Silver Pickaxe"] = {
    Material = Enum.Material.Metal,
    Color = BrickColor.new("Light stone grey"),
    Icon = Assets_m.Images.PICKAXE_HEAD_SILVER,
    BaseMineTime = 2.5,
    DoubleDropChance = 3.75,
    Tier = 3
}
t["Emerald Pickaxe"] = {
    Material = Enum.Material.Marble,
    Color = BrickColor.new("Bright green"),
    Icon = Assets_m.Images.PICKAXE_HEAD_EMERALD,
    BaseMineTime = 2,
    DoubleDropChance = 5,
    Tier = 4
}
t["Ruby Pickaxe"] = {
    Material = Enum.Material.Marble,
    Color = BrickColor.new("Bright red"),
    Icon = Assets_m.Images.PICKAXE_HEAD_RUBY,
    BaseMineTime = 1.5,
    DoubleDropChance = 6,
    Tier = 4
}
t["Sapphire Pickaxe"] = {
    Material = Enum.Material.Marble,
    Color = BrickColor.new("Bright blue"),
    Icon = Assets_m.Images.PICKAXE_HEAD_SAPPHIRE,
    BaseMineTime = 1.2,
    DoubleDropChance = 7,
    Tier = 4
}
t["Gold Pickaxe"] = {
    Material = Enum.Material.Metal,
    Color = BrickColor.new("Bright yellow"),
    Icon = Assets_m.Images.PICKAXE_HEAD_GOLD,
    BaseMineTime = 0.9,
    DoubleDropChance = 8,
    Tier = 5
}
t["Diamond Pickaxe"] = {
    Material = Enum.Material.Ice,
    Color = BrickColor.new("Pastel light blue"),
    Icon = Assets_m.Images.PICKAXE_HEAD_DIAMOND,
    BaseMineTime = 0.7,
    DoubleDropChance = 9,
    Tier = 6
}
t["Obsidian Pickaxe"] = {
    Material = Enum.Material.Granite,
    Color = Color3.fromRGB(84, 69, 255),
    Icon = Assets_m.Images.PICKAXE_HEAD_OBSIDIAN,
    BaseMineTime = 0.5,
    DoubleDropChance = 10,
    Tier = 6
}
t["Mithril Pickaxe"] = {
    Material = Enum.Material.Metal,
    Color = BrickColor.new("Medium blue"),
    Icon = Assets_m.Images.PICKAXE_HEAD_MITHRIL,
    InstaMine = true,
    BaseMineTime = 0.3,
    DoubleDropChance = 12.5,
    Tier = 6
}
t["Pickaxe of the Core"] = {
    Material = Enum.Material.Neon,
    Color = Color3.fromRGB(190, 104, 98),
    UIColor = Color3.fromRGB(255, 51, 15),
    Icon = Assets_m.Images.PICKAXE_HEAD_CORE,
    BaseMineTime = 1,
    DoubleDropChance = 50,
    Durability = 200,
    Tooltip = function(arg1) -- line: 101
        return { { Color = arg1.UIColor, Text = "100% Autosmelt Chance" } }
    end
}
t["Aetherial Pickaxe"] = {
    Material = Enum.Material.Neon,
    Color = Color3.fromRGB(52, 167, 92),
    UIColor = Color3.fromRGB(65, 212, 114),
    Icon = Assets_m.Images.PICKAXE_HEAD_AETHERIAL,
    BaseMineTime = 0.8,
    DoubleDropChance = 15,
    Durability = 250,
    Tooltip = function(arg2) -- line: 115
        return {
            { Color = arg2.UIColor, Text = "+20% Luck" },
            { Color = arg2.UIColor, Text = "" },
            { Color = arg2.UIColor, Text = "Doesn't lose durability when\nmining Dirt or Stone" }
        }
    end
}

return (table.freeze(t))
