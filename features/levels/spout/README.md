# Level 3: the spout

A spout hangs at the top of the screen, pointing down. Swing it left and right
— that is the whole input — and whatever comes out of it falls through a field
of pins at the bottom. Every pin it hits plays a note. The pins are laid out
as a **scale diagram on all six strings of a guitar** — the high e on top,
frets 9 to 21 left to right — so pitch climbs along each string, and sweeping
the spout plays a phrase that rises and falls with your aim. Behind it the
eye band's songs play in full. (The older layout, staggered rows rising low
to high left to right, is still there: see [Layouts](#layouts).)

There are three versions, differing only in what comes out of the spout:

- **A** (`a_fluid/`) pours the eye tank's fluid.
- **B** (`b_balls/`) fires billiard-like balls, with a haptic tick per ball.
- **C** (`c_sticky/`) fires B's balls twice as fast, and each sticks to the
  first free pin it hits; the pin plays on the next sixteenth and pops until
  the next bar.

Both pour in **steps of the bar** (see [Pouring in bar subdivisions](#pouring-in-bar-subdivisions)):
2 drops a bar up to 16, each on the bar's grid, set by RT or by which ring
round the spout you touch (C on its own steps, 8–20). In the carousel the
spout slot plays A, B or C, a third each.

`spout_level.tscn` is the shell both build on, with a debug emitter in place
of either: Space plucks the pin you are aiming at.

## Controls

| | Pad (through Steam) | Deck outside Steam | Keyboard / mouse |
| --- | --- | --- | --- |
| Aim | Either stick | Touch the screen where you want it to point | A / D, or hold the mouse button |
| Key down / up a fourth | L1 / R1 | `key −4th` / `key +4th` buttons, top right | Q / E |
| Key down / up a fifth | — (RT pours) | — | Z / X |
| Next scale (temporary) | Y | A (sends Enter), or the `scale ▸` button | Enter |
| Pour / fire, 2–16 a bar | RT, depth = step | Touch: the ring you touch is the step; Y (sends Space) = full | Space = full, 1–5 = depths, or hold the mouse button |
| Tempo | D-pad | D-pad (sends arrows) | Arrows |
| Back to the menu | View | View (sends Tab), or the `‹ menu` button | Backspace |

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
| `pin_field.gd` | `PinField` — pins with bodies, on a fretboard or in staggered rows; `hit(pin, strength)` plucks. |
| `peg_scale.gd` | `PegScale` — pure: which note each column plays, and the scroll. |
| `fretboard_scale.gd` | `FretboardScale` — pure: which fretboard sites hold a pin, and the fret-by-fret scroll. |
| `guitar_diagrams.gd` | `GuitarDiagrams` — every scale as a full six-string scale diagram, frets 0–24. |
| `spout_emitter.gd` | `SpoutEmitter` — the slot an emitter fills, and the stepped pour both versions share. |
| `spout_flow.gd` | `SpoutFlow` — pure: trigger depth and touch distance to a step, drops due on the bar's grid. An emitter can bring its own steps (`flow_steps()`). |
| `spout_flow_overlay.gd` | `SpoutFlowOverlay` — the rings round the spout, one per step. |
| `debug_spout_emitter.gd` | `DebugSpoutEmitter` — the shell's stand-in: Space plucks. |

The music is the host's [`Band`](../../../core/audio/band.gd) (see
[the level format](../carousel/README.md#the-level-format)): every part
plays, on whichever of the eye band's songs comes up. Its `key_changed` keeps the
`PegScale` on the band's key, and its `stepped` signal advances the scroll.

### Layouts

`SpoutLevel.pin_layout` picks one per scene; all three versions use the
fretboard.

**Fretboard (the default).** The pins are a scale diagram on all six strings
of a guitar in standard tuning — e B G D A E as rows, the high e on top as in
tab — and frets 9 to 21 as 13 columns, as many as the staggered layout has.
Every string and fret is a *site* with its own note, the open string plus
the fret (C#3 at the low E's 9th fret up to C#6 at the high e's 21st), and a
pin stands at the sites in the scale; roots are ringed. A pentatonic puts
about 33 pins on the neck, the major scale about 46. The fretboard takes a
slightly taller strip than the staggered rows (`SpoutLevel.fretboard_area`,
60-80% of the height), so the strings sit close together but the drop from
the spout stays long. The field draws the strings, the fret wires, the
inlay dots and the fret numbers behind them. `PinField.strings`,
`first_fret` and `frets` change the neck.

**The diagrams are stored whole.** [`GuitarDiagrams`](guitar_diagrams.gd)
holds every scale in `PegScale.SCALES` as a full scale diagram for all six
strings, frets 0–24, drawn in E — one line a string, `R` a root, `o` a
scale tone, `-` nothing:

```
"minor pentatonic":
[
	#  0    5    10   15   20  24
	"e R--o-o-o--o-R--o-o-o--o-R",
	"B o--o-R--o-o-o--o-R--o-o-o",
	"G o-o-o--o-R--o-o-o--o-R--o",
	...
```

The game reads the top `strings` lines; another key is the same diagram slid
along the neck. A test checks every diagram against its scale's intervals.

**Staggered.** Rows like a falling-balls board. Columns, not pins, carry
notes: every pin sits in one of 13 distinct columns across the field (7 full
columns and 6 set in between them); the scale gives each column a note, low
to high left to right from D4 up, and pins in the same column share it.

**Changing key or scale scrolls.** Nothing snaps. On the fretboard the pins
move: fret by fret, lowest first, one per sixteenth of the music, the old
scale's pins leave and the new one's arrive, so the shape slides along the
neck in time with the band. A site about to gain a pin shimmers in its note's
colour, a pin about to go flickers, and a white ring marks the fret about to
change. On the staggered layout the notes flip column by column the same
way. A second change mid-scroll restarts the sweep from the left.

**Scales.** The pins start on the pentatonic matching the song — major for
*Night Pool*, minor for the rest — and follow a mode change if the key moves.
`SpoutLevel.set_pin_scale(intervals)` or `cycle_scale()` swap it for anything
else; `PegScale.SCALES` has major and minor pentatonic, major, natural minor,
dorian and blues. Which input should do that is still open (#117); Y, Enter
and the `scale ▸` button are stand-ins.

**Pins.** Each is a `StaticBody2D` on physics layer 3 with some bounce, so
balls clack off it; anything that is not a physics body looks pins up with
`PinField.pin_at`. A pin can `pop()` — gone, drawn as a faint dotted mark,
not collided with — until `restore()` (version C). A hit plays a short sine pluck with an octave sparkle on
top, immediately, not quantised to the grid, and a pin hit again within 60 ms
stays quiet.

## Version A: fluid

`a_fluid/level_three_a.tscn` (`scripts/run.sh spout-a`). The spout pours the
host's fluid, the same water the eyes float in.

The solve has no particles and no solid obstacles, so "a fluid element hits a
pin" needed an answer. [`FluidEmitter`](a_fluid/fluid_emitter.gd) gives it in
three parts:

1. **The stream.** Each physics frame it pours, the nozzle pushes the fluid
   along its aim and paints into it, harder at a higher step, so a painted
   jet swings with the spout. The tank leans gently downwards to keep it
   falling.
2. **Droplets.** One per step of the bar's grid leaves the nozzle as a small
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

**RT or a touch sets the step**, as in version A: see below.

**A tick per ball.** Every ball fired asks the level's
[`Haptics`](../../../core/haptics/README.md) for a 25 ms pulse, a little
stronger the higher the step. At 16 a bar the port's rate limit decides what
is felt.

**Hits.** A ball reports each pin it strikes with how fast it was closing on
it — the part of its speed along the line to the pin, taken from the step
before the bounce — so a straight drop plays loud and a glancing roll plays
soft or not at all (under 45 px/s stays quiet).

## Version C: sticky balls

`c_sticky/level_three_c.tscn` (`scripts/run.sh spout-c`).
[`StickyBallEmitter`](c_sticky/sticky_ball_emitter.gd) fires version B's
balls at twice the muzzle speed (1040 px/s) — **8, 12, 16 or 20 a bar**,
on the same RT or rings.

**A ball sticks to the first free pin it hits** and stays there, frozen.
One ball to a pin: a ball hitting a pin that already holds one bounces off
without a sound, and can go on to stick lower down.

**A pin with a ball plays on the next sixteenth**, not on the hit, at the
strength the ball struck it with (full strength at 1300 px/s closing, B's
650 scaled with the speed; never quieter than a quarter, so every stuck ball
is heard). Every pin waiting plays on that sixteenth together, so balls that
stick at once sound as a chord.

**Then it pops.** The pin and its ball burst and are gone — balls fall
through where it was — until the start of the next bar, when every popped
pin comes back at once. A pin played on a downbeat is gone the whole bar.

## Pouring in bar subdivisions

Both versions share it, in [`SpoutEmitter`](spout_emitter.gd) with the pure
rules in [`SpoutFlow`](spout_flow.gd).

**Steps of the bar.** The spout pours (A) or fires (B) at **8, 12, 16, 20 or 24
drops a bar** — few steps, so each gets a wide ring to aim for. With *n* a
bar, one leaves at each *k/n* of the bar, so 8 a bar is eighth notes, 12
eighth-note triplets, 16 sixteenths, 24 sixteenth triplets — the stream plays in time with the band. The grid is read from
the music time source the band's `StepClock` plays from, not
`AudioManager.get_current_bar()`, which only moves while loop layers play.
Changing step starts counting from that moment, so it never releases a
burst, and at most two drops leave in one frame.

**RT** past a small deadzone splits its travel evenly into the five steps.
Space is full, 1–5 fixed depths. With nothing held the spout is closed.

**Touch** sets the step by how far from the spout the finger is: the bands
run evenly from just past the nozzle's tip down to the bottom of the pins.
Any touch pours, at least 8 a bar.

**The rings.** [`SpoutFlowOverlay`](spout_flow_overlay.gd) draws a ring round
the spout for each step, labelled with its drops a bar. The band under the
finger is lit and pulses with each drop; a dashed line runs from the pivot to
the finger, with an `8 / bar` readout beside it. It fades in on touch and out
on release; RT shows the lit ring faintly.

**RT is not a key move here.** In the eye band L2/R2 move the key by a fifth;
here RT pours, so both triggers are left out of key moves and L1/R1 (fourths)
do the job alone — repeated fourths still reach all twelve keys.

## Tuning so far

All first guesses, waiting on a play on real hardware: six strings by 13
frets (9–21) over 60-80% of the height, or 4 rows of 7/6 pins on the
staggered layout over 65-80%, both across the middle 80% of the width; the spout hung at 7% of the height; ±90° of aim (horizontal either
way); 1.6 rad/s at full stick, 0.9 on the keys; pluck level 0.11, release 0.9
s.

Version A: jet 2800–6400 px/s² from the gentlest step to the fullest (twice
what it first was), 34 px wide; droplets 280–420 px/s, ±7°,
sinking at 240 px/s², drag 0.35 (they hold their own line through the current); restitution 0.5; full strength at 420 px/s
closing speed; pin resistance 5/s.

Version B: muzzle speed 520 px/s, ±2.5° scatter; ball bounce 0.3 over the
pins' 0.6 and the cushions' 0.45 (Godot adds them, capped at 1); linear damp
0.08; full strength at 650 px/s closing; at most 60 balls, 14 s each; haptic
pulse 0.35-0.8 strength, 25 ms.
