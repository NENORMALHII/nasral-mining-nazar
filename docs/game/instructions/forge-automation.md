# Forge automation (surface trip)

Implemented in `src/main.lua` as the `Forge` module. Protocol and client line
references: `protocol/forge.md`.

## Sequence

Runs after the surface teleport, while the root is still anchored by
`Sell.holdForSale`, in this order:

1. `Forge.enter` — `Workspace.Forge.Interact.InteractEvent:FireServer()` and up to
   `Config.forgeOpenWait = 1` s waiting for `ToggleForgeEvent.OnClientEvent` (the
   server's "forge opened" signal treated as "server accepts forge actions").
2. `TakeResult` — melted bars into the inventory. Skipped (like the real client)
   while `Inventory.usage()` reports `used >= capacity`.
3. `AddInput` — first selected ore (UI order) with `Inventory.count(name) > 0`,
   sent as `{ name, count }` with the full owned count. Skipped while the server
   state already shows `Input.Amount > 0`; one ore type per visit because the
   forge input holds a single type.
4. `AddFuel` — first selected fuel with stock. Units =
   `ceil((SmeltTime * inputCount - BurnTimeRemaining) / BurnTime)`, capped by
   stock and `Config.forgeMaxFuelUnits = 10`. Fuel is only added when an ore is
   queued.
5. `Forge.leave` — `ToggleForgeEvent:FireServer()` plus the same local cleanup as
   `ForgeClient`'s CloseButton (`Container.Visible = false`,
   `BackpackVisible = true`). Only when this trip opened the forge.

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

Ore list is the static `ForgeHelper` order; fuel list comes from
`FuelData:GetAllFuels()` with a static fallback. Smelt time and burn time are
read from `ForgeHelper:GetOreData` / `FuelData:GetFuelData`, with the table values
from `protocol/forge.md` as fallback.

## Unverified

- Whether `InteractEvent` with no arguments is the correct open request.
- Whether `TakeResult`, `AddInput`, `AddFuel` require the forge to be open, the
  player to be in range, or fuel/temperature to be valid.
- Whether the server clips `AddInput` count to the owned amount or accepts
  negative / unknown values (test matrix in `protocol/forge.md`).
- Whether `AddFuel` consumes one unit per call.
