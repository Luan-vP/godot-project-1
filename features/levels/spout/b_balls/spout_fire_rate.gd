class_name SpoutFireRate
extends RefCounted
## How many balls version B fires, from how far the right trigger is pressed.
## Pure: depth in, balls out, so the feel can be tested without a pad.
##
## Below a small deadzone nothing fires. Past it the rate rises in proportion
## to the depth, from [constant MIN_RATE] just past the deadzone to
## [constant MAX_RATE] fully pressed. An accumulator carries the fraction of a
## ball owed from frame to frame, so changing the depth changes the rate
## smoothly instead of resetting a timer. The first ball of a press fires at
## once — the trigger should feel like it does something the moment it moves.

const DEADZONE := 0.06
## Balls per second just past the deadzone, and fully pressed.
const MIN_RATE := 1.0
const MAX_RATE := 12.0

## Fraction of a ball owed; 1 or more means one is due.
var _owed := 1.0


## Balls per second at trigger [param depth] (0..1).
static func rate_for(depth: float) -> float:
	if depth <= DEADZONE:
		return 0.0
	var past := clampf((depth - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
	return lerpf(MIN_RATE, MAX_RATE, past)


## Balls to fire this frame, [param delta] seconds long, at [param depth].
func step(depth: float, delta: float) -> int:
	var rate := rate_for(depth)
	if rate <= 0.0:
		# Released: the next press fires its first ball at once.
		_owed = 1.0
		return 0
	_owed += rate * delta
	var due := floori(_owed)
	_owed -= due
	return due


## Trigger depth for a touch (or held click) at [param point], aiming a spout
## pivoting at [param pivot]: further away fires faster, like drawing a
## slingshot. [param reach] is the distance that counts as fully pressed —
## the level uses the drop from the spout to the pins. Never below a gentle
## dribble, so any touch fires.
static func pointer_depth(pivot: Vector2, point: Vector2, reach: float) -> float:
	if reach <= 0.0:
		return 1.0
	return clampf(pivot.distance_to(point) / reach, 0.2, 1.0)


## The trigger depth to read this frame: the right trigger on whichever pad is
## pressed furthest, or a keyboard stand-in — [kbd]Space[/kbd] (the Deck's Y
## outside Steam) for fully pressed, and [kbd]1[/kbd]–[kbd]5[/kbd] for fifths
## of the way. A touch or held click fires too, through [SpoutPointer]; see
## [method pointer_depth].
static func read_depth() -> float:
	var depth := 0.0
	for device in Input.get_connected_joypads():
		depth = maxf(depth, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT))
	if Input.is_physical_key_pressed(KEY_SPACE):
		depth = 1.0
	var steps: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
	for i in steps.size():
		if Input.is_physical_key_pressed(steps[i]):
			depth = maxf(depth, (i + 1) / 5.0)
	return depth
