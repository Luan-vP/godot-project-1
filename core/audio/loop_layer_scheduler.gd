class_name LoopLayerScheduler
extends RefCounted
## Queues layer on/off requests and releases them only when playback crosses
## a bar boundary, so a change asked for mid-bar lands on the next one
## instead of the instant it was asked for.
##
## Pure and [AudioServer]-free like [MusicClock]: [method update] is handed
## the current position in beats by the caller rather than reading a clock
## itself, which is what makes the scheduling logic deterministically testable
## — a test can call [method update] with any sequence of positions to
## simulate time passing, without waiting on real playback.

var _clock: MusicClock
var _pending: Dictionary = {}
var _last_bar: int = -1


func _init(clock: MusicClock) -> void:
	_clock = clock


## Swaps in a new clock, e.g. after a tempo change. Does not release or
## discard anything pending.
##
## Nothing is rebased, because nothing needs to be: a bar sits at a fixed
## position in beats, so the new clock agrees with the old one about which bar
## the music is in. While position was measured in seconds, two tempos rarely
## agreed about that, the mismatch read as a boundary crossing, and anything
## pending released immediately — mid-bar — rather than waiting for a real one.
func set_clock(clock: MusicClock) -> void:
	_clock = clock


## Forgets where "the last bar" was and any pending requests. Call when
## playback (re)starts, so the first [method update] establishes a fresh
## baseline instead of comparing against a bar from a previous run.
func reset() -> void:
	_pending.clear()
	_last_bar = -1


## Queues [param layer_name] to become active/inactive on the next bar
## boundary. A later call for the same layer before that boundary replaces
## the earlier one — only the most recent request per layer is honoured.
func request(layer_name: String, active: bool) -> void:
	_pending[layer_name] = active


## Advances the scheduler to [param beats] and returns the layer_name ->
## active changes that just landed on a bar boundary, as a [Dictionary]
## (empty if none did, including on the very first call after a [method
## reset], which only establishes the starting bar).
func update(beats: float) -> Dictionary:
	var bar := _clock.bar_at(beats)
	if _last_bar == -1:
		_last_bar = bar
		return {}
	if bar == _last_bar or _pending.is_empty():
		_last_bar = bar
		return {}
	_last_bar = bar
	var changes := _pending.duplicate()
	_pending.clear()
	return changes
