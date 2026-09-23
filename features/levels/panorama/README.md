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

## Tilting the device tilts the scene

The level owns a `MotionInput` and a
[`MotionTiltDriver`](../../player/motion_tilt_driver.gd), so on a handheld —
the Steam Deck, a phone — leaning the device leans the view. On a desktop the
arrow keys stand in for the sensors, which is how the feel gets judged without
one; see [`core/motion`](../../../core/motion/README.md).

**A lean, not a turn.** Tilt lands on `PanoramaLookCamera.tilt_offset` rather
than on its yaw and pitch. Looking around accumulates — a stick held over
means keep turning — and a held tilt does not: it means hold the scene at that
angle, and letting go brings it back. Integrating it into the heading would
give a lean that never comes back and a horizon that drifts away from level
whenever the player's hands do.

The scene tilts the way the view through a window does: tip the device right
and the horizon rolls left, staying where it was in the world rather than
following the screen round. Spans are small (12° of roll, 6° of pitch at full
tilt) because this sits on top of wherever looking around has left the camera.

`tilt_offset` is deliberately **not** in `angular_velocity`. That number is
how fast the player is looking around and the floaters mechanic hangs off it;
a device held at a lean is not a gaze sweeping across the view, and feeding it
in would swish the medium for as long as the lean was held.

`recentre_tilt` — `C`, or the right stick click — takes whatever pose the
player is holding as level. A handheld is never held the way the last player
held it, and `MotionCalibration` assumes no hold orientation, so this is the
control that makes the rest of it work.

## Comfort options

[`ComfortSettings`](../../../autoload/ComfortSettings.gd) (issue #17) lets a
player pull back from a level's tuned `distortion_strength` and
`look_sensitivity`, scale back how far device tilt leans the scene, and reduce
how much a floater lags and overshoots behind the current — the whole mechanic is "move the view, watch the image distort",
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
