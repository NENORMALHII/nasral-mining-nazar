# Forge automation (surface trip)

Implemented in `src/main.lua` as the `Forge` module. Protocol and client line
references: `protocol/forge.md`.

## Sequence

Runs after the surface teleport, while the root is still anchored by
`Sell.holdForSale`, in this order:

1. `Forge.enter` — `Workspace.Forge.Interact.InteractEvent:FireServer()` and up to
   `Config.forgeOpenWait = 1` s waiting for `ToggleForgeEvent.OnClientEvent` (the
   server's "forge opened" signal treated as "server accepts forge actions"),
   followed by `forgeOpenBuffer = 0.2` s before the first action remote.
2. `TakeResult` — melted bars into the inventory. Skipped (like the real client)
   while `Inventory.usage()` reports `used >= capacity`. After the fire-and-forget
   remote, `forgeActionWait = 0.35` s before reading state, then up to
   `forgeStateWait = 1.5` s waiting for `Output.Amount` to change.
3. `AddInput` — highest-value selected ore with `Inventory.count(name) > 0`,
   sent as `{ name, count }` with the full owned count. Value is one smelted
   bar: `BasePrice * Bar.Multiplier` (`Copper 20*1.5` … `Mithril 600*1.5`), ties by
   name. The "Ores to smelt" list is shown in that order. Skipped while the server
   state already shows `Input.Amount > 0`; one ore type per visit because the
   forge input holds a single type. Same wait pattern: `forgeActionWait`, then a
   state wait, then `Inventory.invalidate()`.
4. `AddFuel` — first selected fuel with stock. Units =
   `ceil((SmeltTime * inputCount - BurnTimeRemaining) / BurnTime)`, capped by
   stock and `Config.forgeMaxFuelUnits = 10`. Fuel is only added when an ore is
   queued. One `AddFuel` per `forgeActionWait = 0.35` s; the inventory snapshot is
   dropped afterwards.
5. `Forge.leave` — `ToggleForgeEvent:FireServer()` plus the same local cleanup as
   `ForgeClient`'s CloseButton (`Container.Visible = false`,
   `BackpackVisible = true`). Only when this trip opened the forge. A
   `forgeSettle = 0.3` s buffer runs before it, so the last remote lands before
   the caller sells.

Then the caller sells.

## Call sites

| Path | Behaviour |
|---|---|
| `Sell.try` (auto sell) | only when the backpack is full and Auto sell is enabled; forge first, `Sell.run` after |
| `Sell.manual` ("Sell now") | always; forge first, forced sale after |
| `Forge.trip` ("Service now") | surface trip with forge only, no sale; ignores the toggle |

Auto sell off means no surface trip, so the forge is not serviced automatically.

## Settings

| Key | Control |
|---|---|
| `forgeEnabled` | Forge → Service on surface |
| `forgeOres` | Forge → Ores to smelt (default `none`) |
| `forgeFuels` | Forge → Fuel (default `none`) |

Ore list is the static `ForgeHelper` order sorted by bar value (`Forge.oreNames`,
cached); fuel list comes from `FuelData:GetAllFuels()` with a static fallback.
Smelt time and burn time are read from `ForgeHelper:GetOreData` /
`FuelData:GetFuelData`, with the table values from `protocol/forge.md` as fallback.

## Unverified

- Whether `InteractEvent` with no arguments is the correct open request.
- Whether `TakeResult`, `AddInput`, `AddFuel` require the forge to be open, the
  player to be in range, or fuel/temperature to be valid.
- Whether the server clips `AddInput` count to the owned amount or accepts
  negative / unknown values (test matrix in `protocol/forge.md`).
- Whether `AddFuel` consumes one unit per call.
