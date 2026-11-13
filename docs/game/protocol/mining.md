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

## Block coordinates

- `Blocks.toBlock(position)` / `Blocks.worldOf(cell)` use the `Util.GetWorldCoords`
  formula (`BASE_X = 61.5`, `BASE_ALTITUDE = 7998.5`, `BASE_Z = -56.5`) plus
  `Blocks.offset`.
- `Blocks.calibrate()` measures the offset from the two blocks nearest to the field centre
  (`offset = MinePosition - rawBlock(block.Position)`) and accepts it only when both agree;
  otherwise the offset is kept at zero and the measurement is retried after the 5 s gate.
- `Blocks.standPoint(cell) = worldOf(cell) + (0, 0.5, 0)` — cell centre, so a teleport
  never lands on a half-cell boundary where `rawBlock` could round to a neighbour.
- `Mining.besideLiquid(block)` and Farm's liquid check share the same 6-offset
  `IsBlockBesideLiquid` logic (the block below is skipped).

`ReplicatedStorage.Modules.Constants`:

- `ATTR_WORLD_ID = "WorldId"`, `ATTR_MINE_POSITION = "MinePosition"`.
- `PLACE_ID_STAGING` and `PLACE_ID_TESTING` are used by `CommonUtils.IsDevPlace`.

## Ore selection

`Ores.names()` builds the list from `Resources` (`Natural`), sorted by `BasePrice`.
The UI stores selected indices; `Ores.isSelected(name)` maps them to names.
Empty selection means nothing is selected.

## Target selection (no prediction)

There is no seed hashing and no depth heuristic. `Ores.nearest(position, radius)`:

- converts the player position to block coordinates (`Blocks.toBlock`);
- scans only the `±ceil(radius/7)` cube around the player with
  `mine:FindFirstChild(vec3ToString(cell))`, instead of iterating every child of
  `Workspace.Mine`;
- skips blocks that are not selected, invalid (world, `Dug`, `MinePosition`) or out of range;
- collects the cheap candidates, sorts them by `BasePrice * 1000 - distance`, then calls
  the expensive `Mining.why` lazily only until one candidate passes (liquid checks no
  longer waste a full tick per rejected ore);
- `Ores.ignore(block)` skips a failed block for 5 s.

Radius is `Mining.reach() = Pick.MaxDistance - 4` (21 studs).

## Movement

Mining does not move the character. The server accepts any block within `Pick.MaxDistance`,
so teleporting to the block centre was unnecessary and caused `BlockMinedEvent` rejections.

- Farm mines only blocks already in reach; otherwise it digs the block under the feet.
- After a shaft block breaks the character falls naturally (`Movement.waitLanded`).
- All movement goes through `Movement.to`: `Movement.jump` is only an alias. With
  `Config.instantMove = false` (default) the root is anchored and tweened at
  `Config.tweenSpeed` for `distance / speed` seconds (clamped to 0.05..5), then settled;
  with `Config.instantMove = true` the move is a single `PivotTo`. There is no separate
  "teleport" path any more, so loot, pits, step-aside, empty field and auto-sell surface
  moves all use the same method.
- Destination buffer: after a tween (and after an instant `PivotTo`) the character stays
  anchored at the target for `Config.moveBuffer = 0.1` s before `Movement.release` resumes
  physics. Prevents sliding/falling in the same frame the move ends.
- Every move sets `Movement.lastMoveAt`; Farm waits `moveCooldown` (0.5 s) before the next
  `BlockEvent`, so mining never starts in the same tick as a position change.
- Stability: `Movement.release` zeroes `AssemblyLinearVelocity`/`AssemblyAngularVelocity`
  before un-anchoring, so tween momentum does not carry into the humanoid. Block targets use
  `Blocks.standPoint(cell)` (cell centre `+0.5` Y), never a cell boundary: a `+3.5` lift is
  exactly half a cell and `rawBlock` rounds it to the neighbouring cell. Loot drop parts
  (not cells) still use the old `Config.teleportLift = 3.5` lift.
- `HumanoidRootPart` is anchored during tweens, during the `BlockEvent`/`BlockMinedEvent`
  window, and while the `Mine` container has no blocks at all (see the empty-field rule below).
- Empty field (`Mine` has zero children): there is nothing to dig and no ground, so digging down
  can never succeed. Farm jumps once to `Config.fieldCenter` + `Config.emptyMineLift` studs, keeps
  the character anchored, and re-checks every `Config.emptyMineWait` seconds. The jump only fires
  again when the character is more than 4 studs from that point, so the loop no longer teleports
  and falls every tick. `Movement.releaseHold()` runs on the first tick that sees blocks again.
- Liquid floor is special-cased: when `Mining.why(below)` is `liquid` or `blocked`, Farm
  never even attempts `mine(below)` (the block borders liquid and cannot break) and does not
  mine any lower ore either. It logs `floor blocked (<reason>), forcing side escape` and
  immediately runs the side escape.
- Side escape (`stepAside` in `src/main.lua`) is selection-independent: the ore selection is
  ignored, any resource is allowed when escaping. Farm searches ring by ring outwards
  (radius `1..Config.sideSearchRadius = 10`). For each ring it first tries the current layer
  (`dy = 0`), then one block UP (`dy = -1`); the floor below that up-cell is the
  current-layer side block, so this moves sideways or up, never down. Inside each ring the
  richest floor wins. The first ring with a candidate logs `step aside r=N [up] -> x,y,z`
  and teleports to `Blocks.standPoint(cell)` — the cell centre, so `Blocks.below()` on the
  next tick still points at the validated floor and not at a boundary-rounded neighbour.
  If no candidate exists inside the radius it logs
  `down-block undiggable, no side escape within N` and waits 1 s, then retries.
- Liquid escape (`escapeLiquid` in `src/main.lua`): when the bot is fully stuck in liquid,
  i.e. at least `Config.liquidStuckCount = 4` of the 5 horizontal neighbours are
  `LiquidResource` (Oil/Lava), sidestepping cannot help. Farm raises the search one block
  above the stuck cell (`cell + (0, -1, 0)`), then searches by increasing distance
  (outer loop `1..liquidSearchRange = 16`, inner loop over the shuffled 8 directions), so
  the nearest mineable block wins instead of the first direction that happens to hit.
  Blocks at the liquid level and below are never mined. On a hit it logs
  `liquid escape -> x,y,z (Type)`, checks that the cell above the block is empty and
  teleports into that cell with `Blocks.standPoint`; the next Farm tick digs it as the
  block under the feet.

## Surface pits

The mine field centre is `89.5, 7998.5, -21.5` (`Config.fieldCenter`). While the player is on
the surface (`Blocks.toBlock(root.Position).Y < surfaceDepth = 2`):

1. If the player is farther than `fieldRadius = 14` studs from the field centre horizontally,
   `Movement.jump` moves them there once and the tick ends. Pit detection only runs inside the
   field.
2. Block names are built from `MinePosition`, which can be shifted from the world formula by a
   constant. `Blocks.calibrate()` measures that offset once (see "Block coordinates").
3. `Surface.depth(mine, x, z, topY)` counts empty cells from `topY` down to the first solid
   block, capped at `surfaceMaxDepth = 10`. If no floor is found the column is outside the
   generated mine and is ignored.
4. `Surface.scan` is the single pit finder used by both the surface entry and the reset:
   it scans a `±6` block square, collects every column with `depth >= minDepth`, sorts by
   depth (deepest first, ties by distance), then runs the star check only until the first
   valid candidate.
5. `Surface.safe(mine, cell, depth)` is the teleport guard. A cell is accepted only when:
   - the cell itself is empty;
   - the floor block at `cell.Y + depth` exists in `Workspace.Mine`;
   - `Surface.star` hits solid mine blocks in **all 8** horizontal directions.

   `Surface.star` is the side "raycast" in a star pattern: for each of the 8 directions in
   `Surface.dirs` (4 straight + 4 diagonal) it walks outward up to
   `surfaceProbeDepth = 6` blocks at the floor level until a solid block is met, and counts
   the directions that hit. Requiring 8/8 rejects map edges, floating single columns and
   holes that are not surrounded by generated terrain, so a teleport target is always
   inside the generated mine.
6. `Surface.find(position)` runs the scan on the player's own layer with
   `surfaceMinDepth = 2` (normal surface column has depth 1; a one-block hole already has
   depth 2) and returns the pit cell. `Surface.resetPoint()` runs the same scan on the
   fixed surface layer `y = -1` around the field centre with `minDepth = 1` and returns
   `Blocks.worldOf(cell) + teleportLift`.
7. If the player is not above the pit, `Movement.jump` moves them to the mouth — the same
   block cell at the player's current Y — and the tick ends. The next tick the character
   drops in.
8. Above the mouth, the bot mines the block under the feet and waits to land. If there is no
   block under the feet it simply falls.

The scan is not cached: it is one small loop and the normal dig-down path handles anything
the pit cannot.

## Client modes

- `FarmMode` — loot first, then the best selected block in reach, otherwise dig straight down.
- `MushroomMode` — nearest `HarvestableNode`, moves there, fires `InteractEvent`.

## Loot

Drops are `workspace.TargetFilter/{BlockName}_Drop` models with `DropScript.Player`.
`Loot.sync` keeps own selected drops in `Loot.pending`.

`Loot.collectAll(character)` runs first on every Farm tick:

1. sorts pending drops by `BasePrice`;
2. teleports to each drop with `Movement.jump`;
3. waits `lootDwell` for the touch;
4. removes collected drops and moves to the next;
5. auto sell is independent of this loop: a 1 s watcher calls `Sell.try("watch")` even when
   no mode is running.

No radius limit, no batching: the character always goes to its own loot before mining again.

## Stats used by the bot

From `docs/game/decompiled/tools-pickaxes.lua`:

- `BaseMineTime` — real wait time for the equipped pickaxe, resolved from the
  `ATTR_TOOL_MATERIAL` attribute, then the tool name, then the `Head` part; also updated from
  `UpdatePickaxe`.
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
safety     = 0.08 + ping * 1.0     -- ping-dependent buffer
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
| Network lag spikes | `safety` scales with rolling min ping (`0.08 + ping * 1.0`) |
| Predictable timing | `preSwing` + `swing` + `jitter` add human-like micro-delays |
| Stale `BaseMineTime` from table | Server value waits on equip, takes priority over table |
| Stale `ToolSpeedModifier` | Re-read from player attributes every mine |
| Cancel sent too late | `mineRejectGrace` increased to 0.8 s, poll interval 0.02 s |

The client fires `BlockEvent`, waits `preSwing + swing + waitTime`, then fires `BlockMinedEvent`.
Server validates that elapsed time >= expected `mineTime` (with its own tolerance).
If the bot finishes too early, the server rejects with "server rejected".

Rejection streak: `Mining.rejects` counts consecutive `server rejected` results and is
zeroed by any successful break. The log line carries `streak=N`. At
`Config.maxRejects = 5` the bot sets `Mining.resetRequested`; on the next Farm tick it:

1. clears cached mapping and scan state: `Blocks.calibrated = false`,
   `Blocks.lastCalibrate = 0`, `Surface.pit = nil`, `Ores.clearCache()` (scan cell,
   cached target, ignore timers), then recalibrates. The previous `Blocks.origin` is
   kept until a stable new one is found;
2. calls `Surface.resetPoint()`: scans only the fixed surface layer `y = -1` within
   `surfaceScanRadius` of the field centre, accepts a cell only when `Surface.depth`
   says depth >= 1 (cell empty, solid floor below), re-checks the cell/floor and the 8-ray
   star, then returns `Blocks.standPoint(cell)`;
3. logs `reset point x,y,z depth=N` and `mining reset: teleport to ..., caches cleared`,
   jumps there and waits for the landing.

If no validated cell exists it logs
`mining reset: no safe point inside the mine, staying put` and does not move. The scan
never leaves the field, so the reset cannot teleport outside the map.

Position formula (same as `ReplicatedFirst.Util`):

```
block  -> world: (61.5 + 7x, 7998.5 - 7y, -56.5 + 7z)
world  -> block: (floor((X - 61.5)/7 + 0.5),
                  -floor((Y - 7998.5)/7 + 0.5),
                  floor((Z + 56.5)/7 + 0.5))
```

## Pickaxe handle detection

`Mining.detect(pickaxe)` resolves and caches both values:

- pickaxe: `ATTR_TOOL_MATERIAL` attribute, then tool name, then `Head` part material + colour
  against `Tools.Pickaxes`;
- handle: `ATTR_TOOL_WOOD_MATERIAL` attribute, then `Handle` part colour against
  `Tools.ToolHandles`.

Attribute values are normalized (`pickaxe`, `pick`, `axe`, `wood`, `handle` stripped, punctuation
removed), so `Stone` matches `Stone Pickaxe` and `Oak Wood` matches `Oak`.

`Stone` is both a handle and a pickaxe head material; handles are never read from the
`Material` attribute, only from `WoodMaterial`.

Handle buffs are not added to mine time: the server already folds them into `ToolSpeedModifier`.

## Drops (from `docs/game/instructions/block-drops.md`)

Drops live in `workspace.TargetFilter`, one model per broken block, named `{BlockName}_Drop`.
Inside there is a `BasePart`, a `DropScript`, and under it a `StringValue` named `Player` —
the player who broke the block.

`Loot.collectAll` only picks drops where `DropScript.Player.Value` matches `LocalPlayer`
(instance, name, user id or string). Drops are cached in `Loot.pending` by `Loot.sync` and stay
there until picked. The character teleports to the drop, waits for the touch, and repeats for the
next drop; `lootSpawnWait` (0.3 s) after a block breaks gives the drop time to spawn.

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

## Performance notes

- `Surface.scan` collects depth candidates once, sorts by depth/distance and runs the 8-ray
  star check lazily only until the first valid candidate.
- `Ores.nearest` collects candidates cheaply, sorts by score and calls `Mining.why` only until
  the first candidate passes, so liquid-blocked ore no longer wastes a tick and an ignore slot.
- `Mining.maxDistance()` is re-read per equip; `typeOf` is a plain attribute read.
- StreamingEnabled caveat: if `workspace.StreamingEnabled` is true, a missing client block does
  not mean the block is missing on the server. `Surface.depth` would report "no floor" and the
  star check would see a map edge where there is none. The bot assumes streaming is off.
