-- Script Path: game:GetService("ReplicatedStorage").Modules.WeightedRandom
-- Took 0.05s to decompile.
-- Executor: Delta (1.0.745.1142)

local v_u_1 = require(game.ReplicatedStorage.Modules.CharacterStatDefinitions)
local v_u_2 = require(game.ReplicatedStorage.Modules.CommonUtils)
local v3 = require(game.ReplicatedStorage.Lib.Typecheck)
local v_u_4 = require(game.ReplicatedStorage.Modules.Logger).new()
local v_u_5 = v3.strictInterface({
    ["Weight"] = v3.numberPositive,
    ["Scalable"] = v3.optional(v3.boolean),
    ["Inverted"] = v3.optional(v3.boolean)
})
local v_u_6 = {}
v_u_6.__index = v_u_6
function v_u_6.from(p7, p8, p9) -- name: from
    -- upvalues: (copy) v_u_2, (copy) v_u_6, (copy) v_u_5
    if p8 ~= nil then
        local v10 = typeof(p8) == "number"
        assert(v10, "Scale must be a number")
    end
    local v11 = {
        ["_tab"] = nil,
        ["_values"] = nil,
        ["_totalWeight"] = 0,
        ["_random"] = nil,
        ["_scaledRandoms"] = nil,
        ["_tab"] = {},
        ["_values"] = v_u_2:CopyTable(p7),
        ["_random"] = Random.new(tick()),
        ["_scaledRandoms"] = {}
    }
    local v12 = v_u_6
    local v13 = setmetatable(v11, v12)
    for v14, v15 in pairs(p7) do
        local v16 = 0
        local v17 = true
        local v18 = false
        local v19
        if typeof(v15) == "number" then
            local v20 = typeof(v15) == "number"
            assert(v20, "Weight must be numbers")
            local v21 = v15 >= 0
            assert(v21, "Weight must be non-negative")
            v19 = v15
        else
            local v22, v23 = v_u_5(v15)
            if not v22 then
                error("Invalid weight definition: " .. v23)
            end
            v19 = v16 + v15.Weight
            if v15.Scalable == false then
                v17 = false
            end
            if v15.Inverted == true then
                v18 = true
            end
        end
        if p8 ~= nil then
            v19 = v19 * 10
            if v17 then
                local v24
                if v18 then
                    v24 = 1 - (p8 - 1)
                else
                    v24 = p8
                end
                local v25 = v19 * v24
                v19 = math.floor(v25)
            end
        end
        v13._totalWeight = v13._totalWeight + v19
        local v26 = v13._tab
        local v27 = {
            ["value"] = v14,
            ["weight"] = v19,
            ["cumulativeWeight"] = v13._totalWeight
        }
        table.insert(v26, v27)
    end
    if p9 == nil then
        print("Created new WeightedRandom", v13)
        return v13
    else
        print("Created new WeightedRandom", p9, v13)
        return v13
    end
end
function v_u_6.GetRandomValue(p28) -- name: GetRandomValue
    local v29 = p28._random:NextInteger(1, p28._totalWeight)
    for _, v30 in ipairs(p28._tab) do
        if v30.cumulativeWeight - v30.weight >= v29 or v29 > v30.cumulativeWeight then
            continue
        end
        return v30.value
    end
    error("Could not find value for random weight " .. v29, 2)
end
function v_u_6.GetRandomValueWithLuck(p31, p32) -- name: GetRandomValueWithLuck
    -- upvalues: (copy) v_u_1, (copy) v_u_4, (copy) v_u_6
    local v33 = p32:GetAttribute(v_u_1.Luck.Id)
    v_u_4:debug("Player %s has luck %.2f", p32.Name, v33)
    if v33 == nil or math.floor(v33) == 0 then
        return p31:GetRandomValue()
    end
    local v34 = math.floor(v33)
    if p31._scaledRandoms[v34] then
        return p31._scaledRandoms[v34]:GetRandomValue()
    end
    local v35 = 1 + v34 / 100
    v_u_4:debug("Created new WeightedRandom with scale = %.2f", v35)
    p31._scaledRandoms[v34] = v_u_6.from(p31._values, v35)
    return p31._scaledRandoms[v34]:GetRandomValue()
end
function v_u_6.Simulate(p36, p37) -- name: Simulate
    local v38 = p37 > 0
    assert(v38, "Number of iterations must be greater than 0")
    local v39 = {}
    for _ = 1, p37 do
        local v40 = p36:GetRandomValue()
        if v39[v40] == nil then
            v39[v40] = 0
        end
        v39[v40] = v39[v40] + 1
    end
    return v39
end
function v_u_6.SimulateAndPrint(p41, p42) -- name: SimulateAndPrint
    local v43 = p41:Simulate(p42)
    print("Simulation results:")
    for v44, v45 in pairs(v43) do
        print(v44, string.format("%.2f%%", v45 * 100 / p42))
    end
end
return v_u_6
