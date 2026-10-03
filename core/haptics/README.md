# Haptics

Short controller pulses for gameplay, behind a port in the same shape as
`core/motion` and `core/look`: gameplay asks for "a tick, now", and does not
care what hardware is listening.

```gdscript
var haptics := Haptics.new()
add_child(haptics)
haptics.pulse(0.6)          # strength 0..1, default 30 ms
```

| Script | What it is |
| --- | --- |
| `haptics.gd` | `Haptics` — the node gameplay calls. Picks an output, rate-limits, applies comfort. |
| `haptics_output.gd` | `HapticsOutput` — port: somewhere a pulse can be felt. |
| `backends/steam_haptics_output.gd` | `SteamHapticsOutput` — rumble through Steam Input: the Deck, launched from Steam. |
| `backends/joypad_haptics_output.gd` | `JoypadHapticsOutput` — rumble on a plain gamepad through `Input.start_joy_vibration`. |
| `backends/null_haptics_output.gd` | `NullHapticsOutput` — felt nowhere, records every pulse; for tests. |
| `haptics_rate_limiter.gd` | `HapticsRateLimiter` — pure: keeps a burst from queueing behind the hardware. |

Outputs are tried in priority order on every pulse — Steam first, then the
gamepad — and the first available one plays it. With neither, a pulse is
silently dropped.

**Rate limiting.** Pulses closer together than about 45 ms merge: the first
plays at once, anything else inside the interval is held, the strongest held
request wins, and it plays once the interval is up. Twelve pulses a second is felt as a steady tick rather than
a backlog that keeps buzzing after the trigger is released.

**Comfort.** `ComfortSettings.haptics_strength` scales every pulse, 1 as
tuned, 0 off. Persisted with the other comfort options.

**Feeling it.** `scripts/run.sh motion` shows which output is live; `H` (or
the pad's A) plays a pulse. On a Deck, as for motion, the game has to be
launched *from* Steam for Steam Input to attribute the controller to it — see
[`core/motion`](../motion/README.md).

Not yet verified on hardware: Steam's `triggerVibration` on the Deck is the
best guess for a crisp tick, and the strengths are untuned.
