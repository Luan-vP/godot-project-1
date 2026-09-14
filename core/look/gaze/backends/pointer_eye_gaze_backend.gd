class_name PointerEyeGazeBackend
extends EyeGazeBackend
## Adapter: the mouse pointer pretending to be where the player is looking.
##
## Not a substitute for eyes — a pointer has none of their jitter, and holds
## still in a way eyes never do — but it lets the mapping's dead zone, curve
## and rates be felt on a desktop, and lets blinks and a lost face be
## simulated on demand, without a device build per tweak.

## Angle from the middle of the viewport to its edges, radians. A phone held
## at about 30 cm spans roughly 7 degrees either side across and 14 up and
## down in portrait.
var half_extent: Vector2 = Vector2(deg_to_rad(7.0), deg_to_rad(14.0))

## Held true to report a closed eye.
var blinking: bool = false

## Held true to report no face in view.
var face_hidden: bool = false

var _viewport: Viewport
var _running: bool = false


func _init(viewport: Viewport) -> void:
	_viewport = viewport


func start() -> void:
	_running = true


func stop() -> void:
	_running = false


func poll() -> EyeGazeSample:
	var sample := EyeGazeSample.new()
	sample.timestamp = Time.get_ticks_usec() / 1_000_000.0
	if not _running:
		sample.state = EyeGazeSample.State.STOPPED
		return sample
	if face_hidden or _viewport == null:
		sample.state = EyeGazeSample.State.NO_FACE
		return sample
	var size := _viewport.get_visible_rect().size
	# Clamped to the window: a pointer parked on another monitor is not a
	# look forty degrees off the screen.
	var centred := ((_viewport.get_mouse_position() - size * 0.5) / (size * 0.5)).clamp(
		-Vector2.ONE, Vector2.ONE
	)
	sample.state = EyeGazeSample.State.TRACKING
	# Screen y grows downwards; gaze pitch grows upwards.
	sample.gaze = Vector2(centred.x * half_extent.x, -centred.y * half_extent.y)
	sample.confidence = 1.0
	sample.blink = 1.0 if blinking else 0.0
	return sample


func describe() -> String:
	return "pointer"
