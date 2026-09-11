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

Drag to stir and paint, arrows to tilt, `Space` to jog, `C` to recalibrate,
`R` to empty the tank, `B` to make everyone blink. On a device with sensors
the arrows and space give way to the real accelerometer with no code change.

## Secret access

**Decision:** once a main level exists, this scene is reached by holding
`Shift` while starting the game, rather than through any in-game menu.

`project.godot`'s `run/main_scene` still points directly at
[`fluid_demo.tscn`](fluid_demo.tscn) for now — there is no main level yet to
hide this behind, so wiring up the `Shift` check would have nothing to
gate. That wiring is left for whichever issue adds the main level.

## Pieces

Kept together because they only make sense as a set:

| File | What it is |
| --- | --- |
| `fluid_demo.gd` | Builds the tank, drops the eyes in, wires up input. |
| `floaty_eye.gd` | `FloatyEye` — a [`FluidBody`](../../fluid/fluid_body.gd) with a face. |
| `eye.gdshader` | The procedural eye look: squash-along-motion and gaze read off the fluid. |
| `fluid_demo.tscn` | The single-node scene entry point. |
