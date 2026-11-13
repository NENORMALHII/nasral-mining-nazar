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

## protocol/

| File | Content |
|---|---|
| `mining.md` | mining flow, checks, drops, loot priority, positions, stats |

## instructions/

| File | Content |
|---|---|
| `block-drops.md` | `workspace.TargetFilter`, `{BlockName}_Drop`, `DropScript.Player` |
| `sell.md` | `SellResourceFunction:InvokeServer(resource, count)` and resource counts |
| `forge-remotes.md` | `ForgeUpdateEvent` actions |
| `getinventory.lua` | `InventoriesClient.GetInventory()` dump, source of resource counts |
| `settings.md` | saved UI options (`nm2/settings.json`) and render toggle |

## data/

| File | Content |
|---|---|
| `player-stats.txt` | default `LocalPlayer` attributes |
