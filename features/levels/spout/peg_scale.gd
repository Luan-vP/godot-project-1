class_name PegScale
extends RefCounted
## Which note each pin in the spout level plays: a scale laid out low to high,
## left to right, one scale degree per pin, climbing octaves as it goes.
##
## Pure — no nodes, no sound. The pins ([PinField]) read [method note_for] and
## listen to [signal pin_changed]; the level hands this the band's key and
## calls [method advance] once per music step.
##
## A change of scale or key never snaps. It sets a target, and the pins take
## their new notes one at a time, leftmost first, one per [method advance] —
## so with [method advance] on the music's step clock, a new scale scrolls in
## across the field in time with the band. A second change mid-scroll starts
## the scroll again from the left, towards the newest target.
##
## Until [method set_scale] picks one, the scale is the pentatonic matching
## the key's mode, and follows the mode if it changes.

## Emitted each time a pin takes a different note: during a scroll, or all at
## once from [method snap].
signal pin_changed(pin: int, old_note: int, new_note: int)

const MAJOR_PENTATONIC: Array[int] = [0, 2, 4, 7, 9]
const MINOR_PENTATONIC: Array[int] = [0, 3, 5, 7, 10]

## Every scale the level can swap to, by name, as semitones above the tonic.
const SCALES := {
	"major pentatonic": MAJOR_PENTATONIC,
	"minor pentatonic": MINOR_PENTATONIC,
	"major": [0, 2, 4, 5, 7, 9, 11],
	"natural minor": [0, 2, 3, 5, 7, 8, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10],
	"blues": [0, 3, 5, 6, 7, 10],
}

## The order [method next_scale_name] cycles through.
const CYCLE: Array[String] = [
	"major pentatonic",
	"minor pentatonic",
	"major",
	"natural minor",
	"dorian",
	"blues",
]

var _pin_count := 0
var _low_note := 48
var _root := 9
var _minor := true
## The scale in use, and its name in [constant SCALES] (empty for one passed
## in by hand).
var _intervals: Array[int] = MINOR_PENTATONIC.duplicate()
var _scale_name := "minor pentatonic"
## Whether [method set_key] picks the scale from the mode, as it does until
## [method set_scale] is first called.
var _follow_mode := true
## What each pin plays now, and what it will play once the scroll reaches it.
var _notes: Array[int] = []
var _targets: Array[int] = []
## The next pin [method advance] flips, or -1 when no scroll is under way.
var _cursor := -1


## [param pin_count] pins, the leftmost on the lowest scale tone at or above
## [param low_note]. Takes effect at once, without a scroll.
func configure(pin_count: int, low_note: int) -> void:
	_pin_count = pin_count
	_low_note = low_note
	_notes = _compute_targets()
	_targets = _notes.duplicate()
	_cursor = -1


## Follow the band's key: [param root_pitch_class] its tonic, 0 = C. While no
## scale has been picked with [method set_scale], the scale becomes the
## pentatonic matching [param minor]. Scrolls in.
func set_key(root_pitch_class: int, minor: bool) -> void:
	_root = posmod(root_pitch_class, 12)
	_minor = minor
	if _follow_mode:
		_intervals = pentatonic_for(minor)
		_scale_name = "minor pentatonic" if minor else "major pentatonic"
	_retarget()


## Swap to [param intervals], semitones above the tonic. [param scale_name] is
## only for display. Scrolls in.
func set_scale(intervals: Array[int], scale_name: String = "") -> void:
	_follow_mode = false
	_intervals = intervals.duplicate()
	_scale_name = scale_name
	_retarget()


## Swap to the scale called [param scale_name] in [constant SCALES].
func set_scale_named(scale_name: String) -> void:
	var intervals: Array[int] = []
	intervals.assign(SCALES[scale_name])
	set_scale(intervals, scale_name)


## Go back to the pentatonic that follows the key's mode. Scrolls in.
func use_key_pentatonic() -> void:
	_follow_mode = true
	set_key(_root, _minor)


## The name of the scale after the current one in [constant CYCLE].
func next_scale_name() -> String:
	var index := CYCLE.find(_scale_name)
	return CYCLE[(index + 1) % CYCLE.size()]


## Flip the next pin over to its new note. Does nothing once the scroll has
## reached the right-hand end.
func advance() -> void:
	if _cursor < 0:
		return
	var pin := _cursor
	_cursor += 1
	if _cursor >= _pin_count:
		_cursor = -1
	_set_note(pin, _targets[pin])


## Finish any scroll at once.
func snap() -> void:
	for pin in _pin_count:
		_set_note(pin, _targets[pin])
	_cursor = -1


func note_for(pin: int) -> int:
	return _notes[pin]


## The note [param pin] is waiting to flip to, or -1 if it already plays the
## note it will end on.
func pending_for(pin: int) -> int:
	return _targets[pin] if _targets[pin] != _notes[pin] else -1


func is_scrolling() -> bool:
	return _cursor >= 0


## Which pin flips next, or -1 when settled.
func scroll_position() -> int:
	return _cursor


func pin_count() -> int:
	return _pin_count


func scale_name() -> String:
	return _scale_name


func root() -> int:
	return _root


func is_minor() -> bool:
	return _minor


static func pentatonic_for(minor: bool) -> Array[int]:
	return (MINOR_PENTATONIC if minor else MAJOR_PENTATONIC).duplicate()


## [param count] notes of [param intervals] over [param root_pitch_class],
## ascending, the first the lowest scale tone at or above [param low_note].
static func notes_for(
	root_pitch_class: int, intervals: Array[int], low_note: int, count: int
) -> Array[int]:
	var notes: Array[int] = []
	if intervals.is_empty():
		return notes
	var octave_base := low_note - posmod(low_note - root_pitch_class, 12) - 12
	while notes.size() < count:
		for interval in intervals:
			var note := octave_base + interval
			if note >= low_note and notes.size() < count:
				notes.append(note)
		octave_base += 12
	return notes


func _retarget() -> void:
	_targets = _compute_targets()
	if _notes.size() != _pin_count:
		_notes = _targets.duplicate()
	_cursor = 0 if _pin_count > 0 else -1


func _compute_targets() -> Array[int]:
	return notes_for(_root, _intervals, _low_note, _pin_count)


func _set_note(pin: int, note: int) -> void:
	var old := _notes[pin]
	if old == note:
		return
	_notes[pin] = note
	pin_changed.emit(pin, old, note)
