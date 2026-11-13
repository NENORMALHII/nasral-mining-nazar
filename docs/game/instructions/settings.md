# Saved settings

`src/main.lua` persists UI options with the standard executor filesystem API:
`writefile`, `readfile`, `isfile`, `makefolder` (all guarded with `type(...) == "function"`),
JSON via `HttpService:JSONEncode` / `JSONDecode`.

- Path: `nm2/settings.json` (`Settings.path`); if writing there fails, the bot retries the
  flat `nm2_settings.json` (`Settings.fallbackPath`).
- Folder `nm2` is created with `makefolder` when the executor exposes it.
- `Settings.load()` reads the file once; missing file or bad JSON falls back to defaults.
- `Settings.set(key, value)` updates the table and calls `Settings.persist()`, which writes
  only when the encoded JSON differs from the last written text (`Settings.lastJson`).
- Selections (uilib has no change callback) are persisted from the existing 2 s stats loop.

Stored keys:

| Key | Type | UI control |
|---|---|---|
| `mode` | number (1 = Farm, 2 = Mushrooms) | Category dropdown |
| `enabled` | boolean | Mode Enabled toggle |
| `instantMove` | boolean | Instant move |
| `tweenSpeed` | number | Tween speed slider |
| `ores` | array of indexes | Farm ores selection |
| `sellEnabled` | boolean | Auto sell Enabled |
| `sellSelected` | array of indexes | Resources to sell selection |
| `verboseLogs` | boolean | Verbose logs |
| `noRender` | boolean | Disable 3D render |

## Disable 3D render

Debug → Logs → `Disable 3D render` calls
`RunService:Set3dRenderingEnabled(not state)` inside `pcall`. With the toggle on the call is
`RunService:Set3dRenderingEnabled(false)`; the saved `noRender = true` is applied at startup
before the UI is built. GUI rendering is unaffected.
