class_name SongShake
extends Node
## Shake the device to move the band on to its next song.
##
## A shake is two jogs ([signal MotionInput.jogged]) close together — back and
## forth — each harder than the tank's own nudges ([constant JOG_THRESHOLD]),
## so tilting and flicking the eye tank does not change the song. After one it
## rests ([constant COOLDOWN]) before another can count.
##
## Only a real sensor counts: on a desktop the motion falls back to the
## keyboard, whose Space jogs, and Space already pours the spout and plays the
## flocks' snare.

## Emitted when a shake moves the band on.
signal shaken

## Planar acceleration, m/s^2, a jog must reach to count: well over the
## tank's nudge ([member MotionInput.jog_threshold]).
const JOG_THRESHOLD := 18.0
## The second jog must land within this many seconds of the first.
const WINDOW := 0.8
## Seconds after a shake before another counts.
const COOLDOWN := 3.0

var band: Band
var motion: MotionInput

var _clock := 0.0
## When the last jog that could start a shake landed, or -INF.
var _last_jog := -INF
var _rest_until := -INF


func _ready() -> void:
	motion = MotionInput.new()
	motion.name = "Motion"
	motion.jog_threshold = JOG_THRESHOLD
	motion.jog_release = JOG_THRESHOLD * 0.4
	add_child(motion)
	motion.jogged.connect(_on_jogged)


func _process(delta: float) -> void:
	_clock += delta


## Count a jog at [param seconds]. Returns whether it completes a shake,
## which then rests for [constant COOLDOWN].
func jog(seconds: float) -> bool:
	if seconds < _rest_until:
		return false
	if seconds - _last_jog <= WINDOW:
		_last_jog = -INF
		_rest_until = seconds + COOLDOWN
		return true
	_last_jog = seconds
	return false


func _on_jogged(_direction: Vector2) -> void:
	if motion.get_source() is KeyboardMotionSource:
		return
	if jog(_clock):
		if band != null:
			band.next_song()
		shaken.emit()
