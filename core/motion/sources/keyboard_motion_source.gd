class_name KeyboardMotionSource
extends MotionSource
## Adapter: WASD and space, standing in for a device with no sensors.
##
## Not merely a convenience. It is what makes tilt runnable on a desktop, so
## the real pipeline — calibration, basis projection, filtering, jog detection —
## is exercised during development instead of only ever on a phone.
##
## It therefore synthesises a [i]gravity vector[/i] rather than a tilt directly.
## Short-circuiting to a tilt would leave the interesting half of the pipeline
## untested until the first device build.
##
## WASD rather than the arrow keys (#72): the eye band level puts tempo
## control on the arrows, and this is the stand-in — a real device supplies
## tilt from its accelerometer, never the keyboard — so moving it costs
## nothing, unlike moving a real player control. Raw physical keys, not
## [code]ui_*[/code] actions, precisely so it does not collide with whatever
## those actions are bound to elsewhere (see
## docs/music-player-controls-scope.md §5).

## Standard gravity, so the synthesised readings sit in the same range a real
## sensor produces.
const GRAVITY := 9.80665

## Acceleration a keyboard shake reports, comfortably over the jog threshold.
const SHAKE_STRENGTH := 18.0

## How far WASD tilts the imaginary device.
var span_degrees: float = 30.0


func poll(_delta: float) -> MotionReading:
	var wanted := Vector2(_axis(KEY_A, KEY_D), _axis(KEY_W, KEY_S))
	var span := deg_to_rad(span_degrees)
	var about_x := span * wanted.x
	var about_y := span * wanted.y

	# Reference gravity is -Y, matching a device held upright, tilted about the
	# two screen axes.
	var direction := Vector3(sin(about_x), -cos(about_x) * cos(about_y), sin(about_y)).normalized()
	_reading.gravity = direction * GRAVITY

	var shake := Vector3.ZERO
	if Input.is_action_pressed("ui_accept"):
		var heading := wanted if wanted.length() > 0.01 else Vector2.RIGHT
		shake = Vector3(heading.x, 0.0, heading.y).normalized() * SHAKE_STRENGTH
	_reading.acceleration = shake

	_reading.available = true
	return _reading


func is_available() -> bool:
	return true


func describe() -> String:
	return "keyboard (WASD tilt, space jogs)"


## 1 while [param positive] alone is held, -1 for [param negative] alone, 0 for
## neither or both — the same shape as [method Input.get_axis], for a pair of
## raw keys instead of a pair of actions.
static func _axis(negative: Key, positive: Key) -> float:
	var value := 0.0
	if Input.is_physical_key_pressed(positive):
		value += 1.0
	if Input.is_physical_key_pressed(negative):
		value -= 1.0
	return value
