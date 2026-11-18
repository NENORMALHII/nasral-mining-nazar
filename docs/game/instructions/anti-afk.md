# Anti-AFK

`src/main.lua`, module `AntiAfk`.

Roblox disconnects a client after 20 minutes without **user input**; bot actions
(teleports, `FireServer`, mining) do not count as input. There is no event to
cancel the check, only ways to feed the client input:

1. `Players.LocalPlayer.Idled` fires when the client notices the idle timeout →
   `AntiAfk.press("idled")`.
2. A timer also presses every `Config.antiAfkInterval = 240` s, so the client
   never reaches the limit in the first place.

## Input methods

Tried in order, each in `pcall`:

1. `VirtualUser:CaptureController()` + `VirtualUser:ClickButton2(Vector2.zero)`
   (executor service, the usual idle reset);
2. hidden `VirtualInputManager:SendKeyEvent(true/false, Enum.KeyCode.Space, false, game)`;
3. executor `keypress(0x20)` / `keyrelease(0x20)`.

If none works, one warning is logged:
`anti-afk: no virtual input available, idle kick still possible`.

Presses are rate-limited to one per second and logged as
`anti-afk: input N (idled|timer)` on the first press and every 10th.

## Limits

- Virtual input is client-side only. A game-side AFK check that counts
  replicated actions cannot be bypassed from the client; only Roblox's own
  20-minute idle disconnect is addressed.
- The hidden services (`VirtualUser`, `VirtualInputManager`) are not available in
  a normal client without an executor, so the fallbacks exist for that case.
