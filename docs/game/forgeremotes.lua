
local Event = workspace.Forge.ForgeUpdateEvent -- TakeResult collects materials that were melted in forge
Event:FireServer(
    "TakeResult"
)

local Event = workspace.Forge.ForgeUpdateEvent -- AddFuel adds chosen fuel to the forge (fuel data is located in fueldata.lua)
Event:FireServer(
    "AddFuel",
    "Coal"
)

local Event = workspace.Forge.ForgeUpdateEvent -- AddInput adds chosen ore from your inventory to the forge
Event:FireServer(
    "AddInput",
    {
        "Iron Ore",
        1
    }
)
