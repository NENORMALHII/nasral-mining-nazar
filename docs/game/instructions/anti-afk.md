# Anti-AFK

`src/main.lua`, module `AntiAfk`, bound at bootstrap.

Roblox disconnects a client after 20 minutes without **user input**. Bot actions
(teleports, `FireServer`, mining, movement) do not reset that timer. Two layers
are used, the same shape as Infinite Yield's `antiafk`
(`EdgeIY/infiniteyield`, `source`: `addcmd("antiafk")`):

## Layer 1: drop the client's `Idled` handlers

```lua
for _, connection in ipairs(getconnections(Players.LocalPlayer.Idled)) do
    connection:Disable()
    connection:Disconnect()
end
```

The inactivity disconnect is driven by handlers connected to `Player.Idled`;
removing them stops the client from acting on the timeout at all. `getconnections`
is an executor debug API, so this runs in `pcall`, and a second pass runs 3 s
after binding because CoreScripts can attach their handler late. Log:
`anti-afk: disabled N Idled handler(s)`.

## Layer 2: virtual input

`AntiAfk.press` sends a synthetic user input, tried in order:

1. `Instance.new("VirtualInputManager")` +
   `SendMouseButtonEvent(0, 0, 0, true/false, game, 0)` — the Infinite Yield
   method; a real mouse event through the input pipeline;
2. `VirtualUser:CaptureController()` + `VirtualUser:ClickButton2(Vector2.zero)`;
3. `VirtualInputManager:SendKeyEvent(true/false, Enum.KeyCode.Space, ...)`;
4. executor `keypress(0x20)` / `keyrelease(0x20)`.

It fires on `Player.Idled` and on a timer every `Config.antiAfkInterval = 240` s,
so the idle counter never reaches 20 minutes even if Layer 1 is unavailable.
Presses are rate-limited to one per second and logged as
`anti-afk: input N (idled|timer)` on the first and every 10th. If no method works:
`anti-afk: no virtual input available, idle kick still possible`.

## Limits

- Both layers are client-side. A game-side AFK check that counts replicated
  actions cannot be bypassed from the client; only Roblox's own idle disconnect
  is addressed.
- `getconnections`, `VirtualUser` and `Instance.new("VirtualInputManager")` exist
  only under an executor; a plain client falls back to the timer and key helpers.
- Disconnecting `Idled` handlers is intentional: it is the only way to remove the
  20-minute kick rather than just postponing it.
