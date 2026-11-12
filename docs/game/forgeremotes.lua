
local Event = workspace.Forge.ForgeUpdateEvent -- takeresult collects materials that were melted in forge
Event:FireServer(
    "TakeResult"
)

local Event = workspace.Forge.ForgeUpdateEvent -- AddFuel adds chosen fuel to the forge (fuel data is located in fueldata.lua)
Event:FireServer(
    "AddFuel",
    "Coal"
)
