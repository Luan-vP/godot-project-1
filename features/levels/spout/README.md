# Level 3: the spout

A spout hangs at the top of the screen, pointing down, and pours the eye
tank's fluid. Swing it left and right, and choose how hard it pours, and the
stream falls through a field of pins at the bottom. Every pin it hits plays a
note. The pins carry a scale
laid out **low to high, left to right**, so sweeping the spout plays a phrase
that rises and falls with your aim. Behind it the eye band's songs play in
full.

`a_fluid/level_three_a.tscn` is the level (`scripts/run.sh spout`).
`spout_level.tscn` is the shell it builds on, with a debug emitter in place of
the fluid: Space plucks the pin you are aiming at (`scripts/run.sh
spout-shell`). An earlier version B fired billiard balls instead; the fluid
won, and B is gone.

## Controls

| | Pad (through Steam) | Deck outside Steam | Keyboard / mouse |
| --- | --- | --- | --- |
| Aim | Either stick | Touch the screen where you want it to point | A / D, or hold the mouse button |
| Key down / up a fourth | L1 / R1 | `key −4th` / `key +4th` buttons, top right | Q / E |
| Pour | RT: deeper = more droplets a bar | Touch: further from the spout = more; Y (sends Space) = full | Space = full, 1–5 = depths, or hold the mouse button |
| Key down / up a fifth | — (RT pours) | — | Z / X |
| Next scale (temporary) | Y | A (sends Enter), or the `scale ▸` button | Enter |
| Tempo | D-pad | D-pad (sends arrows) | Arrows |
| Back to the menu | View | View (sends Tab), or the `⌫ menu` button | Backspace |

Either stick aims, whichever is pushed further, so the Deck can be held either
way round. A stick is a rate control — push it and the nozzle keeps swinging
until you let go — eased so the nozzle has a little weight. The arrows are not
used for aiming because they move the tempo in every scene.

**The Deck's sticks only reach the game as a gamepad when it is launched
through Steam** (Game Mode, or the non-Steam shortcut — see the root README).
Run outside Steam, Steam keeps the controller in its desktop layout and the
game sees a keyboard and mouse ([docs/steam-deck-controls.md](../../../docs/steam-deck-controls.md)).
So the whole level is also playable by touch: touch where the spout should
point and it swings there and pours for as long as you hold, harder the
further from the spout you touch; the buttons in the top right move the key
and the scale. The right trackpad and R2 (which move the
pointer and click it, outside Steam) aim the same way.

Scale is not on Tab: outside Steam the Deck's View button sends Tab, and that
already means "back to the menu".

## How it fits together

| File | What it is |
| --- | --- |
| `spout_level.gd` | `SpoutLevel` — builds everything, wires the band to the scale, the HUD. |
| `spout.gd` | `Spout` — the nozzle: `aim`, `direction()`, `muzzle_position()`. |
| `spout_aim_input.gd` | `SpoutAimInput` — pure: sticks and keys to a turn rate, a pointer to an aim. |
| `spout_pointer.gd` | `SpoutPointer` — a touch or held click, aiming the spout while it is down. |
| `pin_field.gd` | `PinField` — staggered pins with bodies; `hit(pin, strength)` plucks. |
| `peg_scale.gd` | `PegScale` — pure: which note each column plays, and the scroll. |
| `spout_emitter.gd` | `SpoutEmitter` — the slot an emitter fills. |
| `spout_flow.gd` | `SpoutFlow` — pure: RT depth or touch distance to droplets a bar, and when each falls due. |
| `spout_flow_overlay.gd` | `SpoutFlowOverlay` — the rings round the spout that show a touch's step. |
| `debug_spout_emitter.gd` | `DebugSpoutEmitter` — the shell's stand-in: Space plucks. |

The music is a bare [`Band`](../../../core/audio/band.gd): every part plays,
on whichever of the eye band's songs comes up. Its `key_changed` keeps the
`PegScale` on the band's key, and its `stepped` signal advances the scroll.

**Columns, not pins, carry notes.** The rows are staggered, so every pin sits
in one of 13 distinct columns across the field (7 full columns and 6 set in
between them); the scale gives each column a note, and pins in the same column
share it. A pentatonic over 13 columns spans about two and a half octaves,
from C3 up — enough range to feel like a melody, few enough that neighbouring
pins are still neighbouring notes.

**Changing key or scale scrolls.** The new notes don't snap in. They flip
column by column, leftmost first, one per sixteenth of the music, so a change
sweeps across the field in time with the band. A pin waiting to flip shimmers
in its next note's colour; a white ring marks the column about to flip. A
second change mid-scroll restarts the sweep from the left.

**Scales.** The pins start on the pentatonic matching the song — major for
*Night Pool*, minor for the rest — and follow a mode change if the key moves.
`SpoutLevel.set_pin_scale(intervals)` or `cycle_scale()` swap it for anything
else; `PegScale.SCALES` has major and minor pentatonic, major, natural minor,
dorian and blues. Which input should do that is still open (#117); Y, Enter
and the `scale ▸` button are stand-ins.

**Pins.** Each is a `StaticBody2D` on physics layer 3 with some bounce, so
physics bodies bounce off it; anything that is not a physics body looks pins up with
`PinField.pin_at`. A hit plays a short sine pluck with an octave sparkle on
top, immediately, not quantised to the grid, and a pin hit again within 60 ms
stays quiet.

## The fluid

The spout pours the eye tank's own fluid — a `FluidSimulation` with a default `FluidConfig` the
size of the screen, painted by a `FluidRenderer` — so it is the same water
the eyes float in, on the same dark painterly ground.

The solve has no particles and no solid obstacles, so "a fluid element hits a
pin" needed an answer. [`FluidEmitter`](a_fluid/fluid_emitter.gd) gives it in
three parts:

1. **The stream.** Each physics frame the nozzle pushes the fluid along its
   aim and paints into it, so a painted jet swings with the spout. The tank
   leans gently downwards to keep it falling.
2. **Droplets.** On the bar's grid (below), the nozzle releases small
   [`SpoutDroplet`](a_fluid/droplet.gd)s — `FluidBody`s that sink, are
   dragged by the real current, and stain the water. They are the fluid
   elements: a droplet striking a pin plays it at a strength set by how fast
   it was closing, and bounces off at half speed. Pooled, at most 96.
3. **Pins part the water.** Each pin pushes back on whatever current runs
   through it, and a struck pin splashes outward, so the painted stream
   divides around the pins rather than through them.

Not tried yet: the droplet-free alternative, where each pin samples the
current and fires on a rising edge of local speed. Droplets came first
because they give a crisp, countable rhythm; the comparison is still worth
making by ear.

## How hard it pours

[`SpoutFlow`](spout_flow.gd) sets the pour in steps of the bar: **2, 3, 4, 5,
6, 7, 8, 9, 10, 12, 14 or 16 droplets a bar**. Droplets leave on the grid — at
4 a bar one on each beat, at 3 a triplet feel, at 16 every sixteenth — so the
stream plays in time with the band. The jet's push, its paint and the
droplets' speed grow with the step too, so a heavy pour looks heavier. With
nothing held the spout is closed.

**RT** splits its travel evenly into the twelve steps past a small deadzone:
a gentle press is 2 a bar, the bottom of the travel 16. Since RT pours, the
triggers are left out of key moves here; L1/R1 (fourths) still walk all twelve
keys. Without a pad, Space is fully pressed and 1–5 hold fifths of the way.

**A touch** pours by distance: the further from the spout, the higher the
step, in twelve even bands from just past the nozzle's tip down to the bottom
of the pins. While a touch pours, [`SpoutFlowOverlay`](spout_flow_overlay.gd)
draws the bands as rings round the spout, each labelled with its droplets a
bar; the band under the finger is lit, breathes with each droplet, and a
readout by the finger says `8 / bar`. It fades out when the finger lifts.
With RT, the lit ring shows faintly, so both ways of pouring read as one scale.

A change of step starts counting the grid afresh from that moment, so moving
between steps never dumps a burst.

Each droplet also asks the level's [`Haptics`](../../../core/haptics/README.md)
for a light 20 ms tick, a little stronger at higher steps.

## Tuning so far

All first guesses, waiting on a play on real hardware: 6 rows of 7/6 pins over
the middle 80% of the screen width, 50-80% of its height; the spout hung at 7%
of the height; ±60° of aim; 1.6 rad/s at full stick, 0.9 on the keys; pluck
level 0.11, release 0.9 s.

Fluid: jet 1400-3200 px/s² by step, 34 px wide; droplets at 280-420 px/s by step, ±7°,
sinking at 240 px/s², drag 2.2; restitution 0.5; full strength at 420 px/s
closing speed; pin resistance 5/s; at most 2 droplets released in one frame.
