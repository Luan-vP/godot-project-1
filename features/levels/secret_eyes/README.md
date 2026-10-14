# The eye band

[`FloatyEye`](floaty_eye.gd) thingies drifting on the host's
[fluid](../../fluid/README.md), in a painterly style, plus a dusting of
[`Floater`](../../floaters/README.md) debris, each eye playing a part of the
band while it stays off the walls. Like every level it is a foreground over a
`SharedLayers` host: the tank and the band are the host's (see
[the carousel README](../carousel/README.md#the-level-format)).

The eyes started as the fluid demo's placeholder, built from a misreading of
"eye floaters" as floating eyeballs, and stayed because the band made them
worth keeping.

## Controls

Drag to stir and paint, WASD to tilt, `Space` to jog, `C` to recalibrate,
`R` to empty the tank, `B` to make everyone blink. On a device with sensors
WASD and space give way to the real accelerometer with no code change.

L1/R1 (`Q`/`E`) move the band's key down/up a fourth
and L2/R2 (`Z`/`X`) down/up a fifth, from the next step. The move is round the
circle of fifths, so every part stays in its register: two fourths up lands a
whole tone *below* where you started, not an octave and a third above. The
readout shows where the key sits relative to the song, -5 to +6.

## Access

The plain tank, without the band, is gone. The eye band is the first level in
the fluid carousel (`features/levels/carousel/`) and is listed on its own as
"Eye band" in `features/ui/demo_menu/`.

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
The arrows move the tempo, as in every scene; the live parts follow at once,
and the rendered drums play faster or slower to keep up.
The readout shows the song and the section playing. Push an eye against a wall (tilt with WASD, or stir) and
its part drops out at the next bar; let it drift free and it comes back.

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
arrangement you hold against a drifting medium — using walls for edges, and with the rule inverted: here staying *off*
the edge is what plays.

## Pieces

Kept together because they only make sense as a set:

| File | What it is |
| --- | --- |
| `eye_band.gd` | `EyeBand` — one part of the music per eye, heard while it is clear of the walls. The music itself is [`Band`](../../../core/audio/band.gd)'s; this only decides which parts are wanted. |
| `eye_band_songs.gd` | `EyeBandSongs` — the four songs the band picks from. |
| `eye_band_demo.gd` | The level: the eyes over the host's tank, input, an `EyeBand` driving the host's band, rings round the eyes and a parts readout. |
| `floaty_eye.gd` | `FloatyEye` — a [`FluidBody`](../../fluid/fluid_body.gd) with a face. |
| `eye.gdshader` | The procedural eye look: squash-along-motion and gaze read off the fluid. |
| `eye_band_demo.tscn` | The single-node scene entry point. |
