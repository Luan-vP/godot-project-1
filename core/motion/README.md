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
| `DeviceMotionSource` | a phone's sensors, through `Input` |
| `DeckMotionSource` | the Steam Deck's IMU, read from Linux directly |
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
could not possibly be there is never waited on: `DeckMotionSource` is only
tried where the Deck's sensor device actually exists, which is a look at
`/sys` and costs nothing anywhere else.

Whatever it lands on, it is something that reports. That is the invariant the
probe exists for — a control wired to a silent source is dead, and silently
so.

## The Steam Deck

The Deck has a six-axis IMU and **none of it reaches Godot**. `Input`'s sensor
functions are fed on Android and iOS only, and Godot exposes no gamepad
sensors at all ([godot-proposals#2829](https://github.com/godotengine/godot-proposals/issues/2829)),
so `DeviceMotionSource` reports nothing there and the Deck would be a desktop
with no keyboard.

Linux publishes the sensors itself, without Steam — but not, on real
hardware, the way the first version of this assumed. That version looked for
an evdev device named `Steam Deck Motion Sensors`, the way `hid-steam`'s own
documentation describes it. On a Deck running
`6.11.11-valve27-1-neptune-611` that device does not exist: `hid_steam` loads
with only its `lizard_mode` parameter, nothing under `/sys/class/input`
matches, and the IMU is not on IIO either. **Retrying the evdev path from the
godot-proposals thread alone will not find it on this kernel** — it needs a
different device entirely.

What is there, and readable without root, is a `hidraw` node for the
controller's own raw HID interface — the same one Steam itself reads for
gyro input, and multiple readers are allowed, so reading it alongside Steam
is fine. `hid-steam` binds several `hidraw` nodes to one physical controller
(mouse, keyboard, controller state); the motion-streaming one is identified
by its `uevent` naming driver `hid-steam` and a phys ending `input2`.
`DeckMotionSource` finds that node under `/sys/class/hidraw` and reads it.
`DeckMotionDecoder` has the 64-byte report's layout, and the reasoning behind
it, in its class doc.

**It reads through `cat`.** `FileAccess` refuses anything that is not a
regular file, so a character device such as `/dev/hidraw*` cannot be opened
from GDScript at all. That leaves a GDExtension — native code to build, ship
and keep in step with the engine version, for one vector — or borrowing a
process that already does the one thing needed. `OS.execute_with_pipe` gives
a pipe whose `get_length()` is a `FIONREAD` count, so the stream is drained
without ever blocking a frame, and the reader is bounded: a device that
cannot be read ends in a source that reports nothing rather than a process
started every frame forever.

**Only the accelerometer is read.** Tilt is an orientation against gravity,
which the accelerometer gives directly and without drift. The gyroscope would
only make a fast tilt arrive sooner — a complementary filter is the obvious
follow-up if it ever feels laggy — and `MotionSource` has nowhere to carry it.

**Permissions.** The device is readable by whoever holds the seat, which is
the player in Game Mode and in Desktop Mode, but not an ssh session logged in
alongside them. A denied read comes back as no readings, plus one warning
naming what the reader said, and the keyboard takes over.

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

No device or GPU has run any of this. `DeckMotionSource` finding its hidraw
node, and `DeckMotionDecoder`'s framing and header check, are grounded in
bytes actually captured on a Deck at rest — see the class docs and
`tests/test_deck_motion_decoder.gd`'s `test_a_report_captured_on_real_hardware…`
test, which decodes that exact capture. What is still reasoned rather than
observed is the **axis convention**: which raw field is screen-right,
screen-up or out-of-screen, and in which sign, on the real device. The
calibration is orientation-agnostic by construction, which should absorb
axis surprises, but a device build is where that gets settled.

`scripts/run.sh motion` is where this is settled on hardware: it shows the
live source, the raw gravity axes, the tilt, and the scene leaning with it.
Tilt the Deck right; if the horizon rolls the wrong way, a span on
`MotionTiltDriver` goes negative. If a *raw axis* is wrong, or does not move
at all, the mapping or the offsets in `DeckMotionDecoder` are, and its class
doc says exactly what was assumed and why.
