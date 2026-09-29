# Birds: flocks as polyrhythms

An alternative to the eye band (#90): instead of eyes that each play a part,
a dusk sky of birds that flock, where every flock sings one polyrhythm and
the player plays a snare against them. `scripts/run.sh birds`, or *Birds* in
the demo menu. The design interview behind it is
[docs/boids-rhythm-scope.md](../../../docs/boids-rhythm-scope.md).

## Controls

| Input | Does |
| --- | --- |
| `B` (keyboard or gamepad), `Esc`, `Space`, left or right click | Snare |
| ↑ / ↓ (d-pad too) | Tempo ±2 bpm — in every scene, see `TempoControl` |
| ← / → (d-pad too) | Tempo ±10 bpm |

On the Deck in Desktop Mode, run outside Steam, Steam Input keeps the
controller in its desktop layout and the game sees a keyboard and mouse. B
sends Esc, Y sends Space, R2 and L2 are left and right click, so all four
play the snare, and the d-pad sends the arrows, so tempo works as it is. See
[docs/steam-deck-controls.md](../../../docs/steam-deck-controls.md). The HUD's
*last input* shows what the game actually received for the last press, and
names the Deck control that sent it.

## What happens

- **Flocks sing polyrhythms.** Every flock plays 3, 4 or 6 even pulses across
  one shared bar, all on the same downbeat, so a 3-flock and a 4-flock are
  3-against-4. A soft kick marks each downbeat for reference, since it
  belongs to every rhythm and favours none.
- **Loners are silent.** A loner that flies into a flock joins it, taking its
  rhythm and keeping its own voice: every bird has a note from D major
  pentatonic and a timbre (sine, square or saw) for life. On each pulse a
  few members sing in turn, so a flock's melody comes from who is in it.
- **Flocks breathe on their pulses.** Cohesion and alignment surge on each
  pulse and die away before the next (`FlockSim.surge`), so a 3-flock
  visibly draws together three times a bar.
- **Loners clump into new flocks.** Four or more loners that stay within
  60 px of each other for 1.5 s become a flock, with a rhythm rolled from the
  `RhythmTable`. At most five flocks fly at once; two flocks of the same
  rhythm that meet merge.
- **The snare steers the sky.** Every tap is read against every rhythm: the
  last bar of taps, scored with a two-way least-squares fit (`TapReader`).
  Rhythms that fit gain weight: their flocks tighten, hold on to their
  members and pull loners in. Rhythms that do not fit lose weight: their
  flocks loosen, stop recruiting and shed birds. Tapping also makes a rhythm
  that is *missing* from the sky likelier to be the next one to form.
- **Holding one rhythm scatters the rest — rarely.** Keep playing one rhythm
  clearly and a charge builds (`ScatterCharge`). The winner must have enough
  taps, a fit over 0.75 and a 0.15 lead over second best. It takes about four
  bars of that to fill, and changing rhythm starts it again. When it fills,
  every flock playing anything else bursts apart and goes silent. Then
  nothing can charge for eight bars.
- **The snare shows how it was heard.** It sounds the instant it is hit, and
  a quiet ghost of it lands a bar later on the pulse it was read as.

## Reading the screen

The dial in the corner is the bar as a clock face, downbeat at the top. It
shows a ring of pulses per rhythm (outer 3, then 4, then 6), brighter the
more that rhythm is in favour; the last bar's taps as white ticks; the
playhead; and the charge as a coloured arc round the outside (a faint grey
arc while it is settling after a scatter). As the charge builds, the flocks
it would scatter tremble and the flocks that would survive glow. The label
in the other corner spells out the tempo, the reading and the charge.

## Pieces

| File | What it is |
| --- | --- |
| `boids_level.gd` / `.tscn` | The scene: sky, birds, voices, snare, dial. |
| `flock_sim.gd` | `FlockSim` — boids plus flock membership, pure and testable. |
| `bird.gd`, `flock.gd` | The sim's data. |
| `scatter_charge.gd` | `ScatterCharge` — when the rare full scatter fires. |
| [`core/audio/rhythm/`](../../../core/audio/rhythm/) | `Rhythm`, `RhythmTable`, `TapReader` — the polyrhythm model. |

## Adding a rhythm

Add an entry to `RhythmTable.default_table()`. The grid — the least common
multiple of every rhythm's pulses and the bar's beats — follows by itself:
12 steps a bar for 3, 4 and 6; 60 with a 5; 420 with a 7. Nothing else in
the level names a rhythm. At 420 steps a bar the grid sequencer fires about
200 steps a second at 120 bpm, which is worth revisiting when 7 lands.

## Known rough edges

- **Timing is `WallClockMusicTime`'s:** live notes land within about a mix
  block (roughly 10 ms) of the grid. `tap_offset_seconds` is there to cancel
  press-to-hear latency once it has been measured on the Deck; it is 0 until
  then.
- **The sim is O(n²)** over 64 birds, about 1.5 ms a step on a desktop. A
  spatial grid is the fix if the Deck needs it.
- **Every constant was picked by eye and a headless balance run,** not by
  ear. The sky neither fills up nor empties when left alone, and favouring a
  rhythm shifts it over tens of seconds without wiping it out. That leaves
  the full scatter as the event it is meant to be.
