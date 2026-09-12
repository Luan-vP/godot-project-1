extends Node2D
## Playable sandbox for the fluid system.
##
## Builds a tank the size of the window, drops some eyes in it, and lets the
## cursor stir. Everything here is assembled in code so the scene file stays a
## single node — the demo is meant to be read, not clicked together.
##
## Drag to stir and paint. Arrows tilt, space jogs, C recalibrates, R empties
## the tank, B makes everyone blink.
##
## On a phone the arrows and space are replaced by the real accelerometer,
## with no change here — [MotionInput] picks the source.

const EYE_COUNT := 7
const SEED_BLOBS := 5
const FLOATER_COUNT := 70

## Mouse motion is a speed; the tank wants an acceleration. This bridges them.
const STIR_GAIN := 9.0

const STIR_RADIUS := 110.0
const PAINT_RATE := 3.2

## Pigment density dropped in at startup, as a one-shot rather than a rate.
const SEED_DENSITY := 1.6

var _simulation: FluidSimulation
var _motion: MotionInput
var _readout: Label
var _last_mouse: Vector2 = Vector2.ZERO
var _palette: Array[Color] = [
	Color(0.36, 0.70, 0.68),
	Color(0.85, 0.45, 0.38),
	Color(0.53, 0.44, 0.76),
	Color(0.93, 0.74, 0.36),
	Color(0.30, 0.55, 0.80),
]


func _ready() -> void:
	var extent := get_viewport_rect().size

	var config := FluidConfig.new()
	config.world_size = extent

	_simulation = FluidSimulation.new()
	_simulation.name = "Fluid"
	_simulation.config = config
	add_child(_simulation)

	var renderer := FluidRenderer.new()
	renderer.name = "FluidRenderer"
	renderer.z_index = -100
	add_child(renderer)

	_motion = MotionInput.new()
	_motion.name = "MotionInput"
	add_child(_motion)

	var driver := FluidMotionDriver.new()
	driver.name = "FluidMotionDriver"
	add_child(driver)

	_build_readout()

	for i in EYE_COUNT:
		add_child(_make_eye(i, extent))

	var floaters := FloaterField.new()
	floaters.name = "Floaters"
	floaters.count = FLOATER_COUNT
	add_child(floaters)

	# A tank that starts as flat colour looks like a bug. Seed it.
	for i in SEED_BLOBS:
		var where := Vector2(randf(), randf()) * extent
		_simulation.add_paint(where, _palette[i % _palette.size()], SEED_DENSITY, 150.0, 1.0)

	_last_mouse = get_global_mouse_position()


func _process(delta: float) -> void:
	var mouse := get_global_mouse_position()
	var motion := mouse - _last_mouse
	_last_mouse = mouse
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if delta <= 0.0 or motion.length() < 0.5:
		return
	var color := _palette[int(Time.get_ticks_msec() / 900) % _palette.size()]
	_simulation.add_velocity_impulse(mouse, motion / delta * STIR_GAIN, STIR_RADIUS, delta)
	_simulation.add_paint(mouse, color, PAINT_RATE, STIR_RADIUS * 0.6, delta)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key == null:
		return
	if key.keycode == KEY_R:
		_simulation.reset()
	elif key.keycode == KEY_C:
		_motion.calibrate()
	elif key.keycode == KEY_B:
		for eye in get_children():
			if eye is FloatyEye:
				(eye as FloatyEye).blink()


## Which source won, and what the tilt is doing. Worth showing: the whole point
## of the port is that this line changes on a phone and nothing else does.
func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Readout"
	_readout = Label.new()
	_readout.position = Vector2(16.0, 12.0)
	_readout.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.65))
	layer.add_child(_readout)
	add_child(layer)
	_motion.source_changed.connect(_on_source_changed)
	_on_source_changed(_motion.get_source_description())


func _on_source_changed(description: String) -> void:
	if _readout != null:
		_readout.text = "motion: %s" % description


func _make_eye(index: int, extent: Vector2) -> FloatyEye:
	var eye := FloatyEye.new()
	eye.name = "Eye%d" % index
	eye.position = Vector2(randf_range(0.15, 0.85), randf_range(0.15, 0.85)) * extent
	eye.radius = randf_range(26.0, 62.0)
	eye.iris_color = _palette[index % _palette.size()]
	# Bigger eyes shove more water and are harder for it to shove back.
	eye.wake_radius = eye.radius * 2.2
	eye.wake_strength = 5.0 + eye.radius * 0.07
	eye.drag = 4.4 - eye.radius * 0.03
	eye.paint_amount = 0.55
	eye.paint_color = eye.iris_color.lerp(Color(0.9, 0.95, 1.0), 0.35)
	eye.paint_radius = eye.radius * 1.4
	return eye
