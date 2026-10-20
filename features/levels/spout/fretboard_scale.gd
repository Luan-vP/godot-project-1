class_name FretboardScale
extends PegScale
## The scale laid out as a scale diagram on a guitar's top strings, for the
## fretboard layout of [PinField]: a grid of sites, one per string and fret,
## and a pin only at the sites whose note is in the scale.
##
## A site's note is fixed by where it is — the string's open note plus the
## fret — so a change of key or scale never retunes a pin. It moves them:
## sites leave the scale and others join it, the shape sliding along the
## neck. Which frets are in a scale comes from that scale's diagram in
## [GuitarDiagrams]; a scale passed in by hand, with no diagram, is worked
## out from its intervals.
##
## Sites are indexed fret by fret, left to right, and within a fret top
## string first — so [method note_for] is -1 for a site with no pin. The
## scroll moves a whole fret at a time, lowest fret first, one per
## [method advance].

## Open notes of the strings in play, highest (the top row) first.
var _open_notes: Array[int] = []
var _first_fret := 9
var _frets := 12


## [param strings] strings of standard tuning, the highest first, from
## [param first_fret] for [param frets] frets. Takes effect at once, without a
## scroll.
func configure_fretboard(strings: int, first_fret: int, frets: int) -> void:
	var count := clampi(strings, 1, GuitarDiagrams.STANDARD_TUNING.size())
	_open_notes = GuitarDiagrams.STANDARD_TUNING.slice(0, count)
	_first_fret = maxi(0, first_fret)
	_frets = maxi(1, frets)
	_pin_count = _frets * _open_notes.size()
	_notes = _compute_targets()
	_targets = _notes.duplicate()
	_cursor = -1


func string_count() -> int:
	return _open_notes.size()


func fret_count() -> int:
	return _frets


func first_fret() -> int:
	return _first_fret


## The site for fret column [param column] (0 the first fret shown) on
## [param string_row] (0 the top string).
func site(column: int, string_row: int) -> int:
	return column * _open_notes.size() + string_row


## The fret a site sits on, counted from the nut.
func fret_of(site_index: int) -> int:
	return _first_fret + site_index / _open_notes.size()


func string_of(site_index: int) -> int:
	return site_index % _open_notes.size()


## The note a site plays when it holds a pin.
func site_note(site_index: int) -> int:
	return _open_notes[string_of(site_index)] + fret_of(site_index)


## Flip the next fret's sites over to the new scale. Does nothing once the
## scroll has reached the last fret.
func advance() -> void:
	if _cursor < 0:
		return
	var column := _cursor
	_cursor += 1
	if _cursor >= _frets:
		_cursor = -1
	for row in _open_notes.size():
		var index := site(column, row)
		_set_note(index, _targets[index])


func _compute_targets() -> Array[int]:
	var targets: Array[int] = []
	for index in _pin_count:
		targets.append(site_note(index) if _holds_pin(index) else -1)
	return targets


func _holds_pin(site_index: int) -> bool:
	var string_index := string_of(site_index)
	var fret := fret_of(site_index)
	if GuitarDiagrams.has(_scale_name):
		return GuitarDiagrams.in_scale(_scale_name, string_index, fret, _root)
	return _intervals.has(posmod(site_note(site_index) - _root, 12))
