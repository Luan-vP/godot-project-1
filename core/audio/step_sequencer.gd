class_name StepSequencer
extends RefCounted
## Reports which grid steps have come due, so a caller can fire events on a
## sixteenth-note grid.
##
## Pure and [AudioServer]-free, like [LoopLayerScheduler]: [method update] is
## handed the elapsed position, so a test can drive it with any sequence of
## values. Every step is reported exactly once, in order.
##
## [param lookahead_beats] in [method update] reports a step slightly before it
## is due, for a [MusicTimeSource] that knows sound it starts will be heard
## late.

## After a long frame, report at most this many overdue steps — the most
## recent ones. A hitch should drop old notes, not fire a burst of them at once.
const MAX_CATCH_UP := 4

var _clock: MusicClock
var _next_step: int = -1


func _init(clock: MusicClock) -> void:
	_clock = clock


## Swap in a new clock, e.g. after a tempo change.
##
## Nothing is rebased, because nothing needs to be: a step sits at a fixed
## position in beats, so the new clock agrees with the old one about which step
## the music is in. It was not always so — while position was measured in
## seconds, two tempos disagreed about that and the step had to be recomputed
## here to stop already-fired steps firing again.
func set_clock(clock: MusicClock) -> void:
	_clock = clock


func get_clock() -> MusicClock:
	return _clock


## Forget the position. The next [method update] starts from the step at or
## after the position it is given.
func reset() -> void:
	_next_step = -1


## Steps due by [param beats] + [param lookahead_beats] that have not been
## reported yet, oldest first.
func update(beats: float, lookahead_beats: float = 0.0) -> Array[int]:
	var due: Array[int] = []
	var horizon := beats + maxf(lookahead_beats, 0.0)
	if _next_step == -1:
		# Start on the step at or after now, so joining mid-step does not fire
		# a step that should already have sounded.
		_next_step = int(ceil(beats / _clock.beats_per_step() - 0.000001))
	var last_due := _clock.step_at(horizon)
	if last_due < _next_step:
		return due
	_next_step = maxi(_next_step, last_due - MAX_CATCH_UP + 1)
	while _next_step <= last_due:
		due.append(_next_step)
		_next_step += 1
	return due
