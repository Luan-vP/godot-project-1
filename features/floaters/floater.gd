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
##
## The look — translucent, soft-edged, faintly refractive glass rather than a
## flat sprite — lives entirely in `floater.gdshader`. Every floater shares
## one [ShaderMaterial] instance; only the baked shape mask ([member shape]
## rasterized at [member radius]) and two per-instance shader parameters
## (tint, blur) differ, which is what keeps N floaters cheap. See the shader
## for how translucency, softness, refraction and blur are actually done, and
## the PR this shipped in for why floaters are individual nodes rather than
## one accumulated screen-space pass.

const FLOATER_SHADER := preload("res://features/floaters/shaders/floater.gdshader")

## Screen-space blur radius, in pixels, per pixel of [member radius] — a
## floater's blur comes from sitting close to the lens and far from the
## retina, not from how big it looks, so bigger floaters blur more.
const BLUR_PER_RADIUS := 0.6

static var _shared_material: ShaderMaterial

## What to draw. Shape is data so a shape family needs no scene of its own; see
## [FloaterShape].
@export var shape: FloaterShape:
	set = set_shape

## Tint and translucency, handed straight to the shader as its "glass"
## colour — alpha is how much of the background it replaces at the shape's
## most opaque point, not a flat fill amount.
@export var color: Color = Color(0.13, 0.14, 0.17, 0.55):
	set = set_color

## Visible size in pixels, at the shape's own unit of [code]1.0[/code].
@export var radius: float = 6.0:
	set = set_radius

var _texture: ImageTexture


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
	# One shader instance for every floater in the game — see the class
	# docstring on why this is the whole cost story.
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = FLOATER_SHADER
	material = _shared_material


func _physics_process(delta: float) -> void:
	super(delta)
	var simulation := get_simulation()
	if simulation == null:
		return
	global_position = recycled_position(global_position, simulation.get_world_rect())


func _draw() -> void:
	if _texture == null:
		return
	var extent := Vector2(_texture.get_size()) * 0.5
	draw_texture_rect(_texture, Rect2(-extent, extent * 2.0), false)


func set_shape(value: FloaterShape) -> void:
	shape = value
	_rebuild_texture()


func set_radius(value: float) -> void:
	radius = value
	set_instance_shader_parameter("blur_px", radius * BLUR_PER_RADIUS)
	_rebuild_texture()


func set_color(value: Color) -> void:
	color = value
	set_instance_shader_parameter("tint", color)


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


## Re-bakes [member _texture] from [member shape] at [member radius]. Cheap
## enough to call on every edit in the editor, but still only on a change —
## never per frame — since it walks every pixel of a small image on the CPU.
func _rebuild_texture() -> void:
	if shape == null:
		_texture = null
	else:
		_texture = ImageTexture.create_from_image(shape.rasterize(radius))
	queue_redraw()
