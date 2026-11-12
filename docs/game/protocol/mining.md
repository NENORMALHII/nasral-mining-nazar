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

`Ores.names()` builds the list from `Resources` (`Natural`), sorted by `BasePrice`.
The UI stores selected indices; `Ores.isSelected(name)` maps them to names.
Empty selection means nothing is selected.

## Target selection (no prediction)

There is no seed hashing and no depth heuristic. `Ores.nearest(position, radius)`:

- converts the player position to block coordinates (`Blocks.toBlock`);
- scans only the `±ceil(radius/7)` cube around the player with
  `mine:FindFirstChild("x,y,z")`, instead of iterating every child of `Workspace.Mine`;
- skips blocks that are not selected, invalid (world, `Dug`, `MinePosition`) or out of range;
- score: `BasePrice * 1000 - distance`, so the most valuable block wins and distance breaks ties;
- `Ores.ignore(block)` skips a failed block for 5 s.

Radius is `Mining.reach() = Pick.MaxDistance - 4` (21 studs).

## Movement

Mining does not move the character. The server accepts any block within `Pick.MaxDistance`,
so teleporting to the block centre was unnecessary and caused `BlockMinedEvent` rejections.

- Farm mines only blocks already in reach; otherwise it digs the block under the feet.
- After a shaft block breaks the character falls naturally (`Movement.waitLanded`).
- Loot teleports use `Movement.jump` (`PivotTo` directly, no tween).
- Every teleport sets `Movement.lastMoveAt`; Farm waits `moveCooldown` (0.5 s) before the next
  `BlockEvent`, so mining never starts in the same tick as a position change.
- `HumanoidRootPart` is anchored only during the `BlockEvent`/`BlockMinedEvent` window.

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
4. removes collected drops and moves to the next.

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
