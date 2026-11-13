# Selling resources

When the inventory is full, sell resources and return to mining.

```lua
local Event = game:GetService("ReplicatedStorage").SellResourceFunction
Event:InvokeServer(
    "Iron Ore",
    1
)
```

`SellResourceFunction` sells the chosen resource and its amount from the player's inventory.

## Resource counts (`docs/game/instructions/getinventory.lua`)

Resource stacks are NOT in `Player.Backpack` (that holds tools only) and are NOT
`LocalPlayer` attributes. The client reads them from `InventoriesClient`:

```lua
local PlayerScriptLoader = require(game.ReplicatedStorage.Modules.PlayerScriptLoader)
local scripts = PlayerScriptLoader:WaitForPlayerScripts()
local InventoriesClient = require(scripts.Modules.InventoriesClient)

local inv = InventoriesClient.GetInventory()
print(inv.CurrentSize, inv.MaxSize)      -- used / capacity
for name, count in pairs(inv.Resources) do
    print(name, count)                  -- "Iron Ore", 42, ...
end
```

`src/main.lua` uses the same source in `Inventory.count` / `Inventory.usage`.
`Sell.count` falls back to Backpack stacks and `LocalPlayer` attributes only if
`InventoriesClient` is not loaded yet.

## When auto sell runs

- at the start of every Farm tick (`Sell.run()`);
- right after each successful loot pickup: `Sell.isFull()` compares
  `Inventory.usage()` used vs max, then `Sell.run()` sells the selected resources.

`Sell.run()` without `force` still requires the Auto sell toggle and respects
`sellCooldown = 1`. The "Sell now" button forces a run.

## Failure seen before the fix

Logs `manual sell total 0` and `sell: names=22 selected=20, used=232/525`
meant the GUI label reported a full inventory but every `Sell.count(name)`
returned `0`, so no `InvokeServer` call was made. Cause: counts were read from
`Backpack` children / `LocalPlayer` attributes, neither of which stores
resources. Fixed by reading `InventoriesClient.GetInventory().Resources`.
