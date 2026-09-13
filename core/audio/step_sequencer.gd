class_name StepSequencer
extends RefCounted
## Reports which grid steps have come due, so a caller can fire events on a
## sixteenth-note grid.
##
## Pure and [AudioServer]-free, like [LoopLayerScheduler]: [method update] is
## handed the elapsed seconds, so a test can drive it with any sequence of
## times. Every step is reported exactly once, in order.
##
## [param lookahead] in [method update] reports a step slightly before it is
## due, for a [MusicTimeSource] that knows sound it starts will be heard late.

## After a long frame, report at most this many overdue steps — the most
## recent ones. A hitch should drop old notes, not fire a burst of them at once.
const MAX_CATCH_UP := 4

var _clock: MusicClock
var _next_step: int = -1


func _init(clock: MusicClock) -> void:
	_clock = clock


## Swap in a new clock, e.g. after a tempo change, continuing from the step
## [param seconds] falls in under it so nothing already fired fires again.
func set_clock(clock: MusicClock, seconds: float) -> void:
	_clock = clock
	if _next_step != -1:
		_next_step = _clock.step_at(seconds) + 1


func get_clock() -> MusicClock:
	return _clock


## Forget the position. The next [method update] starts from the step at or
## after the seconds it is given.
func reset() -> void:
	_next_step = -1


## Steps due by [param seconds] + [param lookahead] that have not been reported
## yet, oldest first.
func update(seconds: float, lookahead: float = 0.0) -> Array[int]:
	var due: Array[int] = []
	var horizon := seconds + maxf(lookahead, 0.0)
	if _next_step == -1:
		# Start on the step at or after now, so joining mid-step does not fire
		# a step that should already have sounded.
		_next_step = int(ceil(seconds / _clock.seconds_per_step() - 0.000001))
	var last_due := _clock.step_at(horizon)
	if last_due < _next_step:
		return due
	_next_step = maxi(_next_step, last_due - MAX_CATCH_UP + 1)
	while _next_step <= last_due:
		due.append(_next_step)
		_next_step += 1
	return due
