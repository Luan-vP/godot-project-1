# Panorama level

The main level's core mechanic: a [`PanoramaLookCamera`](../../player/panorama_look_camera.gd)
at the centre of a sphere, looking around an equirectangular background, with
the [fluid](../../fluid/README.md) and its [floaters](../../floaters/README.md)
as a screen-space overlay in front of it. See [issue #7](https://github.com/Luan-vP/godot-project-1/issues/7)
and [issue #14](https://github.com/Luan-vP/godot-project-1/issues/14).

## One `Level`, one assignment

[`Level`](../level.gd) is the single resource a level is defined by: the
background, the medium's `FluidConfig`, how much debris drifts in it, how
hard it bends the view, and how sensitive looking around feels. Assigning
`PanoramaLevel.level` is the whole job of loading a level — nothing about the
scene or the script needs to change to retune one.

`Level` references a `FluidConfig` rather than inlining its fields, for the
same reason `FluidConfig` and `PainterlyStyle`/`RefractionStyle` are kept
apart (see the fluid README): retuning a level's medium should never risk
changing another level's physics unless they deliberately share the same
`FluidConfig` asset.

`PanoramaLevel` is built in code, the same as the secret eye and vitreous
levels — the medium overlay has to be sized against the actual viewport, and
`FluidConfig` is only read once when its `FluidSimulation` is built, so
changing `level` tears down and rebuilds the overlay rather than editing it
in place.

## Level 1: pure exploration

[`level_one.tscn`](level_one.tscn) is the first level a player actually
plays, built the same way as the two examples below: a single node whose
script assigns `Level.pure_exploration()` before calling up to
`PanoramaLevel._ready()`. See [issue #22](https://github.com/Luan-vP/godot-project-1/issues/22).

Per [issue #9](https://github.com/Luan-vP/godot-project-1/issues/9), it has no
score, no timer, and no end condition — `edge_source` is left `null`, and
nothing outside `Level` tracks time or progress. Leaving is the only way it
ends.

It reuses `overcast_sky()`'s idea — a bright, high-key sky where floaters read
against a broad, uniform field — but tunes for legibility over that preset's
crowded drama: fewer, larger floaters and less background bend, so a first-time
player can follow a single floater rather than take in a whole swarm. Worth
checking on a real playthrough (this is a content-and-tuning issue, judged by
looking, not by tests) against the three behaviours the floaters mechanic
promises: the lag, the settling, and whether a floater evades a straight-on
look. That last one needs the medium to react to where the player is looking,
which nothing does yet — see "Not yet" below — so until that lands, level 1 can
only prove the first two.

## Two examples

`Level.overcast_sky()` and `Level.dim_interior()` are tuned presets — the
[`overcast_sky.tscn`](overcast_sky.tscn) and [`dim_interior.tscn`](dim_interior.tscn)
scenes are each a single node whose script assigns one of them before calling
up to `PanoramaLevel._ready()`. They exist to prove the resource actually
abstracts a level rather than just moving the same numbers somewhere else:

| | Overcast Sky | Dim Interior |
| --- | --- | --- |
| Floaters | 220, unmissable | 8, barely there |
| Distortion | 0.02, a visible ripple | 0.002, almost nothing |
| Medium | brisk, `viscosity` 200 | thick and still, `viscosity` 1200 |
| Look sensitivity | 1.0 | 0.6, slower and heavier |

Both panoramas are generated in code (`Level._gradient_panorama`), the same
reason `refraction_demo.gd` paints its checkerboard in code rather than
shipping an image: no binary asset, so no export-size cost. A real
photographic equirectangular background can replace either later by simply
assigning a loaded `Texture2D` to `Level.panorama_texture` instead — check
what that does to the Linux/Windows export size in `build.yml` before
committing more than one, since `.png`/`.jpg` are already tracked with Git
LFS but still ship inside the exported PCK.

## How the background is rendered

`WorldEnvironment` with a `Sky` whose `sky_material` is a `PanoramaSkyMaterial`
— the purpose-built way to show an equirectangular image behind a `Camera3D`.
The fallback the issue called out, an inverted sphere mesh, would only be
worth it if the sky path turned out to fight the 2D overlay; the overlay reads
`hint_screen_texture` rather than rendering into the sky, so there is nothing
to fight and the simpler approach stands.

## Look input and angular velocity

Looking is mouse and gamepad stick, composed rather than switched — see
[`core/look`](../../../core/look/README.md) for why. `PanoramaLookCamera`
exposes `angular_velocity` (`Vector2`, radians/second, x = yaw, y = pitch) as
a plain property; the floaters mechanic reads it from here rather than
recomputing it.

Pitch is clamped short of vertical (`max_pitch_degrees`, default 85°) so the
horizon cannot roll over. Yaw wraps to `[-PI, PI]` rather than growing without
bound, and the wrap is a jump of exactly one full turn — visually identical,
so it produces no seam.

`PanoramaLookCamera.sensitivity` multiplies every configured `LookSource`'s
contribution in one place — what `Level.look_sensitivity` drives — rather
than a level having to retune each source's own sensitivity individually.

## Comfort options

[`ComfortSettings`](../../../autoload/ComfortSettings.gd) (issue #17) lets a
player pull back from a level's tuned `distortion_strength` and
`look_sensitivity`, and reduce how much a floater lags and overshoots behind
the current — the whole mechanic is "move the view, watch the image distort",
which some players find sickening. `PanoramaLevel._apply_level` and
`_rebuild_medium` scale a level's numbers through it before applying them, so
the values above stay the tuned defaults a player starts from, not the
accessible ones. Settings persist through `SaveManager` and are read once when
a level's medium is built, not live while one is already running — see the
[comfort settings demo](../../ui/comfort_settings/comfort_settings_demo.gd).

## Not yet

The medium is idle beyond its own `ambient_current`: nothing stirs it from
gaze yet. The vitreous level's README already calls out the intended input —
`PanoramaLookCamera.angular_velocity` driving a stir, the way a real eye's
saccades disturb the vitreous humour — left for its own issue.
