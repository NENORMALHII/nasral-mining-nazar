# Saved settings

`src/main.lua` persists UI options with the standard executor filesystem API:
`writefile`, `readfile`, optional `isfile` / `makefolder` (each guarded with
`type(...) == "function"` and `pcall`), JSON via `HttpService:JSONEncode` / `JSONDecode`.

- Path: `nm2/settings.json` (`Settings.path`); if writing there fails, the bot retries the
  flat `nm2_settings.json` (`Settings.fallbackPath`).
- `isfile` is optional. When the executor does not expose it, the read itself is the existence
  check (`pcall(readfile, path)`), so executors with only `readfile`/`writefile` still work.
- Folder `nm2` is created with `makefolder` when the executor exposes it.
- `Settings.load()` reads the file once; missing file or bad JSON falls back to defaults.
- `Settings.persist()` writes only when the encoded JSON differs from the last written text
  (`Settings.lastJson`), and writes **only registered keys**: leftovers from older builds are
  dropped from the file instead of lingering as if they were still saved.

## Architecture: typed registry

Every saved option is one `Settings.define(key, spec)` entry in the "Saved options" block,
placed after the runtime modules and before the UI:

```lua
Settings.define("instantMove", {
    kind = "bool", default = Config.instantMove,
    apply = function(value) Config.instantMove = value end,
})
```

- `kind` — `bool`, `number` (`min`, `max`, optional `round`) or `names` (array of resource
  names). `Settings.normalize` is the single validation point.
- `default` — used when the file has no entry, or the stored value is unusable.
  For `names`, `"all"` means the whole current option list, `"none"` an empty list.
- `apply` — restore hook. `Settings.restore()` runs every hook once in the bootstrap block
  before the UI exists, so no option needs its own `if saved...` block.

The UI never touches the file: it calls `Settings.read(key)` for the widget default and
`Settings.write(key, value)` in the callback (write normalizes, stores, persists and applies).
Adding an option is one registry line, one `read`, one `write`.

Selections are special because widgets work with indexes while the catalogue order is not
stable across sessions:

- `Settings.selection(key, legacyKey, names)` returns the index list for a widget;
  `Settings.bindSelection(key, names, widget)` registers the widget and
  `Settings.flushSelections()` (called every 0.5 s from its own timer) stores the current
  names. The timer is separate from the 2 s stats readout: a failing stat cannot stop the
  options from being saved.
- Names that no longer exist are dropped. If a saved list has entries but none matches, the
  option default wins (`all` for ores, `none` for the sell list). An intentionally empty list
  stays empty.
- Older files with index arrays (`ores`, `sellSelected`) are still read once: they are clamped
  to the current list size and used only when the name keys are absent.
- `Ores.names()` and `Sell.names()` sort by price and then by name, so ties do not reorder the
  catalogue between sessions.

## Saved keys

| Key | Kind | UI control | Restore hook |
|---|---|---|---|
| `mode` | number (1..2) | Category dropdown | — |
| `instantMove` | bool | Instant move (movement method: tween ⇄ teleport) | `Config.instantMove` |
| `tweenSpeed` | number (20..400) | Tween speed slider | `Config.tweenSpeed` |
| `oreNames` | names (`all`) | Farm ores selection | — |
| `sellEnabled` | bool | Auto sell Enabled | `Sell.enabled` |
| `sellNames` | names (`none`) | Resources to sell selection | — |
| `verboseLogs` | bool | Verbose logs | `Log.enabled` |
| `autoRejoin` | bool | Auto rejoin → Session → Auto rejoin | `Rejoin.set` |

Not saved on purpose: the Farm/Mushrooms `enabled` toggle and `Disable 3D render`
(`noRender`). Both are per-session switches that start off on every execution.

## Disable 3D render

Debug → Logs → `Disable 3D render` calls
`RunService:Set3dRenderingEnabled(not state)` inside `pcall`. With the toggle on the call is
`RunService:Set3dRenderingEnabled(false)`. Not persisted: 3D rendering is always on at startup.

## Auto rejoin

Auto rejoin tab → Session → `Auto rejoin` (`autoRejoin`). Independent of the Farm Enabled toggle.

- The watcher waits up to `Config.rejoinAttachTries = 60` s for
  `CoreGui.RobloxPromptGui`, then takes `promptOverlay` (or `WaitForChild` up to 10 s).
- `promptOverlay.ChildAdded` filters `ErrorPrompt`; the prompt may already exist when the
  toggle is turned on, so an existing `ErrorPrompt` is checked once as well.
- On a hit, `Rejoin.leave` logs `auto rejoin: <reason>, teleporting to place <id>` and starts
  the classic retry loop: `TeleportService:Teleport(game.PlaceId)` every
  `Config.rejoinDelay = 2` s while the option stays on. `Rejoin.teleport` falls back to
  `TeleportService:TeleportAsync(game.PlaceId, { LocalPlayer })` when `Teleport` errors.
- `Rejoin.busy` makes sure one prompt starts one loop; turning the option off stops the loop
  after the current delay.
- If `CoreGui`/`RobloxPromptGui`/`promptOverlay` is missing, the watcher logs a warning and
  clears `Rejoin.attached`, so toggling the option again re-arms it.
- `autoRejoin = true` is applied by `Settings.restore()` before the UI is built.
