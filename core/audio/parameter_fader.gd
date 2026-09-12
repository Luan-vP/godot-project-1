class_name ParameterFader
extends RefCounted
## Smooths a per-frame float into a target's property, in place of assigning
## it directly.
##
## Setting a bus volume or a filter cutoff straight from a per-frame value
## produces stepping and zipper noise, because the value changes once per
## frame while the audio is mixed in much finer blocks. This interpolates
## towards the mapped target instead of jumping to it.
##
## Frame-rate independent: [member retention_per_second] is the fraction of
## the remaining gap that survives one second, applied each step as
## pow(retention_per_second, delta) — the same shape
## [method FluidConfig.retention_over] uses for the fluid's dissipation,
## because a fixed per-frame factor closes the gap roughly twice as fast at
## 144 fps as at 30.
##
## Unaware of gameplay, and of audio: [member target] and [member property]
## can be any [Object] with a settable property. Point it at an [AudioEffect]
## fetched from a bus to drive a filter cutoff or a wet/dry level; it does not
## know that is what it is doing.

## Object whose property [method advance] writes to. May be left null to just
## read the smoothed value back from [method advance]'s return value instead.
var target: Object

## Name of the property on [member target] to drive.
var property: StringName = &""

## Input range mapped from.
var input_min: float = 0.0
var input_max: float = 1.0

## Parameter range mapped to. [member rest_value] is given in these units too.
var output_min: float = 0.0
var output_max: float = 1.0

## Fraction of the remaining gap to the mapped input that survives one
## second. Near 0 snaps almost immediately; near 1 barely moves. Exactly 0
## snaps outright.
var retention_per_second: float = 0.1

## Parameter value the fader settles towards once fresh input has stopped
## arriving for [member input_timeout] seconds — so a level ending or a pause
## resolves somewhere sensible instead of holding the last value forever.
var rest_value: float = 0.0

## Seconds without a fresh [method advance] reading before falling back to
## [member rest_value].
var input_timeout: float = 0.5

var _current: float = 0.0
var _has_current: bool = false
var _time_since_input: float = 0.0


## Advances the fader by [param delta] seconds. Pass a [float] for a fresh
## reading, or `null` when none arrived this frame — the timeout clock keeps
## running either way, so a source that goes quiet is not the same as one
## still reporting its last value. Returns the smoothed parameter value and,
## if [member target] is set, writes it to [member target].[member property].
func advance(delta: float, input: Variant) -> float:
	var mapped_target: float
	if input != null:
		_time_since_input = 0.0
		mapped_target = _map(input)
	else:
		_time_since_input += delta
		if _has_current and _time_since_input < input_timeout:
			mapped_target = _current
		else:
			mapped_target = rest_value

	if not _has_current:
		_current = mapped_target
		_has_current = true
	else:
		var retention := pow(clampf(retention_per_second, 0.0, 1.0), maxf(delta, 0.0))
		_current = lerpf(mapped_target, _current, retention)

	if target != null:
		target.set(property, _current)
	return _current


## Forget the smoothed state and the timeout clock, as after a scene change.
func reset() -> void:
	_has_current = false
	_time_since_input = 0.0


## Maps [param value] from the range [param in_min]..[param in_max] to
## [param out_min]..[param out_max], the same rescale [method advance] uses
## internally. Exposed so a caller can compute the un-smoothed target for
## comparison, e.g. a demo contrasting this against the naive direct
## assignment it exists to replace.
static func remap(
	value: float, in_min: float, in_max: float, out_min: float, out_max: float
) -> float:
	var span := in_max - in_min
	var t := 0.0 if is_zero_approx(span) else (value - in_min) / span
	return lerpf(out_min, out_max, t)


func _map(value: float) -> float:
	return remap(value, input_min, input_max, output_min, output_max)
