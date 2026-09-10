class_name FloatyEye
extends FluidBody
## A floaty eye thingy: a [FluidBody] with a face.
##
## Placeholder content for the fluid demo — it exists so the tank has something
## in it that visibly reacts to the current, and so the coupling can be seen
## working. Real eye art and behaviour should replace this; the parts worth
## keeping are the squash-along-motion and the gaze, both of which read
## directly off the fluid.

const EYE_SHADER := preload("res://features/fluid/demo/eye.gdshader")

## How much of the sprite's half-extent the body fills. Matches the radius the
## shader draws at, so [member radius] means what it says.
const BODY_EXTENT := 0.84

## Seconds a blink takes, lids closing and opening.
const BLINK_DURATION := 0.16

## Visible radius in pixels.
@export var radius: float = 44.0

@export_group("Look")
@export var sclera_color: Color = Color(0.937, 0.918, 0.859)
@export var iris_color: Color = Color(0.396, 0.643, 0.639)
@export var pupil_color: Color = Color(0.078, 0.086, 0.129)
@export var rim_color: Color = Color(0.235, 0.243, 0.353)

@export_group("Behaviour")
## Distance at which the eye notices the cursor and follows it.
@export var attention_radius: float = 460.0

## Idle paddling, in pixels/second^2. This is what keeps an eye from becoming
## a dead float when the water goes quiet.
@export var wander_strength: float = 90.0

## How far the body stretches along its own motion at [member max_speed].
@export_range(0.0, 1.5, 0.01) var squash_amount: float = 0.35

## Random range between blinks, in seconds.
@export var blink_interval: Vector2 = Vector2(2.4, 7.0)

var _pivot: Node2D
var _visual: ColorRect
var _material := ShaderMaterial.new()
var _gaze: Vector2 = Vector2.ZERO
var _wander_phase: float = 0.0
var _blink_countdown: float = 0.0
var _blink_phase: float = -1.0


func _ready() -> void:
	super()
	_wander_phase = randf() * TAU
	_blink_countdown = randf_range(blink_interval.x, blink_interval.y)
	_build_visual()


func _physics_process(delta: float) -> void:
	_wander_phase += delta * 0.7
	velocity += (
		Vector2.from_angle(_wander_phase * 1.31 + sin(_wander_phase) * 2.0)
		* (wander_strength * delta)
	)

	super(delta)

	_face_motion(delta)
	_update_gaze(delta)
	_update_blink(delta)


## Interrupt whatever the eye was doing and make it blink now.
func blink() -> void:
	_blink_phase = 0.0


func _build_visual() -> void:
	_material.shader = EYE_SHADER
	_material.set_shader_parameter("sclera_color", sclera_color)
	_material.set_shader_parameter("iris_color", iris_color)
	_material.set_shader_parameter("pupil_color", pupil_color)
	_material.set_shader_parameter("rim_color", rim_color)
	_material.set_shader_parameter("seed", randf() * 100.0)

	var extent := radius * 2.0 / BODY_EXTENT
	_visual = ColorRect.new()
	_visual.name = "Visual"
	_visual.material = _material
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.size = Vector2(extent, extent)
	_visual.position = Vector2(-extent, -extent) * 0.5

	_pivot = Node2D.new()
	_pivot.name = "Pivot"
	_pivot.add_child(_visual)
	add_child(_pivot)


## Turn to face the direction of travel and stretch along it, so the body reads
## as jelly being pulled by the water rather than a rigid disc sliding about.
func _face_motion(delta: float) -> void:
	var speed := velocity.length()
	if speed > 4.0:
		_pivot.rotation = lerp_angle(_pivot.rotation, velocity.angle(), minf(delta * 6.0, 1.0))
	var stretch := 1.0 + squash_amount * clampf(speed / maxf(max_speed, 1.0), 0.0, 1.0)
	_material.set_shader_parameter("squash", stretch)


func _update_gaze(delta: float) -> void:
	var to_cursor := get_global_mouse_position() - global_position
	var wanted := Vector2.from_angle(_wander_phase * 0.9) * 0.55
	if to_cursor.length() < attention_radius:
		wanted = to_cursor.normalized()
	elif velocity.length() > 12.0:
		wanted = velocity.normalized() * 0.7
	# The sprite turns with the body, so the gaze has to be expressed in the
	# pivot's frame or the eye would appear to roll with it.
	_gaze = _gaze.lerp(wanted.rotated(-_pivot.rotation), minf(delta * 5.0, 1.0))
	_material.set_shader_parameter("gaze", _gaze)


func _update_blink(delta: float) -> void:
	if _blink_phase >= 0.0:
		_blink_phase += delta / BLINK_DURATION
		if _blink_phase >= 1.0:
			_blink_phase = -1.0
			_blink_countdown = randf_range(blink_interval.x, blink_interval.y)
	else:
		_blink_countdown -= delta
		if _blink_countdown <= 0.0:
			_blink_phase = 0.0
	var lid := 0.0 if _blink_phase < 0.0 else sin(_blink_phase * PI)
	_material.set_shader_parameter("lid", lid)
