# Eye gaze

Eye tracking as a look input: where the player's eyes point turns the
panorama camera. It plugs into [`LookInput`](../look_input.gd) as one more
`LookSource`, [`EyeGazeLookSource`](../sources/eye_gaze_look_source.gd), so it
sums with the mouse and stick like any other source.

```
native plugin -> EyeGazeBackend -> EyeGazeSample -> EyeGazeFilter -> EyeGazeLookSource -> LookInput
 (ARKit, ...)     (port)            (one reading)    (the mapping)    (LookSource adapter)
```

## Two ports, not one

Gaze is not yet a look rotation. How a gaze becomes a turn is a feel decision
that should be testable without a camera and changeable without touching
native code, so there are two seams:

| Port | Adapters |
| --- | --- |
| `EyeGazeBackend` — readings | `NativeEyeGazeBackend` (device plugin), `ScriptedEyeGazeBackend` (tests), `PointerEyeGazeBackend` (mouse standing in for eyes, desktop) |
| `LookSource` — turns | `EyeGazeLookSource`, which owns an `EyeGazeFilter` |

## The native contract

Every platform's plugin registers an engine singleton named **`EyeGaze`**
with the same methods. GDScript finds it with `Engine.has_singleton` and never
asks which OS it is on.

| Method | |
| --- | --- |
| `start()` | Open the camera and begin tracking. Asks for camera permission the first time. Idempotent. |
| `stop()` | Stop tracking and release the camera. Idempotent. |
| `get_sample() -> Dictionary` | The latest reading; cheap, called every frame. |
| `get_api_version() -> int` | `1`. |

`get_sample()` keys (all optional; a missing key means "nothing known"):

| Key | Type | Meaning |
| --- | --- | --- |
| `state` | int | `0` UNAVAILABLE (no hardware / not supported), `1` STOPPED, `2` STARTING (camera or permission pending), `3` PERMISSION_DENIED, `4` NO_FACE, `5` TRACKING, `6` FAILED (see `message`) |
| `gaze_yaw`, `gaze_pitch` | float, radians | Gaze direction relative to the **screen**, including head pose. Yaw positive towards the screen's right as the player sees it; pitch positive towards the top of the screen. Zero is along the screen normal through the front camera. |
| `head_yaw`, `head_pitch` | float, radians | Head orientation relative to the screen, same convention. Informational. |
| `confidence` | float 0..1 | How far the backend trusts this gaze. |
| `blink` | float 0..1 | How closed the eyes are (mean of both). |
| `timestamp` | float, seconds | Monotonic capture time of the camera frame. Unchanged means no new frame. |
| `message` | String | Detail for a debug readout. |

Screen-relative, not head-relative, because on a phone what the game can
respond to is where on the screen the player is looking, and the phone moves
in the hand as much as the eyes move in the head. Camera frames never leave
the device; the plugins make no network calls.

## The mapping: rate control around a calibrated neutral

**Hold a look off-centre and the camera turns that way, faster the further
out; look at the middle and it holds still.**

```
sample -> usable? -> smooth gaze -> deflection from neutral -> dead zone -> curve -> rate -> ease
```

1. **Usable?** Tracking, `confidence >= min_confidence`, `blink < max_blink`,
   and a new camera frame within `stale_after`. Unusable readings are ignored
   as if the frame never came.
2. **Smooth gaze** with a time constant (`gaze_smoothing`) against fixational
   jitter. On (re)acquiring a face it snaps rather than sweeping from a stale
   value.
3. **Dropouts.** Within `dropout_grace` the last good gaze holds, so a turn
   carries on through a blink; past it the gaze is dropped and the rate eases
   to zero.
4. **Calibration.** Neutral is the time-averaged gaze over
   `calibration_seconds`. It runs by itself on the first usable gaze
   (`auto_calibrate`), and again on `calibrate()` — the debug demo's button,
   and `C` or a double tap in a panorama level. Nothing turns until there is a
   neutral, or while one is being taken. The front camera sits above the
   screen, so without this a look at the middle reads as looking down.
5. **Deflection** is `(gaze - neutral) / span` per axis — an ellipse, since a
   portrait phone spans about twice the angle vertically.
6. **Dead zone and curve.** Clamped to length 1 (looking off the screen turns
   no faster than looking at its edge), dead zone rescaled so the turn ramps
   from zero at the zone's edge, then raised to `exponent`.
7. **Rate** = shaped deflection × `max_rate`, then eased with `turn_smoothing`.

The maths is pure in [`EyeGazeMapping`](eye_gaze_mapping.gd); the state is in
[`EyeGazeFilter`](eye_gaze_filter.gd). Both are covered by GUT tests through
`ScriptedEyeGazeBackend`, including frame-rate independence and a 120 Hz
game over a 60 Hz camera.

### Tunables (on `EyeGazeFilter`)

| Field | Default | Trades |
| --- | --- | --- |
| `span` | 7°, 14° | Angle counted as full deflection; roughly a portrait phone's edges at 30 cm. Smaller = more sensitive. |
| `deadzone` | 0.4 of span | Stillness vs responsiveness. Must swallow tracker noise (a few degrees) and calibration error. |
| `exponent` | 1.6 | Gentle near the zone vs linear. |
| `max_rate` | 1.4, 0.9 rad/s | Turn speed at the edge; pitch slower because it clamps. |
| `gaze_smoothing` | 0.08 s | Jitter vs lag on the gaze point. |
| `turn_smoothing` | 0.25 s | Dwell: a glance barely starts a turn, a held look builds to full. |
| `min_confidence` | 0.5 | |
| `max_blink` | 0.5 | |
| `dropout_grace` | 0.25 s | Bridges a blink (0.1–0.3 s). |
| `stale_after` | 0.3 s | How long a stalled backend is believed. |
| `calibration_seconds` | 0.6 s | |

`PanoramaLookCamera.sensitivity` (from `Level.look_sensitivity`) scales the
result like every other source.

These defaults are first guesses from geometry and published front-camera
accuracy, not from play. The [gaze debug demo](gaze_debug_demo.tscn) is where
they get judged.

### Alternatives rejected

- **Position control** — gaze angle maps to a camera angle offset. It is a
  feedback loop that fights itself: the camera turns towards what the player
  looks at, that thing moves towards the middle, their eyes follow it, the
  gaze returns to centre and the camera swings back. It also cannot reach
  anything behind the player on a 360° panorama. Rate control is the same loop
  with the sign that settles: the turn stops once the target is centred.
- **Dwell-to-snap** — look at something for N ms and the camera jumps to
  centre it. Precise for UI, but a jump is not "looking around", and it would
  slam the fluid rather than swish it.
- **Saccade velocity drives the look** (eye movement speed becomes camera
  speed, as mouse motion does). Closest to how real floaters are stirred, but
  a front camera's gaze is noisy at 60 Hz: differentiating it amplifies
  exactly the jitter this needs to suppress, and the camera would drift back
  nowhere when the eyes stop. Coupling eye motion to the fluid directly is
  closer to #42's `GazeFluidDriver` than to a `LookSource`.
- **Head pose instead of gaze** — steadier signal, but it is not eye tracking,
  and a phone held in the hand makes "head relative to screen" mostly hand
  motion. Gaze relative to the screen already contains head pose, and the
  plugin still reports head pose separately should a blend be wanted.
- **A One Euro filter** instead of plain exponential smoothing. It adapts its
  cutoff to speed, which matters for a cursor that has to land precisely. Here
  the output is a rate that is itself eased, so the lag it saves is invisible,
  and a time constant matches every other filter in the codebase. Worth
  revisiting if the gaze *marker* ever drives something precise.
- **No auto-calibration, assume a fixed camera offset.** The offset depends on
  the phone model, grip and distance; averaging the first half-second of gaze
  is right far more often, and recalibrate is one tap away.

## Wiring

`LookInput` adds an `EyeGazeLookSource` to its default mix when
`NativeEyeGazeBackend.is_present()` — only builds that carry the plugin —
and `LookInput.eye_tracking` is on (the default). Desktop builds have no
plugin, so their mix is unchanged. The source's `is_available()` is true only
once a face has actually been tracked.

The camera is a privacy and battery cost, so sources now have `start()` /
`stop()` on the `LookSource` port: `LookInput` starts them when they join a
mix in the tree and stops them when they leave it or it leaves the tree.
`NativeEyeGazeBackend` counts starts across instances, so the debug demo and a
look camera sharing one device camera cannot switch it off under each other.

## The debug demo

`scripts/run.sh gaze`, or **Eye Gaze** in the demo menu. It shows tracking
state, raw gaze and head angles, confidence, blink, camera frames per second,
the calibrated neutral, the deflection and turn rate, a heading the turn
accumulates into, the dead-zone and full-deflection ellipses, a hollow marker
for the raw gaze and a filled one for what the mapping steers with (amber
while a blink is being bridged). Buttons: Calibrate, Stop/Start, and a switch
between the device and the pointer.

Without the plugin it falls back to the pointer: `C` calibrates (the button
would move the pointer off-centre while it listens), `Space` holds a blink,
`F` hides the face, `M` switches backend, `R` resets the heading.
