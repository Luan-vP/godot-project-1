# Level 3: the spout

A spout hangs at the top of the screen, pointing down. Swing it left and right
— that is the whole input — and whatever comes out of it falls through a field
of pins at the bottom. Every pin it hits plays a note. The pins are laid out
as a **scale diagram on all six strings of a guitar** — the high e on top,
frets 9 to 20 left to right — so pitch climbs along each string, and sweeping
the spout plays a phrase that rises and falls with your aim. Behind it the
eye band's songs play in full. (The older layout, staggered rows rising low
to high left to right, is still there: see [Layouts](#layouts).)

The spout fires **bubbles** (`bubbles/`). A bubble sticks round the first
free duck it hits; the pin plays on the next sixteenth of the music, the
bubble pops, and the duck is gone until the next bar. Every note echoes
twice, and each bar's notes rise as a constellation that ends up printed in
the water. The spout's jet and the bubbles stir and paint the tank, but the
water never moves a bubble. See [The bubbles](#the-bubbles).

It fires in **steps of the bar** (see [Pouring in bar subdivisions](#pouring-in-bar-subdivisions)):
8, 12, 16 or 20 bubbles a bar, each on the bar's grid, set by RT or by which
ring round the spout you touch.

`spout_level.tscn` is the shell the level builds on, with a debug emitter in
place of the bubbles: Space plucks the pin you are aiming at
(`scripts/run.sh spout-shell`).

## Controls

| | Pad (through Steam) | Deck outside Steam | Keyboard / mouse |
| --- | --- | --- | --- |
| Aim | Either stick | Touch the screen where you want it to point | A / D, or hold the mouse button |
| Key down / up a fourth | L1 / R1 | `key −4th` / `key +4th` buttons, top right | Q / E |
| Key down / up a fifth | — (RT fires) | — | Z / X |
| Next scale (temporary) | Y | A (sends Enter), or the `scale ▸` button | Enter, or the `scale ▸` button |
| Fire, 8–20 a bar | RT, depth = step | Touch: the ring you touch is the step; Y (sends Space) = full | Space = full, 1–5 = depths, or hold the mouse button |
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
right move the key and the scale. Those buttons are the carousel's, not the
spout's: they are in every level, and the scale they step is the band's,
shared with the flocks (see [the carousel](../carousel/README.md#key-scale-and-song)). The right trackpad and R2 (which move the
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
| `spout_emitter.gd` | `SpoutEmitter` — the slot an emitter fills, and the stepped pour. |
| `spout_flow.gd` | `SpoutFlow` — pure: trigger depth and touch distance to a step, drops due on the bar's grid. An emitter can bring its own steps (`flow_steps()`). |
| `spout_flow_overlay.gd` | `SpoutFlowOverlay` — the rings round the spout, one per step. |
| `bubbles/bubble_emitter.gd` | `BubbleEmitter` — fires the bubbles, sticks them, plays and pops them on the sixteenth, and stirs the tank. |
| `bubbles/bubble.gd` | `SpoutBubble` — one bubble: a rigid body drawn in vectors that snaps round a duck, pops, and pushes and paints the water. |
| `bubbles/pin_echo.gd` | `PinEcho` — the delay: every note again a bar later, twice, drawn as a rising constellation that ends up in the water. |
| `debug_spout_emitter.gd` | `DebugSpoutEmitter` — the shell's stand-in: Space plucks. |

The music is the host's [`Band`](../../../core/audio/band.gd) (see
[the level format](../carousel/README.md#the-level-format)): every part
plays, on whichever of the eye band's songs comes up. Its `key_changed` keeps the
`PegScale` on the band's key, and its `stepped` signal advances the scroll.

### Layouts

`SpoutLevel.pin_layout` picks one per scene; the level uses the
fretboard.

**Fretboard (the default).** The pins are a scale diagram on all six strings
of a guitar in standard tuning — e B G D A E as rows, the high e on top as in
tab — and frets 9 to 20 as 12 columns. An even number on purpose: the spout
hangs over the middle of the field, which then falls on a fret wire between
two columns, so a straight drop splits either side and reaches the low
strings rather than landing on the top pin of a column every time.
Every string and fret is a *site* with its own note, the open string plus
the fret (C#3 at the low E's 9th fret up to C6 at the high e's 20th), and a
pin stands at the sites in the scale. Each pin is one of seven hand-drawn
ducks (`ducks/`, taken in turn along the field), with no note colour or
root ring; a hit glows in the note's colour. A pentatonic puts
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

**A key change is printed into the tank**, as in every level: see
[the carousel](../carousel/README.md#the-level-format). **So is the scale's
name**, smaller and above where the key goes: when a spout level arrives,
and, in any level, whenever the band's scale changes — the scale button, or
a new song in the other mode, which swaps the pentatonic.

**Changing key or scale scrolls.** Nothing snaps. On the fretboard the pins
move: fret by fret, lowest first, one per sixteenth of the music, the old
scale's pins leave and the new one's arrive, so the shape slides along the
neck in time with the band. A site about to gain a pin shimmers in its note's
colour, a pin about to go flickers, and a white ring marks the fret about to
change. On the staggered layout the notes flip column by column the same
way. A second change mid-scroll restarts the sweep from the left.

**Scales.** The pins play the band's scale (`Band.scale_name()`), shared
with every level: the pentatonic matching the song — major for *Night Pool*,
minor for the rest — until the `scale ▸` button, Y or Enter
(`cycle_scale()`, which moves the band's) picks another.
`SpoutLevel.set_pin_scale(intervals)` sets one on the pins alone; `PegScale.SCALES` has major and minor pentatonic, major, natural minor,
dorian and blues. Which input should do that is still open (#117); Y, Enter
and the `scale ▸` button are stand-ins.

**Pins.** Each is a `StaticBody2D` on physics layer 3 with some bounce, so
bubbles clack off it; anything that is not a physics body looks pins up with
`PinField.pin_at`. A pin can `pop()` — gone, its duck a faint ghost, not
collided with — until `restore()`. A hit plays a short sine pluck with an octave sparkle on
top, immediately, not quantised to the grid, and a pin hit again within 60 ms
stays quiet.

## The bubbles

`bubbles/level_three.tscn` (`scripts/run.sh spout`).
[`BubbleEmitter`](bubbles/bubble_emitter.gd) fires
[`SpoutBubble`](bubbles/bubble.gd)s — rigid bodies, 8 px, hard and a little
bouncy, at 1040 px/s, **8, 12, 16 or 20 a bar** — that clack off the pins,
off the side cushions and off each other, and leave through the open floor.
They are drawn in vectors: a thin rim in the stream's colour over a clear
fill, with a highlight.

**A tick per bubble.** Every bubble fired asks the level's
[`Haptics`](../../../core/haptics/README.md) for a 25 ms pulse, a little
stronger the higher the step. At 20 a bar the port's rate limit decides what
is felt.

**A bubble sticks round the first free duck it hits.** It snaps to the pin's
centre and grows round the duck (half the duck's size, plus 3 px), frozen
there, out of the physics: the pin does the colliding. One bubble to a pin:
a bubble hitting a pin that already holds one bounces off without a sound,
and can go on to stick lower down. A bubble reports how fast it was closing
on the pin — the part of its speed along the line to the pin, taken from
the step before the bounce.

**A pin with a bubble plays on the next sixteenth**, not on the hit, at the
strength the bubble struck it with (full strength at 1300 px/s closing;
never quieter than a quarter, so every stuck bubble is heard). Every pin
waiting plays on that sixteenth together, so bubbles that stick at once
sound as a chord.

**Then the bubble pops**: its rim flies apart with a spray of drops, and the
water splashes outward round it. The pin is gone — its duck fades to a
ghost, and bubbles fall through where it was — until the start of the next
bar, when every popped pin comes back at once. A pin played on a downbeat is
gone the whole bar.

**Every note echoes.** The pins recharge in a bar, so that is the delay:
[`PinEcho`](bubbles/pin_echo.gd) plays every note again a bar later, on the
same sixteenth, and again a bar after that, at 85% and then 60% of its
strength — the bar's phrase loops twice, in time with the band, then stops.
An echo replays the note that sounded, even if the pins have since scrolled
to a new key. Echoes are a sine with no octave sparkle, so they sit behind
the live pins.

**The phrase is a constellation.** Each bar's notes are drawn as stars where
their pins were, joined in the order they played, glowing (added light) over
the pins. When the bar ends the constellation lifts off and drifts up,
carried a little by the current, each star twinkling as its echo sounds.
After the second loop it is printed into the tank as pigment — dots and
lines in the notes' colours — and the ghost fades over it, leaving the
shape to swirl away with the water, the way the splash's logo does.

**The water.** The tank is the host's, the same water the eyes float in.
The solve has no particles and no solid obstacles, so the level stirs it
from outside, one way only:

1. **The jet.** Each physics frame the spout is open, the nozzle pushes the
   water along its aim and paints into it in the stream's colour (the dyes,
   drifting, lifted 30% towards white), harder at a higher step, so a
   painted jet swings with the spout. The tank leans gently downwards to
   keep it falling.
2. **Bubbles stir it.** Each loose bubble pushes the water by how fast it is
   slipping through it, and paints a thin trail in its colour. A bubble
   striking a pin splashes outward from the contact; one popping splashes
   outward all round.
3. **Pins part the water.** Each pin pushes back on whatever current runs
   through it, so the painted stream divides around the pins rather than
   through them.

**None of it comes back.** A bubble reads the current only to know its slip;
its path is the physics engine's alone, so the water never bends it.

## Pouring in bar subdivisions

In [`SpoutEmitter`](spout_emitter.gd), with the pure rules in
[`SpoutFlow`](spout_flow.gd).

**Steps of the bar.** The spout fires at **8, 12, 16 or 20 bubbles a bar**
(`BubbleEmitter.STEPS`; `SpoutFlow` itself goes on to 24 for an emitter that
wants it) — few steps, so each gets a wide ring to aim for. With *n* a bar,
one leaves at each *k/n* of the bar, so 8 a bar is eighth notes, 12
eighth-note triplets, 16 sixteenths — the stream plays in time with the band. The grid is read from
the music time source the band's `StepClock` plays from, not
`AudioManager.get_current_bar()`, which only moves while loop layers play.
Changing step starts counting from that moment, so it never releases a
burst, and at most two drops leave in one frame.

**RT** past a small deadzone splits its travel evenly into the steps.
Space is full, 1–5 fixed depths. With nothing held the spout is closed.

**Touch** sets the step by how far from the spout the finger is: the bands
run evenly from just past the nozzle's tip down to the bottom of the pins.
Any touch fires, at least 8 a bar.

**The rings.** [`SpoutFlowOverlay`](spout_flow_overlay.gd) draws a ring round
the spout for each step, labelled with its drops a bar. The band under the
finger is lit and pulses with each drop; a dashed line runs from the pivot to
the finger, with an `8 / bar` readout beside it. It fades in on touch and out
on release; RT shows the lit ring faintly.

**RT is not a key move here.** In the eye band L2/R2 move the key by a fifth;
here RT fires, so both triggers are left out of key moves and L1/R1 (fourths)
do the job alone — repeated fourths still reach all twelve keys.

## Tuning so far

All first guesses, waiting on a play on real hardware: six strings by 12
frets (9–20) over 60-80% of the height, or 4 rows of 7/6 pins on the
staggered layout over 65-80%, both across the middle 80% of the width; the spout hung at 7% of the height; ±90° of aim (horizontal either
way); 1.6 rad/s at full stick, 0.9 on the keys; pluck level 0.2 (sparkle 0.065), up from 0.11 to sit well over the band; release 0.9
s.

The water: jet 2800–6400 px/s² from the gentlest step to the fullest, 34 px
wide, painting 2.4/s; a bubble's wake 1.6 × its slip over 36 px, its trail
0.5/s over 18 px; pin splash 1400 px/s², pop splash 900 px/s²; pin
resistance 5/s.

The bubbles: muzzle speed 1040 px/s, ±2.5° scatter; bounce 0.3 over the
pins' 0.6 and the cushions' 0.45 (Godot adds them, capped at 1); linear damp
0.08; full strength at 1300 px/s closing, never under 0.25; at most 60
bubbles, 14 s each; snap 0.12 s, pop 0.22 s; haptic pulse 0.35-0.8
strength, 25 ms. Echoes at 0.85 and 0.6.
