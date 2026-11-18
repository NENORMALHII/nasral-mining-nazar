# Forge (smelting)

Verified from `decompiled/forge-client.lua` (Lynx), `decompiled/fuel-data.lua`,
`dumptree.txt` and live inspection. Server scripts are hidden, so every server
check below is marked unverified.

Bot-side use of this flow: `instructions/forge-automation.md`.

## Instances

| Path | Class | Note |
|---|---|---|
| `Workspace.Forge` | Part | forge model is a part, not a model |
| `Workspace.Forge.ForgeHelper` | ModuleScript | ore table, `ProductionBar2Cost` |
| `Workspace.Forge.ForgeUpdateEvent` | RemoteEvent | every forge action, both directions |
| `Workspace.Forge.ToggleForgeEvent` | RemoteEvent | open (server→client) / close (client→server) |
| `Workspace.Forge.Interact.InteractEvent` | RemoteEvent | generic interact prompt |
| `PlayerGui.Forge.Container.Content.ForgeClient` | LocalScript | decompiled, UI + actions |
| `PlayerGui.Forge.Container.Content.FuelFrame.InitScript` | LocalScript | fuel buttons, not decompiled |
| `PlayerGui.Forge.Container.CloseButton` | TextButton | fires `ToggleForgeEvent` |

## Client → server

`ForgeUpdateEvent:FireServer(action, payload)`

| action | payload | Line |
|---|---|---|
| `"AddInput"` | `{ oreName, count }` | 36 |
| `"TakeResult"` | none | 291 |
| `"BuyProductionBar"` | none | 303, 321, 338 |
| `"AddFuel"` | fuel name | `FuelFrame.InitScript`, not decompiled |

`ToggleForgeEvent:FireServer()` — close request; the client also hides the GUI
locally and resets `LocalPlayer.BackpackVisible` itself (362-364).

## Server → client

`ForgeUpdateEvent.OnClientEvent` sends one table (267-277):

```
{
  PlayerForgeData = {
    Input  = { Type, Amount, BarCount, ProductionBars[n] = { Current, Total } },
    Output = { Type, Amount },
  },
  SourceData = {
    Temperature, MinTemperature, MaxTemperature,
    Fuel = { Amount, BurnTimeRemaining, TotalBurnTime },
  },
}
```

Only the fields the client reads are listed; extra fields may exist.

## Client-side only checks

Every guard around a forge action lives in `ForgeClient`. Nothing is checked
again on the client before `FireServer`.

| Guard | Location | Server check |
|---|---|---|
| `_G.inv.Resources[oreName] > 0` before `AddInput` | 32 | unverified |
| `count = LeftShift and _G.inv.Resources[oreName] or 1` | 35 | unverified |
| `TakeResult` blocked only when `_G.inv.CurrentSize == _G.inv.MaxSize` | 285 | unverified |
| `BuyProductionBar` for bar 2 needs `leaderstats.Money.Value >= 4000` | 302 | unverified |
| mixing results prevented only by hiding other ore buttons while `Input.Amount > 0` | 210-225 | unverified |
| `AddFuel` list from `FuelData.GetAllFuels()` | `InitScript` | unverified |

No client guard checks distance to the forge, being on the surface, current
temperature, remaining fuel, or that the ore is in the input list at all.

## Ore table (`ForgeHelper.GetOreData`)

| Ore | MeltingPoint °C | SmeltTime s | Result |
|---|---|---|---|
| Copper Ore | 1085 | 40 | Copper Bar |
| Iron Ore | 1438 | 60 | Iron Bar |
| Silver Ore | 962 | 40 | Silver Bar |
| Gold Ore | 1064 | 50 | Gold Bar |
| Promethium Ore | 1042 | 60 | Promethium Bar |
| Mithril Ore | 1800 | 80 | Mithril Bar |
| Malachite Ore | 1085 (Studio 20) | 80 (Studio 5) | Malachite Bar |
| Azurite Ore | 1085 (Studio 20) | 80 (Studio 5) | Azurite Bar |

`ProductionBar2Cost = 4000`. Bars are `NotPurchasable = true`,
`AppearsInShop = false` (`resourceslist.lua`).

## Fuel (`FuelData.Fuels`, `BurnTime` s)

| Fuel | BurnTime |
|---|---|
| Coal | 70 |
| Log | 30 |
| Plank | 30 |
| Oil Barrel | 100 |
| Lava Barrel | 130 |
| Ignis | 110 |

`GetFuelData` maps any `"* Log"` to `Log` and `"* Plank"` to `Plank`.

## Test matrix

Run `src/tools/forge_probe.lua` first for the live table and one payload, then
each case below from an executor while watching `PlayerForgeData` and the
inventory count.

| # | Fire | Check |
|---|---|---|
| 1 | `AddInput { name, 1000000 }` | server must reject or clamp to owned count |
| 2 | `AddInput { name, 0 }`, `{ name, -1 }`, `{ name, 0.5 }` | no free input, no negative decrement |
| 3 | `AddInput` unknown resource name | rejected, no error item |
| 4 | `AddInput` same ore twice before the first smelt ends | no input loss, no double output |
| 5 | `AddInput` second ore with different `Result` | must be refused while input is full |
| 6 | `TakeResult` twice in one frame | bar added once |
| 7 | `BuyProductionBar` with `Money < 4000` | purchase refused, `BarCount` unchanged |
| 8 | `BuyProductionBar` for bars 3/4 without the dev product | purchase refused |
| 9 | `AddFuel "Nonexistent"` / fuel not in inventory | no burn time gained |
| 10 | `AddInput` underground / far from `Workspace.Forge` | refused if range is enforced |
| 11 | `Interact.InteractEvent:FireServer()` underground | prompt only, no smelt |

Pass condition for the server: inventory is decremented exactly by the accepted
count, `count` is clamped to what the player owns, output is one bar per smelt
tick, and every action is re-validated server-side.
