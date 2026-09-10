class_name MotionInput
extends Node
## Device tilt and jog, as signals, from whichever source is actually there.
##
## The only part of the motion stack the rest of the game talks to. It picks a
## source, runs the pipeline, and emits; swapping in a fake for a test or a
## replay is one call to [method set_source].
##
## The pipeline, in order:
## [codeblock lang=text]
## source -> calibration -> tilt -> dead zone -> smoothing -> tilt_changed
##                       -> planar acceleration -> jog detector -> jogged
## [/codeblock]
##
## Left as a plain [Node] rather than an autoload so a test or a second local
## player can own its own. Promote it in project.godot if it ever needs to be
## global.

## Emitted when the smoothed tilt moves. Length 1 means fully tilted.
signal tilt_changed(tilt: Vector2)

## Emitted once per shake. The vector carries direction and how hard.
signal jogged(direction: Vector2)

## Emitted when the active source changes, including on the first pick.
signal source_changed(description: String)

## Nodes register here so drivers can find the input without wiring.
const GROUP_NAME := "motion_input"

## How long to wait for sensors to report before falling back to the keyboard.
## Sensors are not always live on the first frame.
const PROBE_SECONDS := 0.75

## How far the tilt must drift from the last announced value before another
## signal is worth sending. This gates the [b]emit only[/b] — never the state
## update. Smoothing takes ever-smaller steps as it converges, so gating the
## update on it freezes the tilt short of its target and, on the way back,
## leaves the current leaning forever.
const TILT_EPSILON := 0.001

@export_group("Tilt")
## Device rotation, in degrees from level, that counts as fully tilted.
@export_range(5.0, 80.0, 1.0) var tilt_span_degrees: float = 28.0

## Tilt below this is treated as holding still. Hands are never quite level.
@export_range(0.0, 0.5, 0.01) var tilt_deadzone: float = 0.08

## Seconds for the tilt to close about 63% of a change. Higher is calmer and
## laggier; this is the main feel control.
@export_range(0.0, 1.0, 0.01) var tilt_smoothing: float = 0.12

@export_group("Jog")
@export_range(1.0, 40.0, 0.5) var jog_threshold: float = 11.0
@export_range(0.0, 20.0, 0.5) var jog_release: float = 5.0
@export_range(0.0, 2.0, 0.01) var jog_cooldown: float = 0.32
@export_range(1.0, 8.0, 0.1) var jog_max_strength: float = 3.0

@export_group("Calibration")
## Take the first usable reading as level. Turn off to calibrate explicitly.
@export var auto_calibrate: bool = true

## Latest smoothed tilt. Length 1 means fully tilted.
var tilt: Vector2 = Vector2.ZERO

var _announced: Vector2 = Vector2.ZERO
var _source: MotionSource
var _calibration := MotionCalibration.new()
var _jog := JogDetector.new()
var _probe_elapsed: float = 0.0
var _probing: bool = true


func _ready() -> void:
	add_to_group(GROUP_NAME)
	_apply_jog_settings()
	# Start hopeful: try the real sensors, and fall back only once they have
	# had a fair chance to report. This deliberately does not go through
	# set_source, which stops probing — an explicit choice by a caller should
	# not be second-guessed a moment later by the fallback.
	_install_source(DeviceMotionSource.new())
	_probing = true


func _process(delta: float) -> void:
	if _source == null:
		return
	var reading := _source.poll(delta)
	_probe_for_sensors(delta)
	if not reading.available:
		return

	if auto_calibrate and not _calibration.is_calibrated():
		_calibration.calibrate(reading.gravity)

	var raw := _calibration.tilt_from(reading.gravity, tilt_span_degrees)
	var wanted := MotionFilter.apply_deadzone(raw, tilt_deadzone)
	tilt = MotionFilter.smooth(tilt, wanted, tilt_smoothing, delta)
	if tilt.distance_to(_announced) > TILT_EPSILON:
		_announced = tilt
		tilt_changed.emit(tilt)

	var nudge := _jog.feed(_calibration.project(reading.acceleration), delta)
	if nudge != Vector2.ZERO:
		jogged.emit(nudge)


## Swap the source. This is the seam the whole feature is built around.
##
## Calling it also ends the startup probe, so a source chosen deliberately —
## a fake in a test, a replay, a player's explicit preference — is never
## replaced by the keyboard fallback.
func set_source(source: MotionSource) -> void:
	_install_source(source)
	_probing = false


func get_source() -> MotionSource:
	return _source


func get_source_description() -> String:
	return "none" if _source == null else _source.describe()


## Take the device's current attitude as level. Call this from a "recentre"
## button — whatever the player is holding becomes neutral.
##
## The neutral value is announced explicitly. Consumers hold the last tilt they
## were told, and the freshly levelled pose produces zero on every subsequent
## frame, so nothing would ever contradict the old value: without this emit the
## recentre button leaves the tank leaning until the player moves.
func calibrate() -> bool:
	if _source == null:
		return false
	var reading := _source.poll(0.0)
	if not _calibration.calibrate(reading.gravity):
		# The reading carried no direction, so the old reference still stands
		# and the tilt it produces is still valid. Zeroing here would be a
		# spurious jump.
		return false
	_jog.reset()
	tilt = Vector2.ZERO
	_announced = Vector2.ZERO
	tilt_changed.emit(tilt)
	return true


func is_calibrated() -> bool:
	return _calibration.is_calibrated()


func _probe_for_sensors(delta: float) -> void:
	if not _probing:
		return
	if _source.is_available():
		_probing = false
		return
	_probe_elapsed += delta
	if _probe_elapsed >= PROBE_SECONDS:
		_install_source(KeyboardMotionSource.new())
		_probing = false


func _install_source(source: MotionSource) -> void:
	_source = source
	_jog.reset()
	if source != null:
		source_changed.emit(source.describe())


func _apply_jog_settings() -> void:
	_jog.threshold = jog_threshold
	_jog.release = jog_release
	_jog.cooldown = jog_cooldown
	_jog.max_strength = jog_max_strength
