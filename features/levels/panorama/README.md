# Panorama level

The main level's core mechanic: a [`PanoramaLookCamera`](../../player/panorama_look_camera.gd)
at the centre of a sphere, looking around an equirectangular background. See
[issue #7](https://github.com/Luan-vP/godot-project-1/issues/7).

Everything else in the floaters mechanic hangs off this scene, because the
floaters are seen *against* this background and the act of looking is what
stirs them — but they are screen-space and belong in a `CanvasLayer` sibling
added later, not here. This scene stays the background and the camera alone.

## How the background is rendered

`WorldEnvironment` with a `Sky` whose `sky_material` is a `PanoramaSkyMaterial`
— the purpose-built way to show an equirectangular image behind a `Camera3D`.
The fallback the issue called out, an inverted sphere mesh, would only be
worth it if the sky path turned out to fight the 2D overlay; there is no
overlay yet, so there is nothing to fight, and the simpler approach stands
until that changes.

## The image is not hardcoded

`PanoramaLevel.panorama_texture` is `@export`ed, not baked into the scene, so
a level can supply its own equirectangular image. It is applied to the
`PanoramaSkyMaterial` at `_ready`. There is no image checked in yet — wiring
an actual level's art to this `@export` is for whichever level-definition
work picks a background per level.

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
