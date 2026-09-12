class_name PanoramaLookCamera
extends Camera3D
## Camera at the centre of a panoramic background, turned by [LookInput].
##
## Owns its own [LookInput] child exactly as [MotionInput] is owned by whatever
## uses it — drop this scene in and it works. A test swaps in a
## [ScriptedLookSource] the same way a motion test swaps in a
## [ScriptedMotionSource]: [code]get_look_input().clear_sources()[/code], then
## [code]add_source(...)[/code].
##
## Yaw and pitch are tracked here rather than read back from [member
## Node3D.rotation], because [member rotation].y gets wrapped every frame to
## stop it drifting with float error over a long session, and un-wrapping it
## again just to keep accumulating would be pointless work this way avoids.

## How far past level the camera may pitch. Short of 90 degrees, so the
## horizon cannot roll over the top of the view.
@export_range(60.0, 89.9, 0.1) var max_pitch_degrees: float = 85.0

## Whether to hide and lock the cursor to the window, so mouse look has room to
## turn indefinitely instead of stalling at the screen edge. Escape releases
## it; a click recaptures.
@export var capture_mouse: bool = true

## Radians/second this frame produced, x = yaw rate, y = pitch rate. The
## floaters mechanic hangs off this number, so it is computed once, here,
## rather than every consumer re-deriving it from the rotation.
var angular_velocity: Vector2 = Vector2.ZERO

## Current heading, radians, wrapped to [code][-PI, PI][/code].
var yaw: float = 0.0

## Current pitch, radians, clamped to +/- [member max_pitch_degrees].
var pitch: float = 0.0

var _look: LookInput


func _ready() -> void:
	yaw = rotation.y
	pitch = rotation.x
	_look = LookInput.new()
	_look.name = "LookInput"
	add_child(_look)
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var raw := _look.poll(delta)
	var previous_pitch := pitch

	yaw = wrapf(yaw - raw.x, -PI, PI)
	var limit := deg_to_rad(max_pitch_degrees)
	pitch = clampf(pitch - raw.y, -limit, limit)
	rotation = Vector3(pitch, yaw, 0.0)

	# Yaw is never clamped, so its true delta is always -raw.x. Pitch can be
	# clamped, so its rate has to come from what actually happened rather than
	# what was asked for — otherwise a stick held hard against the limit would
	# report a rate the camera was not actually turning at.
	angular_velocity = Vector2(-raw.x, pitch - previous_pitch) / delta


func _unhandled_input(event: InputEvent) -> void:
	if not capture_mouse:
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func get_look_input() -> LookInput:
	return _look
