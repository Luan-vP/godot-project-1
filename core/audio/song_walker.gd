class_name SongWalker
extends RefCounted
## The path a [Song] takes through its sections, chosen as it plays.
##
## At the end of each section the next one is drawn from that section's
## weighted [code]"next"[/code] table. The path is laid down lazily, bar by
## bar, as far as anyone asks, and never changes once laid: asking about bar 12
## twice gives the same answer, and asking about bar 40 first extends it.
## Seeded, so a test (or a replay) walks the same way every time.

var song: Song

var _rng: RandomNumberGenerator
## One entry per bar played so far: [section name, bar within section].
var _timeline: Array = []


func _init(p_song: Song, rng: RandomNumberGenerator) -> void:
	song = p_song
	_rng = rng


## Section name playing in [param bar].
func section_at(bar: int) -> String:
	_extend_to(bar)
	return _timeline[bar][0]


## Which bar of its section [param bar] is, from 0.
func bar_in_section(bar: int) -> int:
	_extend_to(bar)
	return _timeline[bar][1]


## Whether [param bar] is the last bar of its section, where fills go.
func is_last_bar_of_section(bar: int) -> bool:
	return bar_in_section(bar) == song.bars_of(section_at(bar)).size() - 1


## Whether [param bar] starts a new pass through a section.
func is_first_bar_of_section(bar: int) -> bool:
	return bar_in_section(bar) == 0


## The one or two chords of [param bar].
func chords_at(bar: int) -> Array:
	return song.bars_of(section_at(bar))[bar_in_section(bar)]


## The chord sounding at a step.
func chord_at(bar: int, step_in_bar: int) -> Chord:
	return song.chord_in_bar(chords_at(bar), step_in_bar)


## Draw a key from [param weights] (name -> relative weight). Static and pure
## given the generator, so the weighting can be checked on its own.
static func pick_weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for key in weights:
		total += maxf(float(weights[key]), 0.0)
	if total <= 0.0:
		return weights.keys()[0]
	var roll := rng.randf() * total
	for key in weights:
		roll -= maxf(float(weights[key]), 0.0)
		if roll < 0.0:
			return key
	return weights.keys()[weights.size() - 1]


func _extend_to(bar: int) -> void:
	while _timeline.size() <= bar:
		var section := song.start_section
		if not _timeline.is_empty():
			var last: Array = _timeline[_timeline.size() - 1]
			section = last[0]
			if last[1] + 1 < song.bars_of(section).size():
				_timeline.append([section, last[1] + 1])
				continue
			section = pick_weighted(song.sections[section]["next"], _rng)
		_timeline.append([section, 0])
