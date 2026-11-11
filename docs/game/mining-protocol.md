# Mining protocol (from `docs/game/minescript.lua`)

Client: `Workspace.<player>.Pick.MineScript` (LocalScript inside the pickaxe tool).
Source of truth: `docs/game/minescript.lua`.
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
Empty selection falls back to `BasePrice >= Config.minOreValue`. Tier gating is not used:
pickaxe tier changes mine time, not ore access.
