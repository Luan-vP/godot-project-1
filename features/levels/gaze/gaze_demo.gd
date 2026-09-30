extends Node
## Manual test bed for [GazeFluidDriver]: look around and watch the floaters
## lag, sweep and settle.
##
## The vitreous tank's gel and floaters, laid over the panorama camera as a
## screen-space overlay and driven by the look instead of a drag. Nothing here
## is the main level — that is its own assembly work — it only exists so the
## feel of the mapping can be judged and retuned by hand.
##
## Mouse or right stick looks. 1/2 and 3/4 lower and raise the hold and flick
## sensitivity live, R stills the gel, F toggles the out-of-focus look, Esc
## frees the cursor.

const PANORAMA_SCENE := preload("res://features/levels/panorama/panorama_level.tscn")
const VitreousTank := preload("res://features/levels/vitreous/vitreous_tank.gd")

const HOLD_STEP := 50.0
const FLICK_STEP := 50.0

var _simulation: FluidSimulation
var _floaters: FloaterField
var _driver: GazeFluidDriver
var _camera: PanoramaLookCamera
var _readout: Label


func _ready() -> void:
	var panorama := PANORAMA_SCENE.instantiate()
	add_child(panorama)
	_camera = panorama.get_node("PanoramaLookCamera")

	# Floaters live in the eye, not the world, so the whole tank is a
	# screen-space overlay that turns with the camera.
	var eye := CanvasLayer.new()
	eye.name = "Eye"
	add_child(eye)

	var size := get_viewport().get_visible_rect().size
	_simulation = FluidSimulation.new()
	_simulation.name = "Vitreous"
	_simulation.config = VitreousTank.make_gel_config(size)
	# The view is a window onto a larger body of gel: a turn carries the whole
	# medium across it and out the far side, which walls would slosh back.
	_simulation.config.wrap_edges = true
	eye.add_child(_simulation)

	var renderer := FluidRenderer.new()
	renderer.name = "FluidRenderer"
	renderer.style = VitreousTank.make_clear_style()
	renderer.z_index = -100
	eye.add_child(renderer)

	_floaters = _make_floaters()
	eye.add_child(_floaters)

	_driver = GazeFluidDriver.new()
	_driver.name = "GazeFluidDriver"
	add_child(_driver)

	_build_readout()


func _process(_delta: float) -> void:
	_readout.text = (
		"look %+.2f, %+.2f rad/s · hold %.0f (1/2) · flick %.0f (3/4) · R still · F focus"
		% [
			_camera.angular_velocity.x,
			_camera.angular_velocity.y,
			_driver.hold_sensitivity,
			_driver.flick_sensitivity,
		]
	)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_driver.hold_sensitivity = maxf(_driver.hold_sensitivity - HOLD_STEP, 0.0)
		KEY_2:
			_driver.hold_sensitivity += HOLD_STEP
		KEY_3:
			_driver.flick_sensitivity = maxf(_driver.flick_sensitivity - FLICK_STEP, 0.0)
		KEY_4:
			_driver.flick_sensitivity += FLICK_STEP
		KEY_R:
			_simulation.reset()
		KEY_F:
			_floaters.defocus_enabled = not _floaters.defocus_enabled


## The vitreous tank's population: a few long, blurry strands riding the gel.
func _make_floaters() -> FloaterField:
	var floaters := FloaterField.new()
	floaters.name = "Floaters"
	floaters.count = 15
	floaters.shape_weights = Vector3(0.0, 1.0, 0.0)
	floaters.strand_radius_range = Vector2(8.0, 34.0)
	floaters.size_skew = 1.7
	floaters.strand_wander = 0.12
	floaters.line_width_px = 1.5
	floaters.random_rotation = true
	floaters.color = Color(0.22, 0.24, 0.28, 0.5)
	floaters.drag = 12.0
	floaters.buoyancy = 3.0
	# A flick sweeps the gel far faster than anything in the vitreous tank does;
	# the default cap would clip exactly the motion this demo is for.
	floaters.max_speed = 1500.0
	var blurriest: Array[FloaterDepth] = [FloaterDepth.vitreous_bands().back()]
	floaters.depths = blurriest
	return floaters


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	_readout = Label.new()
	_readout.position = Vector2(16.0, 12.0)
	_readout.add_theme_color_override("font_color", Color(0.2, 0.22, 0.26, 0.55))
	layer.add_child(_readout)
	add_child(layer)
