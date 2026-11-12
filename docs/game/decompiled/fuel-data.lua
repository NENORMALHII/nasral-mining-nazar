-- Script Path: game:GetService("ReplicatedStorage").Scripts.FuelData
-- Took 0s to decompile.
-- Executor: Lynx (0.747)

local t = {}
local Util_m = require(game.ReplicatedStorage.Util)
t.Fuels = {
    Coal = { BurnTime = 70 },
    Log = { BurnTime = 30 },
    Plank = { BurnTime = 30 },
    ["Oil Barrel"] = { BurnTime = 100 },
    ["Lava Barrel"] = { BurnTime = 130 },
    Ignis = { BurnTime = 110 }
}

function t.ToTrueFuel(_, arg2) -- line: 25
    if arg2:find(" Log") then
        return "Log"
    end

    if arg2:find(" Plank") then
        arg2 = "Plank"
    end

    return arg2
end

function t.GetAllFuels(_) -- line: 35
    -- upvalues:
    --  [1] Util_m (copy)
    --  [2] t (copy)

    local t_2 = {}

    for _, val in pairs(Util_m.ResourceOrder) do
        if t.Fuels[val] then
            table.insert(t_2, val)
        elseif not t.Fuels[val] then
            for key_1, _ in pairs(t.Fuels) do
                if val:find(" " .. key_1) then
                    table.insert(t_2, val)
                end
            end
        end
    end

    return t_2
end

function t.GetFuelData(_, arg5) -- line: 53
    -- upvalues:
    --  [1] t (copy)

    if arg5:find(" Log") then
        arg5 = "Log"
    elseif arg5:find(" Plank") then
        arg5 = "Plank"
    end

    if not t.Fuels[arg5] then
        return nil
    end

    return t.Fuels[arg5]
end

return t
