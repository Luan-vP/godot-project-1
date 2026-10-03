class_name Haptics
extends Node
## Short controller pulses for gameplay — "a tick, now" — without caring what
## hardware is listening. Add one to a scene and call [method pulse].
##
## Picks the first available of its outputs each pulse: Steam Input when Steam
## owns a controller (the Deck launched from Steam), else plain gamepad
## rumble, else nothing. Pulses pass through a [HapticsRateLimiter] and are
## scaled by the player's [member ComfortSettings.haptics_strength], which can
## turn them off entirely.

## Default length of one tick, in seconds.
const TICK_SECONDS := 0.03

var _outputs: Array[HapticsOutput] = []
var _limiter := HapticsRateLimiter.new()
var _held_duration := TICK_SECONDS


func _ready() -> void:
	if _outputs.is_empty():
		if SteamInputMotionSource.is_steam_available():
			_outputs.append(SteamHapticsOutput.new())
		_outputs.append(JoypadHapticsOutput.new())


func _process(_delta: float) -> void:
	if _limiter.has_held():
		var strength := _limiter.flush(_now())
		if strength >= 0.0:
			_play(strength, _held_duration)


## Replace the outputs to choose from, in priority order. For tests, or a
## level that wants something other than the defaults.
func set_outputs(outputs: Array[HapticsOutput]) -> void:
	_outputs = outputs


func get_limiter() -> HapticsRateLimiter:
	return _limiter


## One pulse at [param strength] (0..1) for [param duration_s] seconds,
## subject to rate limiting and the comfort setting.
func pulse(strength: float = 0.6, duration_s: float = TICK_SECONDS) -> void:
	var scaled := ComfortSettings.apply_to_haptics(strength)
	if scaled <= 0.0:
		return
	var now_strength := _limiter.request(_now(), scaled)
	if now_strength >= 0.0:
		_play(now_strength, duration_s)
	else:
		_held_duration = duration_s


## The output a pulse would go to now, or null.
func active_output() -> HapticsOutput:
	for output in _outputs:
		if output.is_available():
			return output
	return null


func describe() -> String:
	var output := active_output()
	return output.describe() if output != null else "none"


func _play(strength: float, duration_s: float) -> void:
	var output := active_output()
	if output != null:
		output.pulse(strength, duration_s, get_tree())


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
