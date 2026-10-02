class_name Spout
extends Node2D
## The spout level's main input: a nozzle hanging at the top of the screen,
## pointing straight down, that the player swings left and right with the
## left stick or A/D (see [SpoutAimInput]).
##
## The spout only aims. What comes out of it is up to a [SpoutEmitter], which
## reads [method muzzle_position] and [method direction] each frame — fluid in
## version A, balls in version B.
##
## The pivot is this node's position, at the top; the nozzle swings from
## there, so the tip moves furthest.

## Emitted whenever the aim moves.
signal aim_changed(aim: float)

## Radians either side of straight down the nozzle can reach.
@export var max_aim: float = SpoutAimInput.MAX_AIM
## From the pivot to the tip, in pixels.
@export var barrel_length: float = 92.0
## Whether this reads the pad and keyboard itself. Off for tests, or for a
## level that drives [method set_aim] some other way.
@export var reads_input: bool = true

@export_group("Look")
@export var body_color: Color = Color(0.2, 0.17, 0.16)
@export var rim_color: Color = Color(0.93, 0.86, 0.72)
@export var barrel_width: float = 26.0

## 0 is straight down; positive swings the tip to the right.
var aim: float = 0.0:
	set = set_aim
var _rate := 0.0


func _process(delta: float) -> void:
	if reads_input:
		steer(SpoutAimInput.read_stick_x(), SpoutAimInput.read_key_axis(), delta)


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
	var dir := direction()
	var side := Vector2(dir.y, -dir.x)
	var tip := dir * barrel_length
	var half := barrel_width * 0.5
	# A barrel tapering a little towards the tip, with a lip at the end.
	var barrel := PackedVector2Array(
		[side * half, side * half * 0.78 + tip, -side * half * 0.78 + tip, -side * half]
	)
	draw_colored_polygon(barrel, body_color)
	draw_line(tip + side * half * 0.95, tip - side * half * 0.95, rim_color, 4.0, true)
	# The hub it swings from.
	draw_circle(Vector2.ZERO, barrel_width * 0.85, body_color)
	draw_arc(Vector2.ZERO, barrel_width * 0.85, 0.0, TAU, 40, rim_color, 2.0, true)
	draw_circle(Vector2.ZERO, barrel_width * 0.25, rim_color)
