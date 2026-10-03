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

| | Pad (through Steam) | Deck outside Steam | Keyboard / mouse |
| --- | --- | --- | --- |
| Aim | Either stick | Touch the screen where you want it to point | A / D, or hold the mouse button |
| Key down / up a fourth | L1 / R1 | `key −4th` / `key +4th` buttons, top right | Q / E |
| Key down / up a fifth | L2 / R2 (not in B) | — | Z / X |
| Next scale (temporary) | Y | A (sends Enter), or the `scale ▸` button | Enter |
| B: fire | RT, depth = rate | Touch (further from the spout = faster), Y (sends Space) = full | Space = full, 1–5 = depths, or hold the mouse button |
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
point and it swings there for as long as you hold; the buttons in the top
right move the key and the scale. The right trackpad and R2 (which move the
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
balls clack off it; anything that is not a physics body looks pins up with
`PinField.pin_at`. A hit plays a short sine pluck with an octave sparkle on
top, immediately, not quantised to the grid, and a pin hit again within 60 ms
stays quiet.

## Version A: fluid

`a_fluid/level_three_a.tscn` (`scripts/run.sh spout-a`). The spout pours the
eye tank's own fluid — a `FluidSimulation` with a default `FluidConfig` the
size of the screen, painted by a `FluidRenderer` — so it is the same water
the eyes float in, on the same dark painterly ground.

The solve has no particles and no solid obstacles, so "a fluid element hits a
pin" needed an answer. [`FluidEmitter`](a_fluid/fluid_emitter.gd) gives it in
three parts:

1. **The stream.** Each physics frame the nozzle pushes the fluid along its
   aim and paints into it, so a painted jet swings with the spout. The tank
   leans gently downwards to keep it falling.
2. **Droplets.** Sixteen a second leave the nozzle as small
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

## Version B: balls

`b_balls/level_three_b.tscn` (`scripts/run.sh spout-b`). The spout fires
[`SpoutBall`](b_balls/spout_ball.gd)s — rigid bodies, 8 px, hard and a
little bouncy — that clack off the pins, off the side cushions and off each
other, and leave through the open floor.

**RT sets the rate.** [`SpoutFireRate`](b_balls/spout_fire_rate.gd) maps the
right trigger's depth to balls per second, in proportion: nothing inside a
small deadzone, 1/s just past it, 12/s fully pressed. An accumulator carries
the fraction of a ball owed between frames, so easing the trigger eases the
rate; the first ball of each press fires at once. Without a pad: Space is
fully pressed and 1–5 hold fifths of the way.

**Touch fires too.** Touching aims the spout at the finger and fires at once,
faster the further the finger is from the spout — like drawing a slingshot —
from a dribble right by the nozzle to the full 12/s down at the pins. A held
click (the Deck's R2 outside Steam, with the right trackpad as the pointer)
does the same.

**A tick per ball.** Every ball fired asks the level's
[`Haptics`](../../../core/haptics/README.md) for a 25 ms pulse, a little
stronger the deeper the trigger. At 12 balls a second the port's rate limit
decides what is felt.

**Hits.** A ball reports each pin it strikes with how fast it was closing on
it — the part of its speed along the line to the pin, taken from the step
before the bounce — so a straight drop plays loud and a glancing roll plays
soft or not at all (under 45 px/s stays quiet).

**RT is not a key move here.** In the eye band L2/R2 move the key by a fifth;
here RT fires, so both triggers are left out of key moves and L1/R1 (fourths)
do the job alone — repeated fourths still reach all twelve keys.

## Tuning so far

All first guesses, waiting on a play on real hardware: 6 rows of 7/6 pins over
the middle 80% of the screen width, 50-80% of its height; the spout hung at 7%
of the height; ±60° of aim; 1.6 rad/s at full stick, 0.9 on the keys; pluck
level 0.11, release 0.9 s.

Version A: jet 2600 px/s², 34 px wide; droplets 16/s at 340 px/s, ±7°,
sinking at 240 px/s², drag 2.2; restitution 0.5; full strength at 420 px/s
closing speed; pin resistance 5/s. Aimed straight down it plays about thirty
hits a second, which the 60 ms per-pin cooldown thins out.

Version B: muzzle speed 520 px/s, ±2.5° scatter; ball bounce 0.3 over the
pins' 0.6 and the cushions' 0.45 (Godot adds them, capped at 1); linear damp
0.08; full strength at 650 px/s closing; at most 60 balls, 14 s each; haptic
pulse 0.35-0.8 strength, 25 ms.
