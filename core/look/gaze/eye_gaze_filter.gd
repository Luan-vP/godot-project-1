class_name EyeGazeFilter
extends RefCounted
## Gaze readings in, a smoothed look rate out: calibration, jitter smoothing,
## blink and dropout handling, and the dead-zone rate mapping, in order.
##
## [codeblock lang=text]
## sample -> usable? -> smooth gaze -> deflection from neutral -> dead zone
##        -> curve -> rate -> ease the rate
## [/codeblock]
##
## Kept apart from [EyeGazeLookSource] so every step can be driven from a
## [ScriptedEyeGazeBackend] with known frame timing, and apart from
## [EyeGazeMapping] because this is the part with memory.
##
## Every tunable is a plain field so a level or the debug demo can change it
## live. Defaults are a first guess for a portrait phone held at reading
## distance, not a verdict; the gaze README says what each one trades.

## Gaze angle, radians from neutral, that counts as full deflection. Roughly
## the edges of a portrait phone at 30 cm: looking at the edge turns at full
## rate.
var span: Vector2 = Vector2(deg_to_rad(7.0), deg_to_rad(14.0))

## Fraction of [member span] around neutral that turns nothing. Front-camera
## gaze is only good to a few degrees, so this must swallow tracker noise and
## a relaxed look at the middle of the screen.
var deadzone: float = 0.4

## Response curve past the dead zone. 1 is linear; higher is gentler near the
## zone and steeper towards the edge.
var exponent: float = 1.6

## Radians/second at full deflection, x = yaw, y = pitch. Pitch is slower:
## the camera clamps short of straight up and down, and a fast pitch into the
## clamp reads as the view sticking.
var max_rate: Vector2 = Vector2(1.4, 0.9)

## Seconds for the smoothed gaze to close ~63% of a jump. Takes the edge off
## fixational jitter without hiding a deliberate saccade for long.
var gaze_smoothing: float = 0.08

## Seconds for the turn rate to close ~63% of a change. The dwell against the
## Midas touch: a glance at a corner barely starts a turn before the eyes come
## back, while a held look builds to full rate.
var turn_smoothing: float = 0.25

## Readings below this confidence are ignored, as if the frame never came.
var min_confidence: float = 0.5

## Readings with the eye this closed or more are ignored.
var max_blink: float = 0.5

## Seconds a lost or unusable gaze is bridged by holding the last good one. A
## blink lasts 0.1-0.3 s; without this every blink would stutter a turn.
var dropout_grace: float = 0.25

## Seconds without a new camera frame before a still-"tracking" backend is
## treated as lost. Guards against a stalled plugin steering forever.
var stale_after: float = 0.3

## Seconds of usable gaze averaged into a new neutral.
var calibration_seconds: float = 0.6

## Calibrate from the first usable gaze without being asked. Without a
## neutral nothing turns, and the front camera sits above the screen, so
## looking at the middle of the screen reads as looking down.
var auto_calibrate: bool = true

## Radians, the gaze that counts as looking at the middle of the screen.
var neutral: Vector2 = Vector2.ZERO

## Smoothed gaze, radians, as last fed.
var smoothed_gaze: Vector2 = Vector2.ZERO

## Normalised, unshaped deflection of [member smoothed_gaze] from [member
## neutral] — where the debug marker goes.
var deflection: Vector2 = Vector2.ZERO

## Current look rate, radians/second, [LookSource] convention.
var rate: Vector2 = Vector2.ZERO

var _calibrated: bool = false
var _calibrating: bool = false
var _calibration_sum: Vector2 = Vector2.ZERO
var _calibration_time: float = 0.0
var _has_gaze: bool = false
var _since_usable: float = INF
var _last_timestamp: float = NAN
var _stale_age: float = 0.0


## Take the next [member calibration_seconds] of usable gaze as neutral. The
## camera stops turning while it listens: the player is being asked to look at
## the middle, and a turn started now would drag their eyes away.
func calibrate() -> void:
	_calibrating = true
	_calibration_sum = Vector2.ZERO
	_calibration_time = 0.0


func is_calibrated() -> bool:
	return _calibrated


func is_calibrating() -> bool:
	return _calibrating


## Whether a gaze is being steered with right now, including one bridged
## across a blink.
func has_gaze() -> bool:
	return _has_gaze


## Forget everything learned, neutral included.
func reset() -> void:
	_calibrated = false
	_calibrating = false
	_has_gaze = false
	_since_usable = INF
	_last_timestamp = NAN
	_stale_age = 0.0
	neutral = Vector2.ZERO
	smoothed_gaze = Vector2.ZERO
	deflection = Vector2.ZERO
	rate = Vector2.ZERO


## Feed one reading, [param delta] seconds after the last, and get the look
## rate in radians/second.
func feed(sample: EyeGazeSample, delta: float) -> Vector2:
	if delta <= 0.0:
		return rate

	var usable := EyeGazeMapping.is_usable(sample, min_confidence, max_blink)
	# The game may poll faster than the camera delivers, so a repeated
	# timestamp is normal for a frame or two. Only a long run of them means
	# the backend has stalled while still claiming to track.
	if is_nan(_last_timestamp) or sample.timestamp != _last_timestamp:
		_last_timestamp = sample.timestamp
		_stale_age = 0.0
	else:
		_stale_age += delta
	if _stale_age > stale_after:
		usable = false

	if usable:
		_take(sample.gaze, delta)
	else:
		_since_usable += delta
		# Within the grace the last good gaze simply holds, so a turn carries
		# on through a blink. Past it the gaze is gone, and the rate eases out
		# below rather than stopping dead.
		if _since_usable > dropout_grace:
			_has_gaze = false

	var target := Vector2.ZERO
	if _has_gaze and _calibrated and not _calibrating:
		deflection = EyeGazeMapping.deflection(smoothed_gaze, neutral, span)
		target = EyeGazeMapping.look_rate(
			EyeGazeMapping.shape(deflection, deadzone, exponent), max_rate
		)
	rate = MotionFilter.smooth(rate, target, turn_smoothing, delta)
	return rate


func _take(gaze: Vector2, delta: float) -> void:
	# On (re)acquiring, snap instead of smoothing from wherever the gaze was
	# before it was lost: sweeping across the screen from a stale value would
	# turn the camera towards somewhere the player never looked.
	smoothed_gaze = (
		MotionFilter.smooth(smoothed_gaze, gaze, gaze_smoothing, delta) if _has_gaze else gaze
	)
	_has_gaze = true
	_since_usable = 0.0

	if auto_calibrate and not _calibrated and not _calibrating:
		calibrate()
	if _calibrating:
		# Averaged raw, weighted by time: the mean already removes jitter, and
		# the smoothed value would still carry the lag of the last look.
		_calibration_sum += gaze * delta
		_calibration_time += delta
		if _calibration_time >= calibration_seconds:
			neutral = _calibration_sum / _calibration_time
			_calibrated = true
			_calibrating = false
