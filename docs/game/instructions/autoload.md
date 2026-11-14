# Save slot loading

`ReplicatedStorage.LoadGameEvent` [RemoteEvent] (see `docs/game/dumptree.txt`). The
game fires it from the save-slot menu before the world is loaded.

Captured client call (slot 1):

```lua
local args = {
    1
}
game:GetService("ReplicatedStorage"):WaitForChild("LoadGameEvent"):FireServer(unpack(args))
```

- `args[1]` — slot number, 1..3. The bot sends it as a plain number
  (`AutoLoad.fire`), which is the same single-value form as `unpack({ 1 })`.
- Related remotes in the same folder: `NewGameEvent`, `StartGameForPlayerEvent`.

## Bot behaviour

`AutoLoad` (`src/main.lua`, after the `Rejoin` block) drives it from the
Auto load tab:

- `Save slot` dropdown (1/2/3) → `autoloadSlot`; the registry clamps it with
  `max = #AutoLoad.slots`, so nothing outside 1..3 reaches the remote.
- `Autoload` toggle → `autoloadEnabled`, restored by `Settings.restore()` before the UI,
  so the bot answers the menu on every execution, including after an auto rejoin.
- The loop fires `LoadGameEvent(slot)` every `Config.autoloadDelay = 1` s and stops when
  `LocalPlayer` attribute `FullyLoaded` is `true`, or after `Config.autoloadTries = 10`
  shots. The cap exists because a wrong "not loaded" reading must never keep reloading a
  running world.
- `AutoLoad.state` also reads attribute `Profile` and logs it as the loaded slot.

Unverified in game: that `FullyLoaded` is the load-finish flag and that `Profile` is the
slot index (both from `docs/game/data/player-stats.txt`). Each shot is logged as
`autoload: firing slot <n> (loaded=<value>)`, so the console shows the real attribute
state; adjust `Config.autoloadLoadedAttr` / `Config.autoloadProfileAttr` if it differs.
