class_name Floater
extends FluidBody
## A muscae-volitantes-style speck: drifts on a [FluidSimulation] the way real
## floaters do — dominated by the current, not neutrally buoyant, and settling
## back into view when the medium goes still.
##
## Built entirely on [FluidBody]; this only adds the sinking bias, the wrap
## instead of a bounce at the walls, and drawing whatever [FloaterShape] it is
## given. It does not stir the tank ([member FluidBody.wake_strength] is left
## at zero) or stain it ([member FluidBody.paint_amount] likewise) — real
## floaters are far too small to move the vitreous they sit in, and the medium
## is meant to stay clear.

## What to draw. Shape is data so a shape family needs no scene of its own; see
## [FloaterShape].
@export var shape: FloaterShape:
	set = set_shape

@export var color: Color = Color(0.13, 0.14, 0.17, 0.55)

## Visible size in pixels, at the shape's own unit of [code]1.0[/code].
@export var radius: float = 6.0:
	set = set_radius


func _init() -> void:
	# Loose enough to lag and overshoot when the medium swishes, rather than
	# snapping straight onto the current the way a tightly-coupled body would.
	drag = 2.2
	# Positive sinks (see FluidBody.buoyancy) — floaters are debris, not fish.
	buoyancy = 12.0
	max_speed = 140.0
	# Too small to stir or stain the medium; see the class docstring.
	wake_strength = 0.0
	paint_amount = 0.0
	# Walls wrap instead of bounce, so leaving the tank recycles the floater
	# rather than losing it or making it bounce like a solid body.
	contained = false


func _physics_process(delta: float) -> void:
	super(delta)
	var simulation := get_simulation()
	if simulation == null:
		return
	global_position = recycled_position(global_position, simulation.get_world_rect())


func _draw() -> void:
	if shape == null:
		return
	for dot in shape.dots:
		draw_circle(Vector2(dot.x, dot.y) * radius, dot.z * radius, color)
	for strand in shape.strands:
		var scaled := PackedVector2Array()
		scaled.resize(strand.size())
		for i in strand.size():
			scaled[i] = strand[i] * radius
		if scaled.size() > 1:
			draw_polyline(scaled, color, shape.strand_width * radius, true)


func set_shape(value: FloaterShape) -> void:
	shape = value
	queue_redraw()


func set_radius(value: float) -> void:
	radius = value
	queue_redraw()


## A position that has drifted outside [param rect] reappears from the
## opposite edge with its motion untouched, so a floater that sinks out the
## bottom keeps sinking back in at the top instead of popping to a random spot
## or stopping dead at a wall.
static func recycled_position(position: Vector2, rect: Rect2) -> Vector2:
	var result := position
	var limit := rect.end
	if result.x < rect.position.x:
		result.x = limit.x
	elif result.x > limit.x:
		result.x = rect.position.x
	if result.y < rect.position.y:
		result.y = limit.y
	elif result.y > limit.y:
		result.y = rect.position.y
	return result
