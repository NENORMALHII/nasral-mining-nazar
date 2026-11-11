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
