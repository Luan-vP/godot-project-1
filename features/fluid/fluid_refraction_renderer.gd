class_name FluidRefractionRenderer
extends ColorRect
## Bends the background behind a [FluidSimulation]'s clear medium.
##
## Sits over the tank rect and runs `refraction.gdshader` against the velocity
## field alone — the dye field is unused, since a clear medium has no pigment
## to paint. The look lives in the assigned [RefractionStyle], so the same
## tank can be dressed painterly ([FluidRenderer]) or clear
## ([FluidRefractionRenderer]) without touching the solve.
##
## This is a plain [ColorRect], not a [SubViewport]: the shader reads what is
## behind it through `hint_screen_texture`, which is enough for a
## screen-space overlay and avoids the nested-viewport ordering problems this
## project has already been burned by once — see the "How the solve is put
## together" section of `features/fluid/README.md`.

const REFRACTION_SHADER := preload("res://features/fluid/shaders/refraction.gdshader")

## Tank to render. Left empty, the first tank in the scene is used.
@export var simulation_path: NodePath

## How strongly the field bends the background. A default is created if none
## is assigned.
@export var style: RefractionStyle:
	set = set_style

var _simulation: FluidSimulation
var _material := ShaderMaterial.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if style == null:
		style = RefractionStyle.new()
	_material.shader = REFRACTION_SHADER
	material = _material
	style.apply_to(_material)
	_bind()


func _process(_delta: float) -> void:
	# The tank builds its render targets in its own _ready, which may run after
	# this node's. Keep trying until they exist, then stop asking.
	if _simulation == null:
		_bind()
	elif _simulation.get_velocity_texture() != null:
		set_process(false)


## Re-apply the style. Assigning [member style] does this for you.
func set_style(value: RefractionStyle) -> void:
	style = value
	if style != null and _material.shader != null:
		style.apply_to(_material)


func _bind() -> void:
	_simulation = _resolve_simulation()
	if _simulation == null:
		return
	var velocity := _simulation.get_velocity_texture()
	if velocity == null:
		_simulation = null
		return

	var rect := _simulation.get_world_rect()
	global_position = rect.position
	size = rect.size

	_material.set_shader_parameter("velocity_tex", velocity)
	_material.set_shader_parameter(
		"texel_size", Vector2.ONE / Vector2(_simulation.config.simulation_size())
	)


func _resolve_simulation() -> FluidSimulation:
	if not simulation_path.is_empty():
		return get_node_or_null(simulation_path) as FluidSimulation
	return get_tree().get_first_node_in_group(FluidSimulation.GROUP_NAME) as FluidSimulation
