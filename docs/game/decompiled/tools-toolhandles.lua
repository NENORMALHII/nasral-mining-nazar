-- Script Path: game:GetService("ReplicatedStorage").Modules.Tools.ToolHandles
-- Took 0.01s to decompile.
-- Executor: Lynx (0.747)

local Assets_m = require(game.ReplicatedFirst.Assets)
local Enums_m = require(game.ReplicatedStorage.Modules.Enums)
local TreeTypes_m = require(game.ReplicatedStorage.Scripts.TreeTypes)
local t = {}
t.Oak = {
    Color = TreeTypes_m.Types.Oak.CoreColor,
    Icon = Assets_m.Images.HANDLE_OAK,
    Description = function(_: any, _: number) -- line: 12
        return { { Text = "Nothing" } }
    end,
    DescriptionTooltip = function(_: any, _: number) -- line: 15
        return {}
    end
}
t.Pine = {
    Color = TreeTypes_m.Types.Pine.CoreColor,
    Icon = Assets_m.Images.HANDLE_PINE,
    Description = function(arg3: any, _: number) -- line: 23
        return {
            {
                Color = arg3.Color,
                Text = ("+%d move speed per each tool\nwith a Pine handle"):format(
                    arg3.MoveSpeedModifier
                )
            }
        }
    end,
    Buffs = function(_: any, _: number) -- line: 26
        return { "Pine" }
    end,
    MoveSpeedModifier = 10
}
t.Ash = {
    Color = TreeTypes_m.Types.Ash.CoreColor,
    Icon = Assets_m.Images.HANDLE_ASH,
    Description = function(arg5: any, _: number) -- line: 36
        return { { Color = arg5.Color, Text = "+1 total jumps per each tool\nwith an Ash handle" } }
    end,
    Buffs = function(_: any, _: number) -- line: 39
        return { "Ash" }
    end
}
t.Birch = {
    Color = TreeTypes_m.Types.Birch.CoreColor,
    Icon = Assets_m.Images.HANDLE_BIRCH,
    Description = function(arg7: any, _: number) -- line: 47
        return {
            { Color = arg7.Color, Text = ("+%d%% Luck while equipped"):format(arg7.LuckModifier) }
        }
    end,
    Buffs = function(_: any, n8: number) -- line: 50
        -- upvalues:
        --  [1] Enums_m (copy)

        if n8 == Enums_m.ToolType.Pickaxe then
            return { "BirchPickaxePassive" }
        end

        if n8 == Enums_m.ToolType.Axe then
            return { "BirchAxePassive" }
        end
    end,
    LuckModifier = 10
}
t.Silverwood = {
    Color = TreeTypes_m.Types.Silverwood.CoreColor,
    Icon = Assets_m.Images.HANDLE_SILVERWOOD,
    Description = function(arg9: any, n9: number) -- line: 64
        -- upvalues:
        --  [1] Enums_m (copy)

        if n9 == Enums_m.ToolType.Pickaxe then
            return {
                {
                    Color = arg9.Color,
                    Text = ("+%d%% Double Drop Chance"):format(arg9.DoubleDropChanceModifier)
                }
            }
        end

        return {
            {
                Color = arg9.Color,
                Text = ("+%d%% Log Double Drop Chance"):format(arg9.DoubleDropChanceModifier)
            }
        }
    end,
    Buffs = function(_: any, n10: number) -- line: 72
        -- upvalues:
        --  [1] Enums_m (copy)

        if n10 == Enums_m.ToolType.Pickaxe then
            return { "SilverwoodPickaxe" }
        end

        if n10 == Enums_m.ToolType.Axe then
            return { "SilverwoodAxe" }
        end
    end,
    DoubleDropChanceModifier = 15
}
t.Goldbranch = {
    Color = TreeTypes_m.Types.Goldbranch.CoreColor,
    Icon = Assets_m.Images.HANDLE_GOLDBRANCH,
    Description = function(arg11: any, n11: number) -- line: 86
        -- upvalues:
        --  [1] Enums_m (copy)

        if n11 == Enums_m.ToolType.Pickaxe then
            return {
                { Color = arg11.Color, Text = ("+%d%% Mining Speed"):format(arg11.SpeedModifier) }
            }
        end

        return {
            { Color = arg11.Color, Text = ("+%d%% Cutting Speed"):format(arg11.SpeedModifier) }
        }
    end,
    Buffs = function(_: any, _: number) -- line: 94
        return { "Goldbranch" }
    end,
    SpeedModifier = 20
}
t.Cinderbark = {
    Color = TreeTypes_m.Types.Cinderbark.CoreColor,
    Icon = Assets_m.Images.HANDLE_CINDERBARK,
    Description = function(arg13: any, n13: number) -- line: 104
        -- upvalues:
        --  [1] Enums_m (copy)

        if n13 == Enums_m.ToolType.Pickaxe then
            return {
                {
                    Color = arg13.Color,
                    Text = ("+%d%% Autosmelt Chance"):format(arg13.AutoSmeltChance)
                }
            }
        end

        return {
            { Color = arg13.Color, Text = ("+%d%% Autosaw Chance"):format(arg13.AutoSawChance) }
        }
    end,
    Buffs = function(_: any, n14: number) -- line: 112
        -- upvalues:
        --  [1] Enums_m (copy)

        if n14 == Enums_m.ToolType.Pickaxe then
            return { "CinderbarkPickaxe" }
        end

        if n14 == Enums_m.ToolType.Axe then
            return { "CinderbarkAxe" }
        end
    end,
    AutoSmeltChance = 50,
    AutoSawChance = 50
}
t.Witchwood = {
    Color = TreeTypes_m.Types.Witchwood.CoreColor,
    Icon = Assets_m.Images.HANDLE_WITCHWOOD,
    Description = function(arg15: any, n15: number) -- line: 127
        -- upvalues:
        --  [1] Enums_m (copy)

        if n15 == Enums_m.ToolType.Pickaxe then
            return {
                { Color = arg15.Color, Text = ("+%d%% Mining Speed"):format(arg15.SpeedModifier) },
                { Color = arg15.Color, Text = ("+%d%% Pump Speed"):format(arg15.PumpSpeedModifier) }
            }
        end

        return {
            { Color = arg15.Color, Text = ("+%d%% Cutting Speed"):format(arg15.SpeedModifier) },
            { Color = arg15.Color, Text = ("+%d%% Lumber Value"):format(arg15.LumberValueModifier) }
        }
    end,
    Buffs = function(_: any, n16: number) -- line: 141
        -- upvalues:
        --  [1] Enums_m (copy)

        if n16 == Enums_m.ToolType.Pickaxe then
            return { "WitchwoodPickaxe", "WitchwoodPickaxePassive" }
        end

        if n16 == Enums_m.ToolType.Axe then
            return { "WitchwoodAxe", "WitchwoodAxePassive" }
        end
    end,
    SpeedModifier = 10,
    PumpSpeedModifier = 20,
    LumberValueModifier = 50
}
t.Stone = {
    Color = BrickColor.new("Medium stone grey").Color,
    Material = Enum.Material.Slate,
    Description = function(_: any, _: number) -- line: 157
        return {}
    end
}
t["Giant Mushroom"] = {
    Color = TreeTypes_m.Types["Giant Mushroom"].CoreColor,
    Icon = Assets_m.Images.HANDLE_GIANT_MUSHROOM,
    Description = function(arg18: any, n18: number) -- line: 166
        -- upvalues:
        --  [1] Enums_m (copy)

        if n18 == Enums_m.ToolType.Pickaxe then
            return {
                {
                    Color = arg18.Color,
                    Text = ("+%d%% Shroom Double Drop Chance"):format(
                        arg18.MushroomDoubleDropChance
                    )
                },
                { Color = arg18.Color, Text = ("+%d%% Mining Speed"):format(arg18.SpeedModifier) }
            }
        end

        return {
            {
                Color = arg18.Color,
                Text = ("+%d%% Shroom Double Drop Chance"):format(arg18.MushroomDoubleDropChance)
            },
            { Color = arg18.Color, Text = ("+%d%% Cutting Speed"):format(arg18.SpeedModifier) }
        }
    end,
    Buffs = function(_: any, n19: number) -- line: 180
        -- upvalues:
        --  [1] Enums_m (copy)

        if n19 == Enums_m.ToolType.Pickaxe then
            return { "GiantMushroomPickaxe" }
        end

        if n19 == Enums_m.ToolType.Axe then
            return { "GiantMushroomAxe" }
        end
    end,
    MushroomDoubleDropChance = 75,
    SpeedModifier = 8
}

return (table.freeze(t))
