class_name ScriptedEyeGazeBackend
extends EyeGazeBackend
## Adapter: readings set by hand, for tests and replays.
##
## No camera exists in CI, so the whole gaze pipeline — calibration, dead zone,
## blink and dropout handling — is exercised through this instead. Each
## [method look] is a fresh camera frame; [method hold] repeats the last one,
## which is how a stalled native backend looks from the outside.

## One frame at 60 Hz, the rate ARKit face tracking delivers at.
const FRAME_SECONDS := 1.0 / 60.0

var start_count: int = 0
var stop_count: int = 0
var running: bool = false

var _sample := EyeGazeSample.new()


func _init() -> void:
	_sample.state = EyeGazeSample.State.STOPPED


func start() -> void:
	start_count += 1
	running = true


func stop() -> void:
	stop_count += 1
	running = false


## A new frame: gaze at [param gaze] radians, tracking.
func look(gaze: Vector2, confidence: float = 1.0, blink: float = 0.0) -> void:
	_next_frame(EyeGazeSample.State.TRACKING)
	_sample.gaze = gaze
	_sample.confidence = confidence
	_sample.blink = blink


## A new frame with no face in it.
func lose_face() -> void:
	_next_frame(EyeGazeSample.State.NO_FACE)
	_sample.confidence = 0.0


## A new frame in [param state], gaze unchanged.
func set_state(state: EyeGazeSample.State) -> void:
	_next_frame(state)


## No new frame: the next poll repeats the last reading, timestamp and all.
func hold() -> void:
	pass


func poll() -> EyeGazeSample:
	return EyeGazeSample.from_dictionary(_sample.to_dictionary())


func describe() -> String:
	return "scripted"


func _next_frame(state: EyeGazeSample.State) -> void:
	_sample.state = state
	_sample.timestamp += FRAME_SECONDS
