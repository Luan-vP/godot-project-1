extends Node2D
## Manual test bed for [FluidRefractionRenderer].
##
## A checkerboard background makes even a slight bend of straight lines
## obvious, which a flat colour would hide. Drag to stir; [kbd]+[/kbd] and
## [kbd]-[/kbd] tune [member RefractionStyle.strength] live and [kbd]R[/kbd]
## empties the tank, so both halves of the issue's bar — invisible at rest,
## still readable as a ripple mid-swish — can be checked without touching the
## editor.

const STIR_GAIN := 9.0
const STIR_RADIUS := 110.0
const STRENGTH_STEP := 0.005
const CHECKER_TILE := 128
const CHECKER_CELL := 32

var _simulation: FluidSimulation
var _renderer: FluidRefractionRenderer
var _readout: Label
var _last_mouse: Vector2 = Vector2.ZERO


func _ready() -> void:
	var extent := get_viewport_rect().size

	add_child(_make_background(extent))

	var config := FluidConfig.new()
	config.world_size = extent
	_simulation = FluidSimulation.new()
	_simulation.name = "Fluid"
	_simulation.config = config
	add_child(_simulation)

	_renderer = FluidRefractionRenderer.new()
	_renderer.name = "FluidRefractionRenderer"
	add_child(_renderer)

	_build_readout()
	_last_mouse = get_global_mouse_position()


func _process(delta: float) -> void:
	var mouse := get_global_mouse_position()
	var motion := mouse - _last_mouse
	_last_mouse = mouse
	var dragging := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if dragging and delta > 0.0 and motion.length() >= 0.5:
		_simulation.add_velocity_impulse(mouse, motion / delta * STIR_GAIN, STIR_RADIUS, delta)
	_update_readout()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key == null:
		return
	if key.keycode == KEY_EQUAL or key.keycode == KEY_KP_ADD:
		_nudge_strength(STRENGTH_STEP)
	elif key.keycode == KEY_MINUS or key.keycode == KEY_KP_SUBTRACT:
		_nudge_strength(-STRENGTH_STEP)
	elif key.keycode == KEY_R:
		_simulation.reset()


func _nudge_strength(delta: float) -> void:
	_renderer.style.strength = clampf(_renderer.style.strength + delta, 0.0, 0.1)
	# Re-assigning runs the setter, which is what pushes the change to the
	# material; mutating the resource in place does not.
	_renderer.style = _renderer.style


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Readout"
	_readout = Label.new()
	_readout.position = Vector2(16.0, 12.0)
	_readout.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	layer.add_child(_readout)
	add_child(layer)


func _update_readout() -> void:
	if _readout == null or _renderer.style == null:
		return
	_readout.text = (
		"strength: %.3f  (drag to stir, +/- to tune, R to reset)" % _renderer.style.strength
	)


## A small tiled checkerboard rather than a full-screen image: straight lines
## make a subtle bend visible in a way a flat colour cannot, and tiling a
## small texture is far cheaper than painting every pixel of the viewport.
func _make_background(extent: Vector2) -> TextureRect:
	var image := Image.create(CHECKER_TILE, CHECKER_TILE, false, Image.FORMAT_RGB8)
	for y in CHECKER_TILE:
		for x in CHECKER_TILE:
			var light := ((x / CHECKER_CELL) + (y / CHECKER_CELL)) % 2 == 0
			image.set_pixel(x, y, Color(0.85, 0.85, 0.9) if light else Color(0.15, 0.15, 0.2))

	var background := TextureRect.new()
	background.name = "Background"
	background.texture = ImageTexture.create_from_image(image)
	background.stretch_mode = TextureRect.STRETCH_TILE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.size = extent
	return background
