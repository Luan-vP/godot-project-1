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
| `DeviceMotionSource` | the real sensors |
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

Consumers find it through the `motion_input` group. It is a plain node rather
than an autoload so a test — or a second local player — can own its own;
promote it in `project.godot` if it ever needs to be global.

To swap the source, in a test or for a replay:

```gdscript
motion.set_source(my_source)   # also ends the startup sensor probe
```

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

## Not verified

No device or GPU has run any of this. The sensor adapter's behaviour against
real hardware — axis conventions in particular — is reasoned from Godot's API,
not observed. The calibration is orientation-agnostic by construction, which
should absorb axis surprises, but the first device build is where that gets
settled.
