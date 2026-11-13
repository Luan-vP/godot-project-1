class_name FloatyEye
extends FluidBody
## A floaty eye thingy: a [FluidBody] with a face.
##
## Placeholder content for the fluid demo — it exists so the tank has something
## in it that visibly reacts to the current, and so the coupling can be seen
## working. Real eye art and behaviour should replace this; the parts worth
## keeping are the squash-along-motion and the gaze, both of which read
## directly off the fluid.
##
## With a [member painting] the body is a hand-painted cut-out instead, bare or
## wearing the eye ([member painted_eye]), which still looks about and blinks.

const EYE_SHADER := preload("res://features/levels/secret_eyes/eye.gdshader")

## How much of the sprite's half-extent the body fills. Matches the radius the
## shader draws at, so [member radius] means what it says.
const BODY_EXTENT := 0.84

## Seconds a blink takes, lids closing and opening.
const BLINK_DURATION := 0.16

## Visible radius in pixels. A [member painting] is fitted so its longest
## side is twice this.
@export var radius: float = 44.0

@export_group("Painting")
## A hand-painted cut-out to float as the body instead of the procedural eye.
## Left empty, the eye is the whole creature, as before.
@export var painting: Texture2D
## Whether a painted body also wears an eye. It looks and blinks like the
## plain eye's.
@export var painted_eye: bool = false
## Where the eye sits on the painting, from its centre, as a share of the
## painting's width and height.
@export var eye_offset: Vector2 = Vector2.ZERO
## The eye's diameter as a share of the painting's longest side.
@export_range(0.05, 1.0, 0.01) var eye_size: float = 0.4

@export_group("Look")
@export var sclera_color: Color = ArtPalette.SCLERA
@export var iris_color: Color = ArtPalette.dye(0)
@export var pupil_color: Color = ArtPalette.PUPIL
@export var rim_color: Color = ArtPalette.EYE_RIM

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
## The painted body, when there is a [member painting].
var _sprite: Sprite2D
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


## Whether an eye is drawn at all: always on a plain eye, and on a painting
## only when it is to wear one.
func has_eye() -> bool:
	return painting == null or painted_eye


func _build_visual() -> void:
	_pivot = Node2D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	var eye_parent: Node = _pivot
	var eye_diameter := radius * 2.0
	var eye_centre := Vector2.ZERO
	if painting != null:
		var size := painting.get_size()
		_sprite = Sprite2D.new()
		_sprite.name = "Painting"
		_sprite.texture = painting
		_sprite.scale = Vector2.ONE * (radius * 2.0 / maxf(size.x, size.y))
		_pivot.add_child(_sprite)
		# In the sprite's own pixels, so the eye squashes and turns with it.
		eye_parent = _sprite
		eye_diameter = maxf(size.x, size.y) * eye_size
		eye_centre = eye_offset * size
	if not has_eye():
		return

	_material.shader = EYE_SHADER
	_material.set_shader_parameter("sclera_color", sclera_color)
	_material.set_shader_parameter("iris_color", iris_color)
	_material.set_shader_parameter("pupil_color", pupil_color)
	_material.set_shader_parameter("rim_color", rim_color)
	_material.set_shader_parameter("seed", randf() * 100.0)

	var extent := eye_diameter / BODY_EXTENT
	_visual = ColorRect.new()
	_visual.name = "Visual"
	_visual.material = _material
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.size = Vector2(extent, extent)
	_visual.position = eye_centre - Vector2(extent, extent) * 0.5
	eye_parent.add_child(_visual)


## Turn to face the direction of travel and stretch along it, so the body reads
## as jelly being pulled by the water rather than a rigid disc sliding about.
func _face_motion(delta: float) -> void:
	var speed := velocity.length()
	if speed > 4.0:
		_pivot.rotation = lerp_angle(_pivot.rotation, velocity.angle(), minf(delta * 6.0, 1.0))
	var stretch := 1.0 + squash_amount * clampf(speed / maxf(max_speed, 1.0), 0.0, 1.0)
	if _sprite != null:
		# The painting squashes across its motion the way the shader squashes
		# the plain eye, and carries any eye on it along.
		var fit := _sprite.scale.x
		_sprite.scale = Vector2(fit, fit / stretch)
	else:
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
