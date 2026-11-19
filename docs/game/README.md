# Game research index

Reverse-engineering artifacts for Epic Mining 2.

## Tree

```
docs/game/
├─ README.md
├─ dumptree.txt                 client instance tree (17 943 lines)
├─ probe-output.txt             UpdatePickaxe probe log from Lynx
├─ decompiled/                  verbatim decompiled ModuleScripts/LocalScripts
├─ protocol/                    our analysis of client-server behaviour
├─ instructions/                short interaction notes and remote examples
└─ data/                        runtime value dumps
```

## decompiled/

| File | Script path |
|---|---|
| `minescript.lua` | `Workspace.<player>.Pick.MineScript` (Lynx) |
| `local-pickaxe-mining.lua` | same script, Delta decompile, confirms protocol |
| `mining-mine.lua` | `ReplicatedStorage.Modules.Mining.Mine` |
| `mining-types.lua` | `ReplicatedStorage.Modules.Mining.Types` |
| `commonutils.lua` | `ReplicatedStorage.Modules.CommonUtils` |
| `weightedrandom.lua` | `ReplicatedStorage.Modules.WeightedRandom` |
| `replicatedfirst-util.lua` | `ReplicatedFirst.Util` |
| `tools-pickaxes.lua` | `ReplicatedStorage.Modules.Tools.Pickaxes` |
| `tools-toolhandles.lua` | `ReplicatedStorage.Modules.Tools.ToolHandles` |
| `forge-client.lua` | `PlayerGui.Forge.Container.Content.ForgeClient` |
| `fuel-data.lua` | `ReplicatedStorage.Scripts.FuelData` |
| `inventory-backpack.lua` | `ReplicatedStorage.Modules.Inventory.Backpack` (Delta) |
| `resourceslist.lua` | `ReplicatedStorage.Modules.Resources` |
| `intro-script.lua` | `PlayerGui.Intro.Intro` (Delta) |

## protocol/

| File | Content |
|---|---|
| `mining.md` | mining flow, checks, drops, loot priority, positions, stats |
| `forge.md` | forge remotes, client-only checks, ore/fuel tables, exploit test matrix |

## instructions/

| File | Content |
|---|---|
| `block-drops.md` | `workspace.TargetFilter`, `{BlockName}_Drop`, `DropScript.Player` |
| `sell.md` | `SellResourceFunction:InvokeServer(resource, count)` and resource counts |
| `experimental.md` | Experimental "mine 5 blocks (3x3)" batch claim and its protocol |
| `forge-remotes.md` | `ForgeUpdateEvent` actions and payloads |
| `forge-instruction.md` | raw live-inspection paste for the forge, folded into `protocol/forge.md` |
| `forge-automation.md` | surface-trip sequence: take result, add input, add fuel, then sell |
| `getinventory.lua` | `InventoriesClient.GetInventory()` dump, source of resource counts |
| `settings.md` | saved UI options (`nm2/settings.json`) and render toggle |
| `anti-afk.md` | `Player.Idled` and virtual-input reset for the 20-minute kick |
| `autoload.md` | `LoadGameEvent(slot)` save-slot loading, `FullyLoaded`/`Profile` assumptions |

## data/

| File | Content |
|---|---|
| `player-stats.txt` | default `LocalPlayer` attributes |
