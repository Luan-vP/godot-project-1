# Look

Camera yaw/pitch input, behind a port, the same shape as [`core/motion`](../motion/README.md).

## Why this sits beside `MotionInput` rather than inside it

`MotionInput` picks exactly **one** source — sensors, or the keyboard fallback
— because device tilt has exactly one physical ground truth: the phone either
is or is not held a certain way. Look input has no such single truth. A
player can nudge the camera with a gamepad stick while also flicking the
mouse in the same frame, and both should land. Wedging that through
`MotionInput`'s single-active-source model would mean either dropping one
input or teaching that pipeline a second, different composition rule it
doesn't otherwise need.

So [`LookInput`](look_input.gd) follows the same shape — a port
([`LookSource`](look_source.gd)), adapters behind it, one place the rest of
the game talks to — but **sums** every configured source's contribution each
frame instead of switching between them. `GamepadLookSource` reuses
`MotionFilter.apply_deadzone` from `core/motion` for its dead zone, since
that rescale is the same problem in both places and is already pure and
tested.

| Adapter | For |
| --- | --- |
| `MouseLookSource` | desktop and anywhere else with a mouse |
| `GamepadLookSource` | the right stick |
| `ScriptedLookSource` | tests, and replaying a recorded look |
| `EyeGazeLookSource` | eye tracking on a device with the gaze plugin — see [gaze/README.md](gaze/README.md) |

Touch drag is not implemented. The acceptance criteria asked for the mouse
plus at least one of gamepad stick or touch drag; the gamepad covers that,
and touch is a reasonable follow-up `LookSource` adapter whenever it's
needed — the port does not change to add it.

In the meantime a phone is not left without look: Godot's
`emulate_mouse_from_touch` (on by default) turns a finger drag into
`InputEventMouseMotion`, which `MouseLookSource` already reads. It turns at
the mouse's sensitivity, which is a guess for a thumb, and cursor capture
means nothing there.

## Using it

[`PanoramaLookCamera`](../../features/player/panorama_look_camera.gd) owns a
`LookInput` exactly the way a `MotionInput` consumer owns its motion node:

```gdscript
var camera := PanoramaLookCamera.new()
add_child(camera)               # LookInput is created and added in _ready
camera.angular_velocity         # Vector2, radians/second, x = yaw, y = pitch
```

To swap the mix, in a test or to add a source:

```gdscript
camera.get_look_input().clear_sources()
camera.get_look_input().add_source(my_source)
```

## Source lifecycle

`LookSource.start()` / `stop()` default to nothing. `LookInput` calls them as
sources join and leave a mix that is in the tree, because eye gaze holds the
device camera open and must not do so while nothing is looking.
`LookInput.calibrate()` (bound to `C` and a double tap by
`PanoramaLookCamera`) re-takes neutral on any source that has one.

## Mouse capture

`PanoramaLookCamera` captures the mouse by default (`capture_mouse`) so a
look drag has room to turn indefinitely instead of stalling at the window
edge. `Escape` releases it; clicking recaptures.

## Not verified

Same caveat as `core/motion`: no device or GPU has run this. `MouseLookSource`
and `GamepadLookSource` read `Input` directly and are not exercised by tests
for the same reason `DeviceMotionSource` and `KeyboardMotionSource` aren't —
there is nothing headless CI can feed them. `LookInput`'s composition and
`PanoramaLookCamera`'s yaw/pitch/clamp/angular-velocity logic are pure enough
to test through `ScriptedLookSource`, and are.
