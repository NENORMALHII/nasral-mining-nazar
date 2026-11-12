# Epic Mining 2 — white-hat client toolkit

Admin of Epic Mining 2. White hacking: find vulnerabilities with client scripts, prove them, then close the holes.
Everything runs client-side in an executor.

- Wiki: https://epicmining2.fandom.com/wiki/Epic_Mining_2_Wiki
- Admin panel spec: `docs/admin-panel-tz.md`
- Game research index: `docs/game/README.md`

## Docs navigation

Read `docs/game/README.md` first. It maps every research file.

```
docs/game/
├─ README.md                index and file table
├─ dumptree.txt             client instance tree, generated from the place
├─ probe-output.txt         UpdatePickaxe probe log (Lynx)
├─ decompiled/              verbatim decompiled scripts, do not rewrite them
├─ protocol/                our analysis, safe to edit
├─ instructions/            short interaction notes, safe to edit
└─ data/                    runtime value dumps
```

Rules:

- `decompiled/` is source of truth. Never edit or reformat these files; keep the decompiler header.
- `protocol/` and `instructions/` are hand-written notes. Update them when behaviour changes.
- `data/` holds raw runtime values. Keep the original format.
- New decompiled script: `decompiled/<module-name>.lua`, kebab-case, paths documented in `docs/game/README.md`.
- New note: `instructions/<topic>.md` or `protocol/<topic>.md`, kebab-case.
- Do not move files without updating `docs/game/README.md` and this file.
- The original place dump `place-20741661.rbxl` is not in the repository; `dumptree.txt` is the surviving tree.

## Layout

```
src/main.lua              entry point, modes + uilib window
src/tools/dump_tree.lua   prints client instance tree
src/tools/probe.lua       logs UpdatePickaxe args / decompiles MineScript
vendor/uilib/             third-party UI library (source.lua, example.lua)
docs/                     specs and reverse-engineering artifacts
legacy/                   old scripts kept for reference
```

## Conventions

- Luau, simple and minimal. No globals, no speculative abstractions.
- `pcall` around every long-running loop.
- Cross-cutting code as local module tables: `Config`, `Ping`, `Log`, `Game`, `Mode`, `Character`, `Movement`, `Blocks`, `Surface`, `Mining`, `Ores`, `Loot`, `Ui`.
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
- Mine time: `BaseMineTime * (100 - ToolSpeedModifier) / 100 * Resource.MineTimeModifier + ping margin`.
- Client-side checks: block belongs to `Workspace.Mine`, within range, has `MinePosition`, `Type` not in `Oil/Lava/Grass/Void`, not Bedrock, same world attribute, `Dug` free or ours, no adjacent liquid.
- Movement: mine without moving. Only blocks within `MaxDistance - 4` are targeted; dig straight down otherwise; if the down block fails `Mining.why` (liquid neighbour, blocked type, foreign `Dug`), jump one column sideways instead of idling. Loot teleports use `Movement.jump` and set `Movement.lastMoveAt`; a `moveCooldown` blocks the next `BlockEvent`. `Movement.settle` is only for tween moves. `LinearVelocity`/`AlignPosition` with `PlatformStand` cause tumbling.
- Drops: `workspace.TargetFilter/{BlockName}_Drop`, owner in `DropScript.Player`; collect own selected drops before mining.
- Full details: `docs/game/protocol/mining.md`.
