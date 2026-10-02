class_name SpoutAimInput
extends RefCounted
## Turns the left stick and the A/D keys into how fast the spout turns. Pure,
## so the feel can be tested without a pad: [method target_rate] maps raw
## input to a turn rate, and [method step] eases towards it and moves the aim.
##
## The stick is a rate control, not a position: push it and the nozzle keeps
## swinging until you let go, like turning a valve. A small deadzone keeps a
## resting stick still, and the response is squared past it, so small
## deflections give fine control and a full push swings fast. A/D turn at a
## fixed, moderate rate. Not the arrows: they move the tempo in every scene.

## Radians either side of straight down the nozzle can reach.
const MAX_AIM := deg_to_rad(60.0)
## Turn rate at full stick, radians/second.
const MAX_RATE := 1.6
## Turn rate while A or D is held, radians/second.
const KEY_RATE := 0.9
## Stick deflection ignored around centre.
const DEADZONE := 0.15
## How quickly the turn rate catches up with the input, per second. High
## enough to feel direct, low enough that the nozzle has a little weight.
const EASE := 12.0

const LEFT_KEYS: Array[Key] = [KEY_A]
const RIGHT_KEYS: Array[Key] = [KEY_D]


## Turn rate in radians/second for a stick at [param stick_x] (-1..1) and a
## keyboard axis [param key_axis] (-1, 0 or 1). Positive turns the nozzle to
## the right. The stick wins whenever it is outside its deadzone.
static func target_rate(stick_x: float, key_axis: float) -> float:
	var stick := shaped_stick(stick_x)
	if stick != 0.0:
		return stick * MAX_RATE
	return clampf(key_axis, -1.0, 1.0) * KEY_RATE


## [param stick_x] past the deadzone, rescaled to 0..1 and squared, keeping
## its sign.
static func shaped_stick(stick_x: float) -> float:
	var magnitude := absf(stick_x)
	if magnitude <= DEADZONE:
		return 0.0
	var past := clampf((magnitude - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
	return signf(stick_x) * past * past


## The turn rate after [param delta] seconds easing from [param rate] towards
## [param target].
static func eased_rate(rate: float, target: float, delta: float) -> float:
	return lerpf(rate, target, 1.0 - exp(-EASE * delta))


## [param aim] moved by [param rate] for [param delta] seconds, held within
## [param max_aim] either side of straight down.
static func step(aim: float, rate: float, delta: float, max_aim: float = MAX_AIM) -> float:
	return clampf(aim + rate * delta, -max_aim, max_aim)


## The keyboard's turn axis right now: -1 for A, 1 for D, 0 for neither or
## both.
static func read_key_axis() -> float:
	var axis := 0.0
	for key in LEFT_KEYS:
		if Input.is_physical_key_pressed(key):
			axis -= 1.0
			break
	for key in RIGHT_KEYS:
		if Input.is_physical_key_pressed(key):
			axis += 1.0
			break
	return axis


## The left stick's x on whichever connected pad is pushed furthest, so the
## Deck's pad works whatever device number Steam gives it.
static func read_stick_x() -> float:
	var furthest := 0.0
	for device in Input.get_connected_joypads():
		var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		if absf(x) > absf(furthest):
			furthest = x
	return furthest
