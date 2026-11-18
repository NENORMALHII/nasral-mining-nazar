-- Read-only Forge inspection: instances, ForgeHelper/FuelData tables, ore counts
-- and the last ForgeUpdateEvent payload. No FireServer calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ORE_NAMES = {
    "Copper Ore",
    "Iron Ore",
    "Silver Ore",
    "Gold Ore",
    "Promethium Ore",
    "Mithril Ore",
    "Malachite Ore",
    "Azurite Ore",
}

local forge = workspace:WaitForChild("Forge")
local updateEvent = forge:WaitForChild("ForgeUpdateEvent")

print("[forge] part:", forge:GetFullName())
print("[forge] toggle:", forge:FindFirstChild("ToggleForgeEvent") and "ok" or "missing")
print("[forge] interact:", forge:FindFirstChild("Interact")
    and forge.Interact:FindFirstChild("InteractEvent") and "ok" or "missing")

---------------------------------------------------------------------------
-- Ore table and fuel table
---------------------------------------------------------------------------

local function dumpTable(label, data)
    if type(data) ~= "table" then
        print("[forge]", label, tostring(data))
        return
    end

    for key, value in pairs(data) do
        if type(value) == "table" then
            local parts = {}
            for field, inner in pairs(value) do
                table.insert(parts, ("%s=%s"):format(field, tostring(inner)))
            end
            print(("[forge] %s.%s %s"):format(label, tostring(key), table.concat(parts, " ")))
        else
            print(("[forge] %s.%s %s"):format(label, tostring(key), tostring(value)))
        end
    end
end

local okHelper, helper = pcall(function()
    return require(forge:WaitForChild("ForgeHelper"))
end)

if okHelper and type(helper) == "table" then
    print("[forge] ForgeHelper ProductionBar2Cost:", helper.ProductionBar2Cost)

    if type(helper.GetOreData) == "function" then
        for _, name in ipairs(ORE_NAMES) do
            local ok, data = pcall(helper.GetOreData, helper, name)

            if ok and type(data) == "table" then
                print(("[forge] %s melt=%s time=%s result=%s"):format(
                    name,
                    tostring(data.MeltingPoint),
                    tostring(data.SmeltTime),
                    tostring(data.Result)
                ))
            else
                print("[forge]", name, "GetOreData failed:", tostring(data))
            end
        end
    end
else
    print("[forge] ForgeHelper require failed:", tostring(helper))
end

local okFuels, fuels = pcall(function()
    return require(ReplicatedStorage.Scripts:WaitForChild("FuelData"))
end)

if okFuels and type(fuels) == "table" then
    dumpTable("fuel", fuels.Fuels)
else
    print("[forge] FuelData require failed:", tostring(fuels))
end

---------------------------------------------------------------------------
-- Inventory counts for forge ores
---------------------------------------------------------------------------

local inventory = _G.inv

if not inventory then
    local loader = ReplicatedStorage:FindFirstChild("Modules")
    loader = loader and loader:FindFirstChild("PlayerScriptLoader")

    if loader then
        local ok, scripts = pcall(function()
            return loader:WaitForPlayerScripts()
        end)
        local modules = ok and scripts and scripts:FindFirstChild("Modules")
        local module = modules and modules:FindFirstChild("InventoriesClient")

        if module then
            local okClient, client = pcall(require, module)
            if okClient and type(client) == "table" then
                local okInventory, value = pcall(function()
                    return client.GetInventory()
                end)
                inventory = okInventory and value or nil
            end
        end
    end
end

if inventory and type(inventory.Resources) == "table" then
    print(("[forge] inventory %s/%s"):format(
        tostring(inventory.CurrentSize),
        tostring(inventory.MaxSize)
    ))

    for _, name in ipairs(ORE_NAMES) do
        print(("[forge] %s=%s"):format(name, tostring(inventory.Resources[name])))
    end
else
    print("[forge] inventory not available (_G.inv / InventoriesClient)")
end

---------------------------------------------------------------------------
-- Last server payload
---------------------------------------------------------------------------

updateEvent.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then
        return
    end

    local player = payload.PlayerForgeData or {}
    local source = payload.SourceData or {}
    local input = player.Input or {}
    local output = player.Output or {}
    local fuel = source.Fuel or {}

    print(("[forge] state input=%s x%s output=%s x%s bars=%s"):format(
        tostring(input.Type),
        tostring(input.Amount),
        tostring(output.Type),
        tostring(output.Amount),
        tostring(input.BarCount)
    ))
    print(("[forge] state temp=%s/%s fuel=%s burn=%s/%s"):format(
        tostring(source.Temperature),
        tostring(source.MaxTemperature),
        tostring(fuel.Amount),
        tostring(fuel.BurnTimeRemaining),
        tostring(fuel.TotalBurnTime)
    ))
end)

print("[forge] ready, open the forge to log one payload")
