class_name Chord
extends RefCounted
## A chord from its symbol — "Am", "Fmaj7", "Dm9", "A7sus4" — as a root and a
## set of intervals, and the ways a part needs to voice it.
##
## Songs are written as chord symbols so they read like a lead sheet. Every
## part then asks the same chord for what it needs: pads a close voicing in a
## register, the bass a root down low, the arp an ordered run of tones, the
## melody which notes belong. Nothing here knows about time or instruments.

const NOTE_CLASSES := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

## Longest suffix first, so "maj7" is not read as "m" followed by junk.
const QUALITIES := [
	["maj9", [0, 4, 7, 11, 14]],
	["maj7", [0, 4, 7, 11]],
	["m7b5", [0, 3, 6, 10]],
	["7sus4", [0, 5, 7, 10]],
	["add9", [0, 4, 7, 14]],
	["sus2", [0, 2, 7]],
	["sus4", [0, 5, 7]],
	["dim", [0, 3, 6]],
	["m9", [0, 3, 7, 10, 14]],
	["m7", [0, 3, 7, 10]],
	["6", [0, 4, 7, 9]],
	["9", [0, 4, 7, 10, 14]],
	["7", [0, 4, 7, 10]],
	["m", [0, 3, 7]],
	["", [0, 4, 7]],
]

var symbol: String = ""

## Pitch class of the root, 0 = C.
var root: int = 0

## Semitones above the root, ascending, starting at 0.
var intervals: Array[int] = []


## The chord a symbol names, or null for one it does not recognise.
static func parse(text: String) -> Chord:
	var clean := text.strip_edges()
	if clean.is_empty() or not NOTE_CLASSES.has(clean[0].to_upper()):
		return null
	var chord := Chord.new()
	chord.symbol = clean
	chord.root = NOTE_CLASSES[clean[0].to_upper()]
	var rest := clean.substr(1)
	if rest.begins_with("#"):
		chord.root += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		chord.root -= 1
		rest = rest.substr(1)
	chord.root = posmod(chord.root, 12)
	for quality in QUALITIES:
		if rest == quality[0]:
			chord.intervals.assign(quality[1])
			return chord
	return null


## The same chord moved [param semitones] round the circle — only the root
## pitch class changes; the intervals, and so the chord's quality, do not.
## Unbounded and wrapped internally, so up a fourth (+5) and down a fifth
## (-7) land on the same root, as they must (#71): [param semitones] is
## never folded to a smaller equivalent before it gets here, so repeated
## calls (walking the offset up or down) always agree with a single call for
## the total. Every voicing method already keeps its result inside whatever
## register it is given, so nothing downstream needs to know a transposition
## happened at all.
func transposed(semitones: int) -> Chord:
	var moved := Chord.new()
	moved.symbol = symbol
	moved.root = posmod(root + semitones, 12)
	moved.intervals = intervals.duplicate()
	return moved


## Pitch classes in the chord, root first.
func pitch_classes() -> Array[int]:
	var classes: Array[int] = []
	for interval in intervals:
		var pc := posmod(root + interval, 12)
		if pc not in classes:
			classes.append(pc)
	return classes


func contains(note: int) -> bool:
	return posmod(note, 12) in pitch_classes()


## The root as the lowest MIDI note at or above [param low].
func root_at_or_above(low: int) -> int:
	return low + posmod(root - low, 12)


## A close voicing with its root at or above [param low], stacked upwards, and
## any tone that would pass [param high] folded down an octave instead — so
## the voicing stays inside the register and never climbs somewhere shrill.
func voice(low: int, high: int) -> Array[int]:
	var base := root_at_or_above(low)
	var notes: Array[int] = []
	for interval in intervals:
		var note := base + interval
		while note > high and note - 12 >= low:
			note -= 12
		if note not in notes:
			notes.append(note)
	notes.sort()
	return notes


## Every chord tone between [param low] and [param high] inclusive, ascending:
## what an arp climbs and what a melody leans on at the downbeat.
func tones_between(low: int, high: int) -> Array[int]:
	var notes: Array[int] = []
	for note in range(low, high + 1):
		if contains(note):
			notes.append(note)
	return notes
