# Level 3: the spout

A spout hangs at the top of the screen, pointing down. Swing it left and right
— that is the whole input — and whatever comes out of it falls through a field
of pins at the bottom. Every pin it hits plays a note. The pins carry a scale
laid out **low to high, left to right**, so sweeping the spout plays a phrase
that rises and falls with your aim. Behind it the eye band's songs play in
full.

There are two versions, differing only in what comes out of the spout:

- **A** (`a_fluid/`) pours the eye tank's fluid.
- **B** (`b_balls/`) fires billiard-like balls, at a rate set by how far RT is
  pressed, with a haptic tick per ball.

`spout_level.tscn` is the shell both build on, with a debug emitter in place
of either: Space plucks the pin you are aiming at.

## Controls

| | Pad | Keyboard |
| --- | --- | --- |
| Aim | Left stick | A / D |
| Key down / up a fourth | L1 / R1 | Q / E |
| Key down / up a fifth | L2 / R2 (not in B) | Z / X |
| Next scale (temporary) | — | Tab |
| Tempo | D-pad | Arrows |
| Back to the menu | Select | Backspace |

The stick is a rate control — push it and the nozzle keeps swinging until you
let go — eased so the nozzle has a little weight. The arrows are not used for
aiming because they move the tempo in every scene.

## How it fits together

| File | What it is |
| --- | --- |
| `spout_level.gd` | `SpoutLevel` — builds everything, wires the band to the scale, the HUD. |
| `spout.gd` | `Spout` — the nozzle: `aim`, `direction()`, `muzzle_position()`. |
| `spout_aim_input.gd` | `SpoutAimInput` — pure: stick and keys to a turn rate. |
| `pin_field.gd` | `PinField` — staggered pins with bodies; `hit(pin, strength)` plucks. |
| `peg_scale.gd` | `PegScale` — pure: which note each column plays, and the scroll. |
| `spout_emitter.gd` | `SpoutEmitter` — the slot an emitter fills. |
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
dorian and blues. Which input should do that is still open (#117); `Tab` is a
stand-in.

**Pins.** Each is a `StaticBody2D` on physics layer 3 with some bounce, so
balls clack off it; anything that is not a physics body looks pins up with
`PinField.pin_at`. A hit plays a short sine pluck with an octave sparkle on
top, immediately, not quantised to the grid, and a pin hit again within 60 ms
stays quiet.

## Tuning so far

All first guesses, waiting on a play on real hardware: 6 rows of 7/6 pins over
the middle 80% of the screen width, 50-80% of its height; the spout hung at 7%
of the height; ±60° of aim; 1.6 rad/s at full stick, 0.9 on the keys; pluck
level 0.11, release 0.9 s.
