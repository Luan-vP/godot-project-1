class_name StepClock
extends Node
## Emits [signal step] on every grid step while music plays, locked to the same
## [MusicTimeSource] and [MusicClock] as [AudioManager]'s loop layers.
##
## For live, game-driven notes. How tight they land is the time source's
## business, not this node's — see [WallClockMusicTime] for what the current
## one gives. Anything that repeats bar to bar and must be exact, drums above
## all, should be a [StepPattern] rendered into a loop layer instead.

## [param index] counts steps from the start of the music; [param bar] and
## [param step_in_bar] locate it musically.
signal step(index: int, bar: int, step_in_bar: int)

var _sequencer: StepSequencer
var _time_source: MusicTimeSource
var _clock: MusicClock


func _process(_delta: float) -> void:
	advance()


## Use [param source] instead of [AudioManager]'s time source. For tests.
func set_time_source(source: MusicTimeSource) -> void:
	_time_source = source
	reset()


## Use [param clock] instead of [AudioManager]'s tempo. For tests.
func set_music_clock(clock: MusicClock) -> void:
	_clock = clock


## Forget the position; the next steps fired start from the current time.
func reset() -> void:
	if _sequencer != null:
		_sequencer.reset()


## Fire every step that has come due. Called each frame; exposed so a test can
## drive it with a [ScriptedMusicTime].
func advance() -> void:
	var source := _time_source if _time_source != null else AudioManager.get_music_time_source()
	var clock := _clock if _clock != null else AudioManager.get_music_clock()
	if not source.is_running():
		reset()
		return
	var seconds := source.get_seconds()
	if _sequencer == null:
		_sequencer = StepSequencer.new(clock)
	elif _sequencer.get_clock() != clock:
		_sequencer.set_clock(clock, seconds)
	var per_bar := clock.steps_per_bar()
	for index in _sequencer.update(seconds, source.get_lookahead()):
		step.emit(index, index / per_bar, index % per_bar)
