# Forge remotes

`workspace.Forge.ForgeUpdateEvent` is used for every forge action.

```lua
local Event = workspace.Forge.ForgeUpdateEvent

-- collect melted materials
Event:FireServer("TakeResult")

-- add fuel (fuel list: decompiled/fuel-data.lua)
Event:FireServer("AddFuel", "Coal")

-- add ore from inventory; count is client-chosen, the UI sends 1 or the full stack
Event:FireServer("AddInput", { "Iron Ore", 1 })
```

Confirmed against `decompiled/forge-client.lua`: `AddInput` payload is
`{ oreName, count }`, `count = _G.inv.Resources[oreName]` only while `LeftShift`
is held (line 35). The only pre-check is `_G.inv.Resources[oreName] > 0` (line
32). `BuyProductionBar` takes no payload. `ToggleForgeEvent:FireServer()` closes
the forge.

Full protocol, ore/fuel tables and the exploit test matrix:
`protocol/forge.md`.
