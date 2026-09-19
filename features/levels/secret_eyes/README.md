# Secret level: the eye tank

What used to be the fluid demo, kept as a level in its own right. A tank full
of [`FloatyEye`](floaty_eye.gd) thingies drifting on the [fluid](../../fluid/README.md),
in a painterly style, plus a dusting of [`Floater`](../../floaters/README.md)
debris.

It moved here — unchanged — because the eyes were never meant to be the point
of the game; they were a placeholder built from a misreading of "eye
floaters" as floating eyeballs. The tank itself is good enough to keep around
as a secret rather than throw away.

## Controls

Drag to stir and paint, `WASD` to tilt, `Space` to jog, `C` to recalibrate,
`R` to empty the tank, `B` to make everyone blink. On a device with sensors
WASD and space give way to the real accelerometer with no code change.

## Secret access

**Decision:** once a main level exists, this scene is reached by holding
`Shift` while starting the game, rather than through any in-game menu.

There is no main level yet to hide this behind, so wiring up the `Shift`
check would have nothing to gate; that is left for whichever issue adds the
main level. Until then `run/main_scene` is the development demo menu
(`features/ui/demo_menu/`), which lists this level alongside the rest. When
the main level lands, it takes over `run/main_scene` and the menu either
drops this entry or stops shipping, so the secret stays one.

## Eye band

`eye_band_demo.tscn` (`scripts/run.sh band`) is the same tank with music in
it. [`EyeBand`](eye_band.gd) gives each eye one part of a song — biggest eye
the beat, then bass, pads, melody, arp, ghost drums, and the smallest the
shimmer — and a part plays only while its eye floats clear of the tank walls.

Each time the band starts it picks one of four songs from
[`EyeBandSongs`](eye_band_songs.gd) at random: *Glass Tide* (A minor, 70 bpm),
*Low Sun* (D dorian, 64 bpm, half-time), *Night Pool* (F major, 74 bpm, running
arp) and *Slow Orbit* (E minor, 60 bpm). A song is sections of chords that
branch into one another as it plays, so the progression wanders instead of
looping four bars; a fill plays over the beat on the last bar of each section.
The readout shows the song, the section and the tempo it is playing at. Push
an eye against a wall (tilt with `WASD`, or stir) and its part drops out at
the next bar; let it drift free and it comes back.

The arrow keys drive the tempo instead of tilt here — `Up`/`Down` nudge it
±2 bpm, `Left`/`Right` ±10 bpm, clamped to 30-180 bpm. Note holds and the
rendered drum loops' pitch both follow the live tempo (#72); see
[`AudioManager.set_tempo_bpm`](../../../autoload/AudioManager.gd) and
`docs/music-player-controls-scope.md` for why the drums are pitched rather
than re-rendered.

Left alone, eyes in this tank random-walk into the walls within about ten
seconds and stick there, which would silence the band almost at once. The
demo adds a soft spring towards the middle (`CENTRE_PULL`, 0.1). At 0.4 a
free tank played nearly the whole arrangement and a held tilt pinned most
eyes; at 0.8 a full tilt pinned nothing. 0.1 was picked by ear to leave the
eyes looser, so keeping the band playing takes some work.

A ring round each eye shows its state: bright while playing, red while pressed
against a wall, faint while silent. Contact has hysteresis — an eye takes hold
of a wall within 10 px of its rim and lets go only past 40 px — so one bobbing
at the edge does not stutter its part.

This is a sketch of the idea in #9 — the music is the reward for an
arrangement you hold against a drifting medium — using walls where the real
game will use panorama edges, and with the rule inverted: here staying *off*
the edge is what plays.

## Pieces

Kept together because they only make sense as a set:

| File | What it is |
| --- | --- |
| `fluid_demo.gd` | Builds the tank, drops the eyes in, wires up input. |
| `eye_band.gd` | `EyeBand` — one part of the music per eye, heard while it is clear of the walls. |
| `eye_band_songs.gd` | `EyeBandSongs` — the four songs the band picks from. |
| `eye_band_demo.gd` | The tank plus an `EyeBand`, rings round the eyes and a parts readout. |
| `floaty_eye.gd` | `FloatyEye` — a [`FluidBody`](../../fluid/fluid_body.gd) with a face. |
| `eye.gdshader` | The procedural eye look: squash-along-motion and gaze read off the fluid. |
| `fluid_demo.tscn` | The single-node scene entry point. |
