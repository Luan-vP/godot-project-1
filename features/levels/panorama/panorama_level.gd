class_name PanoramaLevel
extends Node3D
## A sphere of look-around plus its medium: a [PanoramaLookCamera] at the
## centre of an equirectangular panorama, with a fluid tank and its floaters
## as a screen-space overlay in front of it.
##
## Everything that makes one level read differently from another — the
## background, how the medium moves, how much debris drifts in it, how hard it
## bends the view, and how sensitive looking around feels — comes from one
## [Level] resource. Assigning [member level] rebuilds the medium and applies
## the background and look feel in one step; nothing here needs a scene edit
## or a script change to retune.
##
## Built in code, the same as the secret eye and vitreous levels: the medium
## overlay has to be sized against the actual viewport, and [FluidConfig] is
## only read once when its tank is built.

## The level to show.
@export var level: Level:
	set(value):
		level = value
		_apply_level()

var _world_environment: WorldEnvironment
var _camera: PanoramaLookCamera
var _motion: MotionInput
var _overlay: CanvasLayer


func _ready() -> void:
	_world_environment = _build_environment()
	add_child(_world_environment)

	_camera = PanoramaLookCamera.new()
	_camera.name = "PanoramaLookCamera"
	_camera.current = true
	add_child(_camera)

	# Device tilt leans the scene where there is a device to tilt — the Steam
	# Deck, a phone — and the arrow keys stand in for it everywhere else, so
	# the feel can be judged without one. MotionInput picks; nothing here
	# knows which it got. See core/motion/README.md.
	_motion = MotionInput.new()
	_motion.name = "MotionInput"
	add_child(_motion)

	var tilt_driver := MotionTiltDriver.new()
	tilt_driver.name = "MotionTiltDriver"
	add_child(tilt_driver)

	_apply_level()


func _unhandled_input(event: InputEvent) -> void:
	# Whatever pose the player is holding becomes level. MotionCalibration
	# assumes no hold orientation on purpose, and a handheld is never held the
	# way the last player held it, so this is the control that makes the rest
	# of the tilt pipeline usable rather than merely correct.
	if _motion != null and event.is_action_pressed(MotionInput.RECENTRE_ACTION):
		_motion.calibrate()


func _apply_level() -> void:
	# The export setter can run before _ready, e.g. while the editor is
	# populating the scene or before a level-select screen assigns a level to
	# a freshly instanced, not-yet-ready scene. _ready applies it again once
	# the camera and environment exist.
	if _world_environment == null or level == null:
		return
	_apply_panorama()
	_camera.sensitivity = ComfortSettings.apply_to_look_sensitivity(level.look_sensitivity)
	_rebuild_medium()


func _apply_panorama() -> void:
	var sky_material := _world_environment.environment.sky.sky_material as PanoramaSkyMaterial
	sky_material.panorama = level.panorama_texture


## Tears down and rebuilds the fluid tank and its floaters. [FluidConfig] is
## only read when a tank is built, so retuning it needs a fresh
## [FluidSimulation] rather than a mutation in place — the same reason [code]
## VitreousTank._spawn_floaters[/code] rebuilds instead of editing floaters.
func _rebuild_medium() -> void:
	if _overlay != null:
		_overlay.queue_free()

	_overlay = CanvasLayer.new()
	_overlay.name = "MediumOverlay"
	add_child(_overlay)

	# Duplicated so sizing the tank to the current viewport never mutates a
	# [FluidConfig] shared with other levels.
	var tank_config: FluidConfig = (
		level.fluid_config.duplicate() if level.fluid_config != null else FluidConfig.new()
	)
	tank_config.world_size = Vector2(get_viewport().get_visible_rect().size)

	var simulation := FluidSimulation.new()
	simulation.name = "Medium"
	simulation.config = tank_config
	_overlay.add_child(simulation)

	# Clear medium: the fluid itself should stay all but invisible and only
	# its motion should read, as a ripple over the panorama — see the fluid
	# README's note on FluidRefractionRenderer vs FluidRenderer.
	var renderer := FluidRefractionRenderer.new()
	renderer.name = "Distortion"
	var style := RefractionStyle.new()
	style.strength = ComfortSettings.apply_to_distortion(level.distortion_strength)
	renderer.style = style
	_overlay.add_child(renderer)

	var floaters := FloaterField.new()
	floaters.name = "Floaters"
	floaters.count = level.floater_count
	floaters.radius_range = level.floater_radius_range
	floaters.size_skew = level.floater_size_skew
	# Comfort setting, not level tuning — see ComfortSettings' note on
	# reducing a floater's inertial lag and overshoot (#17).
	floaters.drag = ComfortSettings.apply_to_floater_drag(floaters.drag)
	# Real floaters sit too close to the retina to ever be crisp; see the
	# floaters README's "Depth of field" section.
	floaters.depths = FloaterDepth.vitreous_bands()
	_overlay.add_child(floaters)


static func _build_environment() -> WorldEnvironment:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = PanoramaSkyMaterial.new()
	environment.sky = sky
	world_environment.environment = environment
	return world_environment
