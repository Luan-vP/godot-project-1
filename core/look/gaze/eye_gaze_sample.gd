class_name EyeGazeSample
extends RefCounted
## One reading from an eye tracker, in the shape every backend agrees on.
##
## A native plugin — ARKit on iOS, a landmark model on Android — hands Godot a
## plain [Dictionary] (see the gaze README for the keys), because a
## [Dictionary] crosses both the GDExtension and the Android plugin boundary
## without either side needing the other's types. [method from_dictionary] is
## the single place that dictionary is interpreted, so nothing past it ever
## asks which platform produced a reading.
##
## Angles are radians relative to the screen, not the head: a tracker reports
## where the player is looking, and on a phone that is the thing the game can
## respond to. Zero is along the screen's normal through the front camera,
## which is not the middle of the screen — the reason calibration exists.

## Where the tracker is in its life. Numbered explicitly because native code
## sends these as plain integers.
enum State {
	## No tracker in this build, or the hardware cannot track a face.
	UNAVAILABLE = 0,
	## Supported, but not running.
	STOPPED = 1,
	## Asked to start; waiting on the camera or the permission prompt.
	STARTING = 2,
	## The player declined camera access.
	PERMISSION_DENIED = 3,
	## Running, but no face in view.
	NO_FACE = 4,
	## A face is in view and gaze is live.
	TRACKING = 5,
	## Started, then failed or was interrupted; [member message] says why.
	FAILED = 6,
}

## Bumped when the dictionary contract changes incompatibly.
const API_VERSION := 1

var state: State = State.UNAVAILABLE

## Radians, x = yaw (positive towards the screen's right as the player sees
## it), y = pitch (positive towards the top of the screen).
var gaze: Vector2 = Vector2.ZERO

## Head orientation relative to the screen, same convention as [member gaze].
## Informational: [member gaze] already includes it.
var head: Vector2 = Vector2.ZERO

## 0..1, how far the backend trusts this gaze.
var confidence: float = 0.0

## 0..1, how closed the eyes are. Gaze from a closing eye is junk.
var blink: float = 0.0

## Seconds, monotonic, when the camera frame was captured. Only differences
## mean anything; an unchanged value means no new frame since the last poll.
var timestamp: float = 0.0

## Human-readable detail from the backend, for a debug readout.
var message: String = ""


## Build a sample from a backend's dictionary. Missing keys fall back to
## "nothing known" rather than erroring, so an older or partial backend
## degrades to [constant State.UNAVAILABLE] instead of crashing the game.
static func from_dictionary(values: Dictionary) -> EyeGazeSample:
	var sample := EyeGazeSample.new()
	sample.state = state_from_int(int(values.get("state", State.UNAVAILABLE)))
	sample.gaze = Vector2(float(values.get("gaze_yaw", 0.0)), float(values.get("gaze_pitch", 0.0)))
	sample.head = Vector2(float(values.get("head_yaw", 0.0)), float(values.get("head_pitch", 0.0)))
	sample.confidence = clampf(float(values.get("confidence", 0.0)), 0.0, 1.0)
	sample.blink = clampf(float(values.get("blink", 0.0)), 0.0, 1.0)
	sample.timestamp = float(values.get("timestamp", 0.0))
	sample.message = str(values.get("message", ""))
	return sample


## An integer from native code, as a [enum State]. Anything unrecognised is
## [constant State.UNAVAILABLE]: a newer backend's state this build does not
## know must not be mistaken for tracking.
static func state_from_int(value: int) -> State:
	if State.values().has(value):
		return value as State
	return State.UNAVAILABLE


static func state_name(value: State) -> String:
	var key: Variant = State.find_key(value)
	return "UNKNOWN" if key == null else String(key)


func is_tracking() -> bool:
	return state == State.TRACKING


func to_dictionary() -> Dictionary:
	return {
		"state": int(state),
		"gaze_yaw": gaze.x,
		"gaze_pitch": gaze.y,
		"head_yaw": head.x,
		"head_pitch": head.y,
		"confidence": confidence,
		"blink": blink,
		"timestamp": timestamp,
		"message": message,
	}
