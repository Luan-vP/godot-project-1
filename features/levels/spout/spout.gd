class_name Spout
extends Node2D
## The spout level's main input: a nozzle hanging at the top of the screen,
## pointing straight down, that the player swings left and right with either
## stick or A/D (see [SpoutAimInput]), or points by touching the screen or
## holding the mouse button (see [SpoutPointer]).
##
## The spout only aims. What comes out of it is up to a [SpoutEmitter], which
## reads [method muzzle_position] and [method direction] each frame — fluid in
## version A, balls in version B.
##
## The pivot is this node's position, at the eye of the hand-drawn spiral;
## the spout swings from there, so its foot, where things leave it, moves
## furthest. The drawing hangs tilted a little so the foot sits straight below
## the eye, on the line it aims along.

## Emitted whenever the aim moves.
signal aim_changed(aim: float)

const ART := preload("res://features/levels/spout/spout.png")
## The spiral's eye in [constant ART], in its pixels: the pivot.
const ART_PIVOT := Vector2(135.0, 160.0)
## The middle of the foot's bottom edge in [constant ART]: the muzzle.
const ART_FOOT := Vector2(190.0, 620.0)

## Radians either side of straight down the nozzle can reach.
@export var max_aim: float = SpoutAimInput.MAX_AIM
## How tall the drawing stands on screen, in pixels.
@export var art_height: float = 150.0
## Whether this reads the pad and keyboard itself. Off for tests, or for a
## level that drives [method set_aim] some other way.
@export var reads_input: bool = true

## 0 is straight down; positive swings the tip to the right.
var aim: float = 0.0:
	set = set_aim
## While this is pressed, the nozzle points at it instead of reading the
## sticks and keys.
var pointer: SpoutPointer
## From the pivot to the foot, in pixels.
var barrel_length: float:
	get:
		return (ART_FOOT - ART_PIVOT).length() * _art_scale()
var _rate := 0.0


func _process(delta: float) -> void:
	if not reads_input:
		return
	if pointer != null and pointer.is_active():
		point_toward(pointer.point(), delta)
	else:
		steer(SpoutAimInput.read_stick_x(), SpoutAimInput.read_key_axis(), delta)


## Swing for [param delta] seconds towards pointing at [param target], in
## world space.
func point_toward(target: Vector2, delta: float) -> void:
	_rate = 0.0
	var wanted := SpoutAimInput.aim_toward(global_position, target, max_aim)
	set_aim(SpoutAimInput.eased_aim(aim, wanted, delta))


## Turn for [param delta] seconds with the stick at [param stick_x] and the
## keyboard axis at [param key_axis], easing the turn rate so the nozzle has
## a little weight.
func steer(stick_x: float, key_axis: float, delta: float) -> void:
	var target := SpoutAimInput.target_rate(stick_x, key_axis)
	_rate = SpoutAimInput.eased_rate(_rate, target, delta)
	var next := SpoutAimInput.step(aim, _rate, delta, max_aim)
	if absf(next) >= max_aim:
		_rate = 0.0
	set_aim(next)


func set_aim(value: float) -> void:
	var clamped := clampf(value, -max_aim, max_aim)
	if is_equal_approx(clamped, aim):
		return
	aim = clamped
	queue_redraw()
	aim_changed.emit(aim)


## Unit vector the nozzle points along, in world space.
func direction() -> Vector2:
	return Vector2(sin(aim), cos(aim))


## Where things leave the nozzle, in world space.
func muzzle_position() -> Vector2:
	return global_position + direction() * barrel_length


func _draw() -> void:
	# Turned so the foot hangs straight below the eye at rest, then swung.
	var rest := atan2(ART_FOOT.x - ART_PIVOT.x, ART_FOOT.y - ART_PIVOT.y)
	var art_scale := _art_scale()
	draw_set_transform(Vector2.ZERO, rest - aim, Vector2(art_scale, art_scale))
	draw_texture(ART, -ART_PIVOT)


func _art_scale() -> float:
	return art_height / ART.get_height()
