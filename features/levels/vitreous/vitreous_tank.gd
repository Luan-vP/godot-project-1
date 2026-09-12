extends Node2D
## A pale tank of eye floaters in a gel, and nothing else.
##
## What the floaters mechanic is actually about: muscae volitantes drifting in
## the vitreous humour, out of focus, against a bright field. Assembled in code
## so the scene file stays a single node, the same as the secret eye level.
##
## Drag to push the gel. Arrows tilt, space jogs, C recalibrates, R stills the
## gel, +/- adds or removes floaters, F toggles the out-of-focus look.

## A push spreads over a broad, soft footprint and moves a whole region of the
## gel at once. That broadness used to come from a very high viscosity, which
## also stopped every push dead; putting it in the input instead leaves the
## fluid free to coast.
const STIR_GAIN := 6.0
const STIR_RADIUS := 300.0

const COUNT_STEP := 5
const MAX_COUNT := 400

var _simulation: FluidSimulation
var _motion: MotionInput
var _floaters: FloaterField
var _last_mouse := Vector2.ZERO
## Only a few: one or two drifting through at a time reads as a real floater,
## a crowd reads as dust.
var _count := 15
var _defocus := true


func _ready() -> void:
	_simulation = FluidSimulation.new()
	_simulation.name = "Vitreous"
	_simulation.config = make_gel_config(get_viewport_rect().size)
	add_child(_simulation)

	var renderer := FluidRenderer.new()
	renderer.name = "FluidRenderer"
	renderer.style = make_clear_style()
	renderer.z_index = -100
	add_child(renderer)

	_motion = MotionInput.new()
	_motion.name = "MotionInput"
	add_child(_motion)

	var driver := FluidMotionDriver.new()
	driver.name = "FluidMotionDriver"
	# The gel is clear; a jog should move it, not stain it.
	driver.nudge_paint = 0.0
	add_child(driver)

	_spawn_floaters()
	_build_hint()
	_last_mouse = get_global_mouse_position()


## The vitreous as a fluid: a push moves a broad region smoothly, with no
## eddies, then keeps its momentum and fades slowly through the whole volume
## instead of bouncing off the walls and sloshing back.
##
## Each setting answers a measured failure; see the level README:
## - converged pressure, because an under-relaxed solve is springy and sloshes
## - free-slip walls, because no-slip walls drain a viscous stir in half a second
## - only a little viscosity, since viscosity damps the tank-wide motion too
static func make_gel_config(world_size: Vector2) -> FluidConfig:
	var config := FluidConfig.new()
	config.world_size = world_size
	config.simulation_resolution = 128
	config.pressure_iterations = 100
	config.viscosity = 1000.0
	config.viscosity_iterations = 20
	config.wall_friction = 0.0
	# Confinement puts swirl back in; a gel should have none.
	config.vorticity = 0.0
	config.velocity_dissipation = 0.98
	# The gel barely moves on its own.
	config.ambient_current = 2.0
	return config


## Nearly clear, bright ground: the floaters should be the only thing to see.
static func make_clear_style() -> PainterlyStyle:
	var style := PainterlyStyle.new()
	style.paper_color = Color(0.95, 0.93, 0.88)
	style.deep_color = Color(0.80, 0.83, 0.86)
	style.ambient_density = 0.04
	style.edge_darkening = 0.15
	style.canvas_grain = 0.08
	return style


func _spawn_floaters() -> void:
	if _floaters != null:
		_floaters.queue_free()
	_floaters = FloaterField.new()
	_floaters.name = "Floaters"
	_floaters.count = _count
	# Straightish threads only. Specks spread over the blurriest band's disc
	# fall to about 1% coverage — present but invisible — so none are spawned.
	_floaters.shape_weights = Vector3(0.0, 1.0, 0.0)
	_floaters.strand_radius_range = Vector2(8.0, 34.0)
	_floaters.size_skew = 1.7
	_floaters.strand_wander = 0.12
	_floaters.line_width_px = 1.5
	_floaters.random_rotation = true
	_floaters.color = Color(0.22, 0.24, 0.28, 0.5)
	# Embedded in the gel: carried by it exactly, and settling only slowly.
	_floaters.drag = 12.0
	_floaters.buoyancy = 3.0
	# Only the very blurriest band: nothing in this tank is ever near focus.
	var blurriest: Array[FloaterDepth] = [FloaterDepth.vitreous_bands().back()]
	_floaters.depths = blurriest
	_floaters.defocus_enabled = _defocus
	add_child(_floaters)


func _build_hint() -> void:
	var layer := CanvasLayer.new()
	var hint := Label.new()
	hint.position = Vector2(16.0, 12.0)
	hint.add_theme_color_override("font_color", Color(0.2, 0.22, 0.26, 0.55))
	hint.text = "drag push · arrows tilt · space jog · C calibrate · R still · +/- count · F focus"
	layer.add_child(hint)
	add_child(layer)


func _process(delta: float) -> void:
	var mouse := get_global_mouse_position()
	var motion := mouse - _last_mouse
	_last_mouse = mouse
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if delta <= 0.0 or motion.length() < 0.5:
		return
	_simulation.add_velocity_impulse(mouse, motion / delta * STIR_GAIN, STIR_RADIUS, delta)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			_simulation.reset()
		KEY_C:
			_motion.calibrate()
		KEY_F:
			_defocus = not _defocus
			_floaters.defocus_enabled = _defocus
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			_count = mini(_count + COUNT_STEP, MAX_COUNT)
			_spawn_floaters()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_count = maxi(_count - COUNT_STEP, 0)
			_spawn_floaters()
