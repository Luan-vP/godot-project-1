class_name FluidRenderer
extends TextureRect
## Paints a [FluidSimulation]'s pigment field.
##
## Sits over the tank rect and runs `painterly.gdshader` on the dye and
## velocity textures. Nothing about the look lives here — it is all in the
## assigned [PainterlyStyle], so the same tank can be re-dressed without
## touching the solve.
##
## The shader runs offscreen, in a [SubViewport] sized by [RenderScale], and
## this shows the result stretched over the tank: on a phone that is a
## sixteenth of the screen's pixels, upscaled.

const PAINTERLY_SHADER := preload("res://features/fluid/shaders/painterly.gdshader")

## Tank to paint. Left empty, the first tank in the scene is used.
@export var simulation_path: NodePath

## Palette, brushwork and paper. A default is created if none is assigned.
@export var style: PainterlyStyle:
	set = set_style

var _simulation: FluidSimulation
var _material := ShaderMaterial.new()
var _buffer := SubViewport.new()
var _paint := ColorRect.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if style == null:
		style = PainterlyStyle.new()
	_material.shader = PAINTERLY_SHADER
	_paint.material = _material
	style.apply_to(_material)

	# Drawn only while the tank is on screen; a sleeping tank costs nothing.
	_buffer.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_buffer.add_child(_paint)
	add_child(_buffer)
	texture = _buffer.get_texture()
	get_viewport().size_changed.connect(_fit_buffer)
	_bind()


## The offscreen buffer the shader draws into.
func get_buffer() -> SubViewport:
	return _buffer


func _process(_delta: float) -> void:
	# The tank builds its render targets in its own _ready, which may run after
	# this node's. Keep trying until they exist, then stop asking.
	if _simulation == null:
		_bind()
	elif _simulation.get_dye_texture() != null:
		set_process(false)


## Re-apply the style. Assigning [member style] does this for you.
func set_style(value: PainterlyStyle) -> void:
	style = value
	if style != null and _material.shader != null:
		style.apply_to(_material)


func _bind() -> void:
	_simulation = _resolve_simulation()
	if _simulation == null:
		return
	var dye := _simulation.get_dye_texture()
	var velocity := _simulation.get_velocity_texture()
	if dye == null or velocity == null:
		_simulation = null
		return

	var rect := _simulation.get_world_rect()
	global_position = rect.position
	size = rect.size
	_fit_buffer()

	_material.set_shader_parameter("dye_tex", dye)
	_material.set_shader_parameter("velocity_tex", velocity)
	_material.set_shader_parameter(
		"texel_size", Vector2.ONE / Vector2(_simulation.config.simulation_size())
	)


func _fit_buffer() -> void:
	_buffer.size = RenderScale.buffer_size_for(get_viewport(), size)
	_paint.size = Vector2(_buffer.size)


func _resolve_simulation() -> FluidSimulation:
	if not simulation_path.is_empty():
		return get_node_or_null(simulation_path) as FluidSimulation
	return get_tree().get_first_node_in_group(FluidSimulation.GROUP_NAME) as FluidSimulation
