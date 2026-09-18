class_name EyeGazeBackend
extends RefCounted
## Port: somewhere gaze readings come from.
##
## Separate from [LookSource] because gaze is not yet a look rotation — how a
## gaze becomes a turn is a feel decision ([EyeGazeFilter]) that should be
## testable, and swappable, without a camera. Adapters behind this port:
## [NativeEyeGazeBackend] (the device plugin), [ScriptedEyeGazeBackend]
## (tests), and [PointerEyeGazeBackend] (a mouse standing in for eyes, so the
## mapping can be felt on a desktop).


## Begin producing readings. For a camera-backed tracker this is what turns the
## camera on, so it is explicit rather than implied by the first poll.
func start() -> void:
	pass


## Stop producing readings and release whatever [method start] opened.
func stop() -> void:
	pass


## The latest reading. Never null; a backend with nothing to say returns a
## sample in [constant EyeGazeSample.State.UNAVAILABLE] or
## [constant EyeGazeSample.State.STOPPED].
func poll() -> EyeGazeSample:
	return EyeGazeSample.new()


## Short human-readable name, for debug overlays and logs.
func describe() -> String:
	return "none"
