# Motion

Device tilt and jog, behind a port.

## Why there is a port here

Not doctrine — the accelerometer can be read neither in CI nor on a
development desktop. Without a seam, tilt would be untestable and
undevelopable anywhere but a phone, and every change would cost a device
build to evaluate.

So there is exactly one interface, [`MotionSource`](motion_source.gd), and
three adapters behind it:

| Adapter | For |
| --- | --- |
| `SteamInputMotionSource` | every controller Steam supports — a Deck, a DualSense, a Pro pad |
| `DeviceMotionSource` | a phone's sensors, through `Input` |
| `KeyboardMotionSource` | desktop — arrows tilt, space jogs |
| `ScriptedMotionSource` | tests, and replaying a recorded gesture |

The keyboard adapter synthesises a **gravity vector**, not a tilt. Producing a
tilt directly would be less code and would leave the interesting half of the
pipeline — calibration, basis projection, filtering — unexercised until the
first device build.

## The pipeline

```
source -> calibration -> tilt -> dead zone -> smoothing -> tilt_changed
                      -> planar acceleration -> jog detector -> jogged
```

Everything between the source and the signals is pure, and all of it is
tested. `MotionInput` is the only [Node]; it picks a source, runs the
pipeline, and emits.

## Using it

```gdscript
var motion := MotionInput.new()
add_child(motion)
motion.tilt_changed.connect(_on_tilt)   # Vector2, length 1 = fully tilted
motion.jogged.connect(_on_jog)          # Vector2, once per shake
```

`MotionTiltDriver` joins it to a `PanoramaLookCamera`, which is how tilting a
device tilts a level — see [the panorama level's README](../../features/levels/panorama/README.md#tilting-the-device-tilts-the-scene).

Consumers find it through the `motion_input` group. It is a plain node rather
than an autoload so a test — or a second local player — can own its own;
promote it in `project.godot` if it ever needs to be global.

To swap the source, in a test or for a replay:

```gdscript
motion.set_source(my_source)   # also ends the startup sensor probe
```

## Picking a source

`MotionInput` tries the real sources in turn, giving each `PROBE_SECONDS` to
report, and falls back to the keyboard once they are exhausted. A source that
could not possibly be there is never waited on: `SteamInputMotionSource` is
only constructed where the GodotSteam extension exists at all, which is one
`ClassDB` lookup and costs nothing in a build without it.

Whatever it lands on, it is something that reports. That is the invariant the
probe exists for — a control wired to a silent source is dead, and silently
so.

## Controllers, and why Steam reads them

A Steam Deck has a six-axis IMU, a DualSense has one, a Switch Pro pad has
one, and **none of them reach Godot**. `Input`'s sensor functions are fed on
Android and iOS only, and Godot exposes no gamepad sensors at all
([godot-proposals#2829](https://github.com/godotengine/godot-proposals/issues/2829)),
so `DeviceMotionSource` reports nothing on any of them, and a Deck would be a
desktop with no keyboard.

Steam already reads those sensors for its own gyro configurations, and
`ISteamInput` hands the result over sensor-fused, in known units, for every
controller it supports. `SteamInputMotionSource` asks it once a frame:
`runFrame()`, the first connected controller handle, then `getMotionData()`.

**Why not read the device directly.** An earlier version of this read the
Deck's raw HID stream from `/dev/hidraw*` through `cat`, since `FileAccess`
refuses a character device. It worked in the narrow sense — numbers arrived
and moved when the device moved — but every byte offset and scale in it was
reverse-engineered by fitting a single resting pose, and it showed: gravity
measured **0.92 g held upright and 0.49 g in a stand**, where a resting
accelerometer reads 1 g in *every* orientation. It was also one device's
report format on one kernel version, for one machine on the shelf. Steam
Input is the interface Valve maintains, and shipping on Steam means it is
there anyway.

**What Steam needs.** The client running, and an app ID — `DEV_APP_ID` (480,
Valve's public test app) until the game has its own. Failing to initialise is
not an error worth reporting: it is what happens on any machine without Steam,
and the probe simply moves on to the next source. Exported builds want a
`steam_appid.txt` holding that ID beside the binary while there is no real
app ID; `scripts/deck-build.sh` writes one. Leave it out of a shipped build.

**Only the accelerometer is used.** Tilt is an orientation against gravity,
which acceleration gives directly and without drift. Steam also reports
absolute rotation and angular velocity; a complementary filter using them is
the obvious follow-up if a fast tilt ever feels late to arrive, and
`MotionSource` has nowhere to carry them today.

## Calibration

There is no assumed hold orientation. `MotionCalibration` takes whatever
gravity was doing when the player last calibrated as level, and builds a screen
basis from it — so the controls work held upright, flat on a table, or anywhere
between. Assuming "down is -Y" is the usual way tilt controls come to feel
wrong for everyone who does not hold the device the way the developer did.

`MotionInput.calibrate()` re-zeros to the current pose. Wire it to a recentre
button; the demo has it on `C`.

## Two things that are easy to get wrong

Both are invisible at the call site, so both are pinned by tests:

- **Smoothing** is a time constant in seconds, not a per-frame factor. A second
  of smoothing lands in the same place at 30 fps and at 144.
- **The jog detector** is a Schmitt trigger *and* a cooldown. A bare threshold
  fires several times per shake as the reading rattles across it; a bare
  cooldown fires again the moment it lapses if the player is still shaking.

The dead zone rescales what survives it, so the control ramps from zero at the
edge rather than jumping — a bare threshold reads as a broken sensor.

## Sensor availability

`DeviceMotionSource` reports availability from **observed readings**, not from
a platform allow-list. A platform that reports works even though it could not
be tested here; one that claims sensors it never feeds is correctly treated as
absent. `MotionInput` gives the sensors `PROBE_SECONDS` to say something before
falling back to the keyboard, because they are not always live on frame one.

Godot has no linear-acceleration sensor, so user acceleration is the
accelerometer minus gravity. Where the gravity sensor is silent but the
accelerometer works, the adapter low-passes the raw signal to estimate gravity
itself — otherwise the whole signal reads as player motion and the jog detector
fires on nothing but gravity.

## Settling it on hardware

CI has no Steam and no controller, so the tests cover the pipeline and the
silent path: a source that cannot start reports nothing and hands on. What
only a device can settle is the **axis convention** — which reported axis is
screen-right, screen-up or out-of-screen, and in which sign. Calibration is
orientation-agnostic by construction, which should absorb surprises there,
but the sign of a roll is not something a test can tell you.

`scripts/run.sh motion` shows the live source, the raw gravity axes, the tilt,
and a scene leaning with it. Tilt right; if the horizon rolls the wrong way, a
span on `MotionTiltDriver` goes negative. Any level with tilt also carries
`MotionDebugOverlay` (F3, or the gamepad's Y button, hides it), which is the
same readout on top of real gameplay.

The check worth making first, because it catches a whole class of unit and
axis mistakes at once: **gravity's magnitude must read about 9.81 in every
orientation.** A magnitude that changes as the device turns means the units or
the axes are wrong, whatever the direction looks like.
