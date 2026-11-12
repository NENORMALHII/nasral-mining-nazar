# Forge remotes

`workspace.Forge.ForgeUpdateEvent` is used for every forge action.

```lua
local Event = workspace.Forge.ForgeUpdateEvent

-- collect melted materials
Event:FireServer("TakeResult")

-- add fuel (fuel list: decompiled/fuel-data.lua)
Event:FireServer("AddFuel", "Coal")

-- add ore from inventory
Event:FireServer("AddInput", { "Iron Ore", 1 })
```
