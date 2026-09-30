class_name Song
extends RefCounted
## A piece of music as data: sections of chords that branch into one another,
## and the patterns each part plays over whatever chord is current.
##
## A song never plays the same way twice in the same order, but it is still
## recognisably itself: sections are fixed material (the same chords, and a
## melody that is the same every time that section comes round), and only the
## path through them is chosen as it plays — see [SongWalker].
##
## [b]Sections[/b] are keyed by name. Each has [code]"bars"[/code], a string of
## bars separated by [code]|[/code]; a bar is one chord symbol, or two joined
## by a comma to split the bar in half. [code]"next"[/code] maps the sections
## that may follow to relative weights.
## [codeblock]
## "A": {"bars": "Am | F | C | G", "next": {"A": 1, "B": 2}},
## [/codeblock]
##
## [b]Bass[/b] is a 16-step string per bar: [code]R[/code] root, [code]O[/code]
## octave, [code]5[/code] fifth, [code]3[/code] third, [code].[/code] rest.
## [b]Arp[/b] is 16 steps of indices into the chord's tones in the arp register,
## lowest first, [code].[/code] for a rest. [b]Melody rhythms[/b] are 16-step
## strings where [code]x[/code] starts a note, [code]-[/code] holds it and
## [code].[/code] rests; [MelodyWriter] picks the pitches.

var title: String = ""
var tempo_bpm: float = 70.0
var beats_per_bar: int = 4

## Pitch class of the key's tonic, 0 = C, and the scale as semitones above it.
var key_root: int = 9
var scale: Array[int] = [0, 2, 3, 5, 7, 8, 10]

var start_section: String = ""
var sections: Dictionary = {}

## Drum part name -> [StepPattern] text, as [method StepPattern.parse] takes.
## "fill" plays only in the last bar of a section, on top of the beat.
var drums: Dictionary = {}

var bass_line: String = "R.......R......."
var bass_hold_steps: int = 2
var arp_pattern: String = "0.1.2.3.2.1.0.1."
var melody_rhythms: Array[String] = ["x-------x---x---"]

## Part name -> overrides for that part's synth patch: any of
## [code]"waveform"[/code], [code]"attack"[/code], [code]"release"[/code],
## [code]"level"[/code]. Parts not listed keep the band's defaults.
var timbres: Dictionary = {}

## Registers as MIDI note ranges, kept low enough that nothing is shrill.
var pad_range := Vector2i(48, 67)
var arp_range := Vector2i(55, 69)
var melody_range := Vector2i(57, 69)
var bass_range := Vector2i(28, 39)


## The chords of [param section], one entry per half-bar-able bar: each bar is
## an array of one or two [Chord]s.
func bars_of(section: String) -> Array:
	var bars := []
	for bar_text in String(sections[section]["bars"]).split("|"):
		var chords: Array[Chord] = []
		for symbol in bar_text.split(","):
			chords.append(Chord.parse(symbol))
		bars.append(chords)
	return bars


## The chord sounding at [param step_in_bar] of a bar holding [param chords].
func chord_in_bar(chords: Array, step_in_bar: int) -> Chord:
	var steps := beats_per_bar * 4
	var index := mini(step_in_bar * chords.size() / steps, chords.size() - 1)
	return chords[index]


## Every problem with this song as written, empty when it is sound: symbols
## that do not parse, sections that lead nowhere, strings of the wrong length.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	var steps := beats_per_bar * 4
	if not sections.has(start_section):
		found.append("start section '%s' does not exist" % start_section)
	for name in sections:
		var section: Dictionary = sections[name]
		for bar in bars_of(name):
			for chord in bar:
				if chord == null:
					found.append("section '%s' has a chord that does not parse" % name)
		var next: Dictionary = section.get("next", {})
		if next.is_empty():
			found.append("section '%s' leads nowhere" % name)
		for target in next:
			if not sections.has(target):
				found.append("section '%s' leads to missing '%s'" % [name, target])
	for text in [bass_line, arp_pattern] + Array(melody_rhythms):
		if String(text).length() != steps:
			found.append("pattern '%s' is not %d steps" % [text, steps])
	for part in drums:
		for hit in drums[part]:
			if String(drums[part][hit]).length() != steps:
				found.append("drum %s/%s is not %d steps" % [part, hit, steps])
	return found
