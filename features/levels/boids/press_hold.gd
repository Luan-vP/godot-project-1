class_name PressHold
extends RefCounted
## A press held still for [member hold_seconds]: one finger (or the mouse)
## down and kept within [member wander] of where it landed. Fires once per
## press; moving too far or letting go calls it off.
##
## How the rhythm level's dial is held to shuffle its rhythms.

var hold_seconds := 0.9
## How far, in canvas units, the press may drift and still count as held.
var wander := 40.0

## The finger (touch index) holding, or -1 when nothing is.
var index := -1

var _from := Vector2.ZERO
var _since := 0.0
var _fired := false


## A press by finger [param p_index] landed at [param at], at [param now]
## seconds. Ignored while another finger is already holding.
func begin(p_index: int, at: Vector2, now: float) -> void:
	if index != -1:
		return
	index = p_index
	_from = at
	_since = now
	_fired = false


## Finger [param p_index] moved to [param at].
func moved(p_index: int, at: Vector2) -> void:
	if p_index == index and at.distance_to(_from) > wander:
		end(p_index)


## Finger [param p_index] let go.
func end(p_index: int) -> void:
	if p_index == index:
		index = -1


func is_holding() -> bool:
	return index != -1 and not _fired


## How far through the hold it is at [param now], 0 to 1; 0 when nothing is
## held or it has already fired.
func progress(now: float) -> float:
	if not is_holding():
		return 0.0
	return clampf((now - _since) / hold_seconds, 0.0, 1.0)


## Whether the hold completes at [param now]: true once per press.
func poll(now: float) -> bool:
	if not is_holding() or now - _since < hold_seconds:
		return false
	_fired = true
	return true
