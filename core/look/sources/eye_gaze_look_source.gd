class_name EyeGazeLookSource
extends LookSource
## Adapter: where the player's eyes are pointed, as a turn.
##
## Holding a look towards the edge of the screen turns the camera that way,
## faster the further out; looking at the middle holds it still. That makes it
## self-centring — whatever the player looks at is carried towards the middle,
## their eyes follow it back, and the turn eases off on its own. The maths and
## its tunables live in [EyeGazeFilter]; the gaze README records why this
## mapping and not the alternatives.
##
## Like a stick, gaze is a held rate, not a discrete amount, so [method poll]
## scales by [param delta] itself.

## Where readings come from. The device plugin by default.
var backend: EyeGazeBackend

## The mapping, with every feel tunable on it.
var filter := EyeGazeFilter.new()

## The reading from the most recent [method poll], for debug readouts.
var last_sample := EyeGazeSample.new()

var _seen_tracking: bool = false


func _init(gaze_backend: EyeGazeBackend = null) -> void:
	backend = gaze_backend if gaze_backend != null else NativeEyeGazeBackend.new()


func start() -> void:
	backend.start()


func stop() -> void:
	backend.stop()


func poll(delta: float) -> Vector2:
	last_sample = backend.poll()
	if last_sample.is_tracking():
		_seen_tracking = true
	return filter.feed(last_sample, delta) * maxf(delta, 0.0)


## True once a face has actually been tracked, not because the build has a
## plugin: a phone without a depth camera carries the same plugin and never
## tracks.
func is_available() -> bool:
	return _seen_tracking


## Re-take neutral from where the player is looking now.
func calibrate() -> void:
	filter.calibrate()


func describe() -> String:
	return "eye gaze (%s)" % backend.describe()
