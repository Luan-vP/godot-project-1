class_name ArrangementDirector
extends RefCounted
## Turns a scoring intensity into which rung of an ordered layer stack should
## be playing, with the hysteresis that keeps a flickering score from
## chattering a layer in and out.
##
## [member layers] is climbed bottom to top: layer [code]i[/code] joins once
## intensity reaches [member thresholds][code][i][/code], which must be
## ascending. Rising intensity adds the next layer immediately — a player
## doing well should hear the reward right away, modulo the bar boundary
## [method AudioManager.set_layer_active] itself waits for. Falling intensity
## is the hard part (see #34's notes): a layer only leaves once intensity has
## stayed continuously below its threshold for [member release_seconds], and
## never before it has been in for at least [member min_hold_seconds] — either
## alone would still let a score hovering right at a boundary chatter a layer.
## Losing several layers at once from a big drop still leaves one at a time,
## each pausing for its own [member release_seconds], which is what makes
## falling from a good state to a poor one decay rather than cut out.
##
## A base "bed" layer that plays regardless of scoring is deliberately not
## this class's concern — #28 decided silence is never the right answer, but
## that just means a caller turns a bed layer on once, outside the stack
## handed to this class, and never asks this class about it.
##
## Pure, like [MusicClock] and [LoopLayerScheduler]: [method update] is handed
## the elapsed seconds it should answer for rather than reading a clock
## itself, so a test can feed a scripted sequence of snapshots and assert
## exactly which layers are active without a running game.

## Layer names, bottom to top. [member AudioManager] doesn't care what a name
## maps to — a rendered drum pattern, a live synth gated on and off — only
## that it is a loop layer this director is allowed to switch.
var layers: Array[String]

## Intensity required for layers[i] to be active. Must be ascending and the
## same length as [member layers]; not validated, since every other data
## class in this codebase (e.g. [StepPattern]) trusts its caller the same way.
var thresholds: PackedFloat32Array

## Seconds intensity must stay continuously below a layer's threshold before
## that layer leaves.
var release_seconds: float

## Seconds a layer must have been active before it is eligible to leave,
## regardless of intensity. Guards against a brief spike adding a layer just
## to have it immediately start counting down to leave again.
var min_hold_seconds: float

var _level := 0
var _level_changed_at := 0.0
var _below_since := -1.0


func _init(
	p_layers: Array[String],
	p_thresholds: PackedFloat32Array,
	p_release_seconds: float = 2.0,
	p_min_hold_seconds: float = 0.0
) -> void:
	layers = p_layers
	thresholds = p_thresholds
	release_seconds = p_release_seconds
	min_hold_seconds = p_min_hold_seconds


## Forgets the current level and any pending release, as when a level
## restarts. The next [method update] starts from no layers active.
func reset() -> void:
	_level = 0
	_level_changed_at = 0.0
	_below_since = -1.0


## How many layers (from the bottom of [member layers]) are currently active.
func current_level() -> int:
	return _level


## The active layers, bottom to top.
func active_layers() -> Array[String]:
	var result: Array[String] = []
	for i in _level:
		result.append(layers[i])
	return result


## Intensity [member layers][-1] requires, or 0 if there are no layers — the
## natural ceiling to normalise a raw intensity against for a continuous
## effect. 0 if there are no thresholds at all.
func top_threshold() -> float:
	return thresholds[-1] if not thresholds.is_empty() else 0.0


## Advances the director with a fresh [param intensity] reading at [param
## seconds], and returns the layer_name -> active changes that resulted, as a
## [Dictionary] (empty if the level did not change). At most one layer changes
## per call, even when intensity has fallen far enough to eventually drop
## several — see the class description for why that is deliberate.
func update(intensity: float, seconds: float) -> Dictionary:
	var target := _target_level(intensity)
	var changes: Dictionary = {}
	if target > _level:
		for i in range(_level, target):
			changes[layers[i]] = true
		_level = target
		_level_changed_at = seconds
		_below_since = -1.0
	elif target < _level:
		var current_threshold: float = thresholds[_level - 1]
		if intensity >= current_threshold:
			_below_since = -1.0
		else:
			if _below_since < 0.0:
				_below_since = seconds
			var held_long_enough := seconds - _below_since >= release_seconds
			var min_hold_elapsed := seconds - _level_changed_at >= min_hold_seconds
			if held_long_enough and min_hold_elapsed:
				changes[layers[_level - 1]] = false
				_level -= 1
				_level_changed_at = seconds
				_below_since = -1.0
	else:
		_below_since = -1.0
	return changes


## How many layers [param intensity] alone would justify, ignoring hysteresis.
func _target_level(intensity: float) -> int:
	var level := 0
	for i in thresholds.size():
		if intensity < thresholds[i]:
			break
		level = i + 1
	return level
