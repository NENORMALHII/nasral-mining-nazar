# Mining protocol (from `docs/game/decompiled/minescript.lua`)

Client: `Workspace.<player>.Pick.MineScript` (LocalScript inside the pickaxe tool).
Source of truth: `docs/game/decompiled/minescript.lua`.
Server side is not in the place dump, so server checks below are inferred.

## Flow

1. Mouse down → `OnActivated(position)` → `StartMining()`.
2. `GetTargetMineableBlock()`:
   - raycast from screen point, max 100 studs;
   - `hit.Parent == workspace.Mine`;
   - `IsPlayerWithinRange(player, hit, MaxDistance)`, `MaxDistance = 25`;
   - `hit:GetAttribute("MinePosition")` exists;
   - `Type` exists and is not `Oil`, `Lava`, `Grass`, `Void`.
3. Extra checks in `StartMining`:
   - `Type ~= "Bedrock"` and `IsBedrock ~= true`;
   - `block:GetAttribute(ATTR_WORLD_ID) == player:GetAttribute(ATTR_WORLD_ID)`;
   - `Dug.Value` is empty or equals `player.Name`;
   - no adjacent liquid block (`IsBlockBesideLiquid`).
4. `BlockEvent:FireServer(block.Name, { dug = true })`.
5. Progress bar runs `mineTime`:
   `BaseMineTime * (100 - ToolSpeedModifier) / 100 * Resources[Type].MineTimeModifier`.
   `BaseMineTime` comes from `UpdatePickaxe.OnClientEvent`, default `10` until the first event.
6. On completion `BlockMinedEvent:FireServer({ blockName = vec3_tostring(MinePosition) })`.
7. Mouse up / target lost → `BlockEvent:FireServer(name, { dug = false })`.

## Exploit notes

- `UpdatePickaxe` is server→client only. The old `FireServer` call did nothing.
- Server receives only the block name and `dug` flag; all target validation is client-side.
  The client must still be within `MaxDistance` and stay there, because the server likely
  re-checks distance on `BlockMinedEvent`.
- `Dug` acts as a soft lock: set by the server on `dug = true`, released on `dug = false`
  or completion. Test scripts should skip blocks claimed by other players.
- Mine time must elapse before `BlockMinedEvent`, otherwise the server may drop the request.
- Teleporting into solid rock can eject the character. `PivotTo` is safe; `LinearVelocity`
  with `PlatformStand` makes the character tumble.

## Supporting modules

`ReplicatedStorage.Modules.CommonUtils` (client helpers only, no remotes):

- `IsPlayerWithinRange(player, target, range)` — compares `HumanoidRootPart.Position` with target `Position` or `Vector3`, range is `Pick.MaxDistance`.
- `RaycastFromScreenPoint(point, distance)` — `camera:ScreenPointToRay`, collision group `RAYCAST`.
- Everything else (tables, formatting, storage cost) is unrelated to mining.

`ReplicatedFirst.Util`:

- `vec3_tostring(v)` = `x .. "," .. y .. "," .. z`; block names and `MinePosition` strings are built this way.
- `POSITIONS` are unit offsets in block coordinates.
- `BASEPLATE_ALTITUDE = 7998.5`; `GetWorldCoords(x, y, z) = (61.5 + 7x, 7998.5 - 7y, -56.5 + 7z)`.

`ReplicatedStorage.Modules.Mining.Mine`:

- `BLOCK_SIZE = 7`, `MAX_MINING_RANGE = 30`, `ATTRIBUTE_RESOURCE_ID = "Resource"`, `ATTRIBUTE_MINE_POSITION = "MinePosition"`.
- `IsBlockBesideLiquid` checks 6 offsets, skipping the one with `offset.Y == 1` (below the block).
- `ConvertWorldPosToBlock` uses `Mine.WorldspaceOffset = (-31, -16, -98.5)`, which differs from `Util.GetWorldCoords`; in the live game `block.Position` is authoritative.

`ReplicatedStorage.Modules.Constants`:

- `ATTR_WORLD_ID = "WorldId"`, `ATTR_MINE_POSITION = "MinePosition"`.
- `PLACE_ID_STAGING` and `PLACE_ID_TESTING` are used by `CommonUtils.IsDevPlace`.

## Ore selection

`Ores.names()` builds the list from `Resources` (`Natural` + `BasePrice`) and falls back to
`Config.orePrices`. The UI selection stores explicit resource names in `Ores.setSelected`.
Default selection is every ore with `BasePrice > 0`. The uilib selection callback is not
used; `Ores.isSelected` polls `selection.getSelected()` directly. Target choice is by highest
price first, then distance. Tier gating is not used: pickaxe tier changes mine time, not ore
access.

## Movement

Anchored tween is the reliable option for this character:

1. `Humanoid.PlatformStand = true`.
2. `HumanoidRootPart.Anchored = true`.
3. `TweenService:Create(root, TweenInfo.new(distance / speed, Linear), { CFrame = CFrame.new(target) })`.
4. Wait for the tween, then unanchor and clear `PlatformStand`.
5. Hold the root anchored while mining so distance checks keep passing.

`AlignPosition`/`LinearVelocity` fight the humanoid and cause tumbling.

## Client modes

`src/main.lua` uses a `Mode` class. Two instances, one per category:

- `FarmMode` — picks the highest-price ore (distance breaks ties), moves, mines, collects `Drops`.
- `MushroomMode` — finds the nearest `HarvestableNode`, moves, fires `InteractEvent`.

Only one mode runs at a time. UI: `Category` dropdown + `Enabled` toggle.
Hotkeys: `F1` farm, `F2` mushrooms. Movement: `Instant move` toggle and `Tween speed` slider.

## Instant loot

`Loot.collectAll` teleports the character to every `Workspace.Drops` child inside `lootRange`,
nearest first, waits `lootDwell` per drop so the server sees the touch, and marks the drop
ignored for 10 s. Always on: runs at the start of every farm tick and right after a successful
mine. All natural resources, including `Dirt`, `Stone` and `Coal`, are present in the ore selection
and selected by default. The shaft fallback still digs straight down when nothing better is in
range.

## Downward strategy and seed predictor

Mine generation code is server-side and missing from the place dump. `Predictor` therefore:

- reads any attribute whose name contains `seed` on `Workspace`, `Workspace.Mine` or
  `ReplicatedStorage`; falls back to `w<WorldId>`;
- converts world position to block coordinates with the `Util.GetBlockCoords` formula;
- hashes seed + block coordinates with `bit32.bxor` for deterministic tie-breaking.

Target score: `BasePrice + max(0, blockY - playerBlockY) * depthWeight + hash / 1000`.
So deeper ores win, and the route is stable for the same seed.
If no selected ore is in range, Farm digs the block below the player (`Dig down` toggle).
`Mining.approach` returns a point only inside an empty block cell next to the ore; there is no
fallback above the ore. `Mining.inCell` checks a 1.5-stud box around the root against
`Workspace.Mine` with `GetPartBoundsInBox`; no overlap means the character is between blocks.
Unreachable ores are ignored and the mode falls back to `Dig down`.

Exact prediction requires the server generation script or the real seed attribute name.

## Stats used by the bot

From `docs/game/decompiled/tools-pickaxes.lua`:

- `BaseMineTime` — real wait time for the equipped pickaxe, resolved through the tool's
  `ToolClass` attribute (fallback: tool name) and also updated from `UpdatePickaxe`.
- `Tier`, `InstaMine`, `DoubleDropChance` — informational; tier does not gate ore access.

From `docs/game/data/player-stats.txt` (LocalPlayer attributes):

- `ToolSpeedModifier` — reduces mine time: `base * (100 - value) / 100`.
- `WorldId` — must match the block's `WorldId` or the server rejects the block.
- `Luck`, `DoubleDropChance`, `WalkSpeed` — not used by the bot.

Wait time (bot formula, updated for server tolerance):

```lua
mineTime   = BaseMineTime * (100 - ToolSpeedModifier) / 100 * MineTimeModifier
preSwing   = random(0.03 .. 0.10)  -- before BlockEvent (human reaction)
swing      = random(0.01 .. 0.05)  -- after BlockEvent (animation wind-up)
jitter     = random(0.03 .. 0.12)  -- per-block variance
safety     = 0.15 + ping * 1.5     -- ping-dependent buffer
ping       = GetNetworkPing()      -- RTT, rolling 8-sample min
waitTime   = mineTime + safety + jitter
```

Total time from `BlockEvent` to `BlockMinedEvent`: `preSwing + swing + waitTime`.

Characteristic acquisition order:

1. `BaseMineTime` — server-authoritative from `UpdatePickaxe.OnClientEvent`. Bot waits up to
   `mineWaitForServer` (1.5 s) after equipping a new tool for the event. Falls back to
   `Tools.Pickaxes[key].BaseMineTime`, then `Config.defaultMineTime`.
2. `ToolSpeedModifier` — re-read from `LocalPlayer` attributes on every mine (buffs change it).
3. `MineTimeModifier` — from `Resources[typeOf(block)]`.
4. Handle buffs are NOT added to mine time — the server already folds them into `ToolSpeedModifier`.

Why rejections happen and how the new algorithm addresses them:

| Cause | Fix |
|---|---|
| `BlockMinedEvent` too early after `BlockEvent` | `waitTime = mineTime + safety + jitter` always exceeds server-expected time |
| Network lag spikes | `safety` scales with rolling min ping (`0.15 + ping * 1.5`) |
| Predictable timing | `preSwing` + `swing` + `jitter` add human-like micro-delays |
| Stale `BaseMineTime` from table | Server value waits on equip, takes priority over table |
| Stale `ToolSpeedModifier` | Re-read from player attributes every mine |
| Cancel sent too late | `mineRejectGrace` increased to 0.8 s, poll interval 0.02 s |

The client fires `BlockEvent`, waits `preSwing + swing + waitTime`, then fires `BlockMinedEvent`.
Server validates that elapsed time >= expected `mineTime` (with its own tolerance).
If the bot finishes too early, the server rejects with "server rejected".

Position formula (same as `ReplicatedFirst.Util`):

```
block  -> world: (61.5 + 7x, 7998.5 - 7y, -56.5 + 7z)
world  -> block: (floor((X - 61.5)/7 + 0.5),
                  -floor((Y - 7998.5)/7 + 0.5),
                  floor((Z + 56.5)/7 + 0.5))
```

The stand point is the center of an empty neighbouring cell with at least 3 solid neighbours
and `Y >= 1`, so the character stays in a pit inside the mine.

## Pickaxe handle detection

`Modules.Tools.ToolHandles` is loaded as `Game.Handles`. `Mining.handleName` resolves the handle:

1. attribute `WoodMaterial` (from `Constants.ATTR_TOOL_WOOD_MATERIAL`);
2. attribute `Handle` or `Wood`;
3. a `StringValue` descendant whose name contains `wood` or `handle`;
4. handle name contained in the tool name.

`Mining.handleInfo` returns the handle entry and its name. The handle only affects buffs
(`SpeedModifier`, `LuckModifier`, `DoubleDropChanceModifier`, etc.). Mine time still uses
`ToolSpeedModifier`, which the server already folds buffs into, so the bot must not add the
handle bonus twice.

## Drops (from `docs/game/instructions/block-drops.md`)

Drops live in `workspace.TargetFilter`, one model per broken block, named `{BlockName}_Drop`.
Inside there is a part (block name or any `BasePart`), a `DropScript`, and under it a
`StringValue` named `Player` — the player who broke the block.

`Loot.collectAll` only picks drops where `DropScript.Player.Value` matches `LocalPlayer`
(instance, name, user id or string). Drops are cached in `Loot.pending` by `Loot.sync` and stay
there until picked, even if they move or end up above the mine. Each drop gets three attempts,
the part position is re-read every attempt, and there is no distance limit. Runs after `lootSpawnWait` (0.35 s) so the drop has time to spawn; the character
is not teleported into the block instantly.

## Surface (first layer)

While the player's block Y is `<= surfaceY` (-1, meaning the character stands on top of the
first block layer), Farm skips the empty-cell calculation and breaks exactly the block below.
Once the character drops into the first hole (Y >= 0), normal shaft logic takes over.

`Dig down` never uses `Mining.approach` or `Mining.inCell`: the character is already above the
block, so it anchors in place and mines the block below. That keeps the shaft going instead of
silently skipping every deep block.

Excluded ores are not skipped when they block the shaft: if the block directly below is not in
the ore selection, Farm clears it (`clear path`) before choosing a distant selected ore.

## Digging position

The bot always moves into the centre of the block it mines (`Movement.to(block.Position)`),
holds `HumanoidRootPart` anchored during `BlockEvent`/`BlockMinedEvent`, then releases. No
neighbour-cell heuristics and no `GetPartBoundsInBox` checks are used anymore: they were the main
source of freezes and of the bot leaving the shaft.

## Loot priority

Loot order:

- `{BlockName}_Drop` → resource name by stripping `_Drop`;
- only drops whose resource is selected in the UI are collected;
- higher `BasePrice` first, ties by distance.

`Loot.collectAll` sorts every pass with this key before teleporting.

## Loot-first rule

Farm does not mine while any own selected drop exists:

1. `Loot.sync()` fills `Loot.pending` with own selected drops from `workspace.TargetFilter`.
2. `collectLoot` runs up to 6 rounds of `Loot.collectAll`, 0.1 s apart.
3. If `Loot.count()` is still above zero, the tick ends and mining waits; the next tick retries.
4. Mining resumes only when `Loot.count() == 0`.

## Pickaxe and handle detection (current)

`Mining.pickaxeInfo` tries, in order:

1. attribute `ToolClass` (`Constants.ATTR_TOOL_TYPE`);
2. tool name;
3. any tool attribute value that matches a key in `Tools.Pickaxes`;
4. any `StringValue` descendant value that matches a key;
5. `Head` part material + color matching a pickaxe definition.

`Mining.handleName` tries:

1. attribute `WoodMaterial`;
2. attributes `Handle`, `Wood`;
3. any attribute or `StringValue` value matching a key in `Tools.ToolHandles`;
4. handle name contained in the tool name;
5. `Handle` part color matching a handle definition.

Mine time remains `BaseMineTime * (100 - ToolSpeedModifier) / 100 * MineTimeModifier`, then
`+ 0.05 + ping * 2 + random(0.02..0.09)`. Handles are not added again: the server already folds
their buffs into `ToolSpeedModifier`.

## Cross-check: Delta decompile

`decompiled/local-pickaxe-mining.lua` is the same `MineScript` decompiled by Delta. It confirms:

- start `BlockEvent:FireServer(block.Name, { dug = true })`;
- finish `BlockMinedEvent:FireServer({ blockName = vec3_tostring(MinePosition) })`;
- cancel `BlockEvent:FireServer(vec3_tostring(MinePosition), { dug = false })` — the cancel argument
  is `MinePosition`, not `block.Name`;
- mine time `base * (100 - ToolSpeedModifier)/100 * MineTimeModifier`, with client fallback base `10`
  until the first `UpdatePickaxe`;
- `MaxDistance` is read once on equip;
- no extra validation beyond type, range, `MinePosition`, world id, `Dug`, liquid.

The bot sends the cancel with `MinePosition` and compares `WorldId` strictly (`tostring` both sides).


## Stat sources

Only two numbers change the mine wait:

- `BaseMineTime` — sent by the server in `UpdatePickaxe` (`Players.<player>.Backpack.Pick.UpdatePickaxe`).
  Never call `FireServer` on it. Client fallback before the first event is `10`.
- `ToolSpeedModifier` — attribute of `LocalPlayer`, already includes pickaxe tier, handle buffs and upgrades.

The pickaxe tool instance is named `Pick`, not `Stone Pickaxe`. The real type and handle are in
attributes listed by `Modules.Inventory.Backpack`:

```lua
local v_u_7 = {
    v_u_3.ATTR_ITEM_COUNT,
    v_u_3.ATTR_TOOL_MATERIAL,        -- pickaxe head material
    v_u_3.ATTR_TOOL_WOOD_MATERIAL,   -- handle material
    v_u_3.ATTR_TOOL_RESOURCE_TYPE,
}
```

Detection order in `src/main.lua`:

| Value | Sources |
|---|---|
| pickaxe | `ATTR_TOOL_MATERIAL` (fuzzy), tool name, `Head` part material + color, tooltip text |
| handle | `ATTR_TOOL_WOOD_MATERIAL` only (fuzzy), tooltip text, `Handle` part color + material |

Attribute matching normalizes names: lowercase, drops `pickaxe`, `pick`, `axe`, `wood`, `wooden`,
`handle`, removes punctuation. So `Material = "Stone"` maps to `Stone Pickaxe` and
`WoodMaterial = "Oak Wood"` maps to `Oak`.

Important: `Stone` is both a legitimate handle and the head material of `Stone Pickaxe`. A blind
scan of every tool attribute therefore misidentifies the handle. Handles are read only from
`ATTR_TOOL_WOOD_MATERIAL` (plus tooltip and part color), never from `Material`.

Tooltip fallback: `Mining.tooltipText` reads `Tool.ToolTip`, tries the game's
`TooltipBuilder`/`Backpack.Tooltip`/`NativeTooltip` modules, and scans visible `Tooltip` frames.
Any returned table/string is flattened and searched for a `Tools.Pickaxes` key and for
`"<handle> handle"`/`"<handle> wood"` phrases. Results are cached per tool signature.

Base time preference: server `UpdatePickaxe` value, then `Tools.Pickaxes[key].BaseMineTime`,
then `Config.defaultMineTime`. The bot forces one unequip/equip after binding so the server event
is received, waits up to 6 heartbeats, and logs
`pickaxe ready base=... source=server|table|default handle=...`.
