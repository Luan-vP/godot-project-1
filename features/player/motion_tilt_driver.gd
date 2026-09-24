class_name MotionTiltDriver
extends Node
## Joins [MotionInput] to a [PanoramaLookCamera]: tilt the device, tilt the
## scene.
##
## The same seam [FluidMotionDriver] is — the only file that knows about both
## sides — for the other consumer of device tilt. There, a lean leans the
## current; here it leans the view.
##
## [b]Tilt is an offset, not a turn.[/b] Looking around accumulates: a stick
## held over means keep turning. A held tilt does not; it means hold the scene
## at that angle, and letting go brings it back. Integrating tilt into [member
## PanoramaLookCamera.yaw] would give the opposite of what the device is
## saying — a lean that never comes back, and a heading that drifts away from
## level whenever the player's hands do.
##
## [b]Which way.[/b] The scene tilts the way the view through a window does:
## tip the device right and the horizon rolls left, staying where it was in the
## world rather than following the screen. Either span can be set negative to
## flip that, and either to zero to use only the other axis.

## How far the horizon rolls at full tilt, in degrees. Deliberately small
## compared with a level's look range: this is a lean, not a barrel roll, and
## the rest of the view is still where looking around left it.
const DEFAULT_ROLL_DEGREES := 12.0

## How far the view pitches at full tilt, in degrees.
const DEFAULT_PITCH_DEGREES := 6.0

## How far the horizon rolls at full tilt. Negative flips which way.
@export_range(-45.0, 45.0, 0.5) var roll_degrees: float = DEFAULT_ROLL_DEGREES

## How far the view pitches at full tilt. Negative flips which way.
@export_range(-45.0, 45.0, 0.5) var pitch_degrees: float = DEFAULT_PITCH_DEGREES

## Whether a player's comfort setting scales both spans. A tilting horizon is
## exactly the kind of movement [ComfortSettings] exists to let someone pull
## back from, and it is the same setting that scales looking around.
@export var apply_comfort_settings: bool = true

@export_group("Wiring")
## Camera to tilt. Left empty, the first one in the scene is used.
@export var camera_path: NodePath

## Motion input to read. Left empty, the first one in the scene is used.
@export var motion_path: NodePath

var _camera: PanoramaLookCamera
var _motion: MotionInput


func _ready() -> void:
	_camera = _resolve_camera()
	_motion = _resolve_motion()
	if _camera == null:
		push_warning("MotionTiltDriver found no PanoramaLookCamera; tilt is inert.")
		return
	if _motion == null:
		push_warning("MotionTiltDriver found no MotionInput; tilt is inert.")
		return
	_motion.tilt_changed.connect(_on_tilt_changed)
	_on_tilt_changed(_motion.tilt)


## The angle this driver puts the scene at for a given tilt. Pure, so the
## mapping — the small spans, the signs, and the comfort scaling — can be
## checked without a camera or a device.
func offset_for(tilt: Vector2) -> Vector2:
	return offset_for_spans(tilt, roll_degrees, pitch_degrees, apply_comfort_settings)


## The mapping itself. Static because a caller that only wants to show what it
## does — the motion demo does exactly that — should not have to own a driver,
## and an unparented [Node] kept around to ask questions of is a leak waiting
## to be written.
static func offset_for_spans(
	tilt: Vector2, roll_degrees_span: float, pitch_degrees_span: float, comfort: bool = true
) -> Vector2:
	var roll := roll_degrees_span
	var pitch := pitch_degrees_span
	if comfort:
		roll = ComfortSettings.apply_to_look_sensitivity(roll)
		pitch = ComfortSettings.apply_to_look_sensitivity(pitch)
	return Vector2(deg_to_rad(-tilt.x * roll), deg_to_rad(-tilt.y * pitch))


func _on_tilt_changed(tilt: Vector2) -> void:
	if _camera == null:
		return
	_camera.tilt_offset = offset_for(tilt)


func _resolve_camera() -> PanoramaLookCamera:
	if not camera_path.is_empty():
		return get_node_or_null(camera_path) as PanoramaLookCamera
	return _first_camera_in(get_tree().get_root())


func _resolve_motion() -> MotionInput:
	if not motion_path.is_empty():
		return get_node_or_null(motion_path) as MotionInput
	return get_tree().get_first_node_in_group(MotionInput.GROUP_NAME) as MotionInput


## Cameras are not in a group the way [MotionInput] and [FluidSimulation] are,
## so finding one without wiring means looking for it.
static func _first_camera_in(node: Node) -> PanoramaLookCamera:
	if node is PanoramaLookCamera:
		return node
	for child in node.get_children():
		var found := _first_camera_in(child)
		if found != null:
			return found
	return null
