class_name SpoutDroplet
extends FluidBody
## One element of the spout's stream: a small, heavy bead of pigment that
## rides the eye tank's fluid. It sinks, is dragged by the current, leaves a
## faint wake and a stain, and is what actually strikes the pins — the solve
## itself has no particles and no solid pins, so the droplets are how the
## fluid "hits" something.
##
## Pooled by [FluidEmitter]: [member active] says whether it is in play.

@export var radius: float = 6.0
## Seconds before an unused droplet is returned to the pool.
@export var lifetime: float = 7.0

var active := false
var age := 0.0
var color := Color(0.3, 0.45, 0.7)


func _init() -> void:
	drag = 2.2
	buoyancy = 240.0
	max_speed = 560.0
	contained = false
	wake_strength = 2.5
	wake_radius = 40.0
	paint_amount = 0.5
	paint_radius = 20.0


func _physics_process(delta: float) -> void:
	if not active:
		return
	age += delta
	super(delta)


## Put the droplet in play at [param at], moving at [param initial].
func launch(at: Vector2, initial: Vector2, tint: Color) -> void:
	global_position = at
	velocity = initial
	color = tint
	paint_color = tint
	age = 0.0
	active = true
	visible = true


func retire() -> void:
	active = false
	visible = false
	velocity = Vector2.ZERO


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


func _draw() -> void:
	var fade := clampf(1.0 - age / lifetime, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * 1.8, Color(color, 0.18 * fade))
	draw_circle(Vector2.ZERO, radius, Color(color.darkened(0.15), 0.85 * fade))
