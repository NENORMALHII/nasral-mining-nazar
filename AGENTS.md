# Epic Mining 2 — white-hat client toolkit

Admin of Epic Mining 2. White hacking: find vulnerabilities with client scripts, prove them, then close the holes.
Everything runs client-side in an executor.

- Wiki: https://epicmining2.fandom.com/wiki/Epic_Mining_2_Wiki
- Admin panel spec: `docs/admin-panel-tz.md`
- Game tree: `docs/game/dumptree.txt`
- Place dump: `docs/game/place-20741661.rbxl`
- Decompiled pickaxe client: `docs/game/minescript.lua`
- Mining protocol notes: `docs/game/mining-protocol.md`

## Layout

```
src/main.lua              entry point, managers + uilib window
src/tools/dump_tree.lua   prints client instance tree
src/tools/probe.lua       logs UpdatePickaxe args / decompiles MineScript
vendor/uilib/             third-party UI library (source.lua, example.lua)
docs/                     specs and reverse-engineering artifacts
docs/game/                place dump, decompiled scripts, probe output
legacy/                   old scripts kept for reference
```

## Conventions

- Luau, simple and minimal. No globals, no speculative abstractions.
- `pcall` around every long-running loop.
- Cross-cutting code as local module tables: `Config`, `Manager`, `Character`, `Mining`, `Target`, `Ores`, `Ui`.
- Lua files `snake_case.lua`, docs `kebab-case.md`, dumps lowercase.
- UI only through `vendor/uilib`. Load it with `readfile`, fall back to the upstream URL.
- Paths in scripts are relative to the repo root.
- Read before write, minimal diff, no unrelated refactors.

## Mining protocol

- Blocks: children of `Workspace.Mine`, named `"x,y,z"`. Have `Type` [StringValue], `Dug` [StringValue], attribute `MinePosition` [Vector3].
- Range: `Pick.MaxDistance` [IntValue] = 25.
- Start: `ReplicatedStorage.BlockEvent:FireServer(block.Name, { dug = true })`.
- Complete: `ReplicatedStorage.BlockMinedEvent:FireServer({ blockName = "x,y,z" })`.
- Cancel: `BlockEvent:FireServer("x,y,z", { dug = false })`.
- `UpdatePickaxe` is server→client only. It carries `BaseMineTime`. Never call `FireServer` on it.
- Mine time: `BaseMineTime * (100 - ToolSpeedModifier) / 100 * Resource.MineTimeModifier`.
- Client-side checks: block belongs to `Workspace.Mine`, within range, has `MinePosition`, `Type` not in `Oil/Lava/Grass/Void`, not Bedrock, same world attribute, `Dug` free or ours, no adjacent liquid.
- `LinearVelocity` + `PlatformStand` on the character causes physics convulsions. Use `PivotTo` for test movement.
