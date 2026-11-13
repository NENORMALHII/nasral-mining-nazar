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

`Sell.try(origin)` compares used vs max and runs the sell when full. It is fully
independent from the farming modes:

- `"watch"` — background loop every 1 s, runs whether Farm/Mushroom is on or off;
- `"manual"` — the "Sell now" button (`Sell.manual()`), forced and logged as
  `manual sell total`. It ignores `Sell.enabled`, ignores `isFull()` (works with a
  partially filled backpack), still respects the resource selection, surfaces first
  if the player is underground, and holds the root until the last remote returns.

The remote refuses to work while the player is underground. Before firing it,
The sell remote only accepts the fixed point `Config.sellAnchor = (78, 8013, -219)`
(`x=78, y=8013, z=-219`); any other position is rejected. `Sell.toSurface` jumps
there unless the player is already close to it on the surface, and
`Sell.holdForSale` anchors the root and sets its CFrame exactly to that point, so
the sale always happens at the same coordinates. It logs
`autosell: leaving depth N for sell point 78,8013,-219`. If a mine is currently in its
`BlockEvent`/`BlockMinedEvent` window (`Movement.holdRoot` is set), the sell is
deferred to the next watcher tick instead of interrupting it.

`Sell.holdForSale` anchors the root exactly at `(78, 8013, -219)`.
Timeline: `Config.sellHoldBefore = 3` s on the anchor, then all `InvokeServer` calls,
then `Config.sellHoldAfter = 2` s on the anchor after the last remote, and only then
`Movement.releaseHold`. Without the anchor the character falls from the sell point
and the server rejects part of the sale.
`Sell.busy` is set for the whole
surface trip, and `FarmMode`/`MushroomMode` return immediately while it is set,
so they cannot move the character or clear the anchor mid-sale.

Diagnostics (throttled to one line per 10 s for repeated states):

- `autosell toggle on|off` — toggle changed;
- `autosell <origin>: not full used=U/M src=<source>`;
- `autosell <origin>: no capacity ...`;
- `autosell <origin>: toggle off, sell skipped`;
- `autosell trigger <origin> used=U/M src=<source> enabled=<bool>`;
- `sell run (<origin>) names=N selected=S with=C units=U used=U/M src=<source>`;
- `sell: inventory source=<src>, per-resource counts may be 0`;
- `autosell: no resources selected` / `autosell: selected resources have zero count`;
- `inventory: InventoriesClient ready`, or a distinct warning for each load failure.

The Auto sell list is built by `Sell.names()`: every `Resources` entry with a
`BasePrice` that is either `Natural = true` (mined ores) or
`MushroomResource = true` (`Red Shroom`, `Brown Shroom`, `Soul Shroom`,
`Witchcap`, `Magmaspore`). The farm ore list (`Ores.names()`) stays `Natural`
only. Smelted bars, planks and sticks are still not in the sell list, so a
backpack full of them keeps `used` at max while every run sells `units=0`.

`Sell.run()` without `force` still requires the Auto sell toggle and respects
`sellCooldown = 1`.

## Where used/max comes from (`Sell.usage`)

The third return value `src` names the source:

1. `"client"` — `InventoriesClient.GetInventory()` → `CurrentSize`, `MaxSize`.
   This is the real backpack volume (see `getinventory.lua`). The module is loaded
   with `PlayerScriptLoader:WaitForPlayerScripts()` → `Modules.InventoriesClient`,
   cached after the first success, retried at most every 5 s.
2. `"gui"` — fallback: parse `PlayerGui.Inventory.ToggleButton.InventoryUsed.Text`
   as `used / max`.
3. `"sum"` — last fallback: sum of `Sell.count(name)` over natural resources
   compared against `Config.sellCapacity` (200).

## Failure seen before the fix

Logs `manual sell total 0` and `sell: names=22 selected=20, used=232/525`
meant the GUI label reported a full inventory but every `Sell.count(name)`
returned `0`, so no `InvokeServer` call was made. Cause: counts were read from
`Backpack` children / `LocalPlayer` attributes, neither of which stores
resources. Fixed by reading `InventoriesClient.GetInventory().Resources`.
