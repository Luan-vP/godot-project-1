extends GutTest
## Covers [Chord]: reading symbols and voicing them inside a register.


func test_symbols_parse_to_root_and_intervals() -> void:
	var cases := {
		"Am": [9, [0, 3, 7]],
		"F": [5, [0, 4, 7]],
		"Fmaj7": [5, [0, 4, 7, 11]],
		"Dm9": [2, [0, 3, 7, 10, 14]],
		"Bbmaj7": [10, [0, 4, 7, 11]],
		"A7sus4": [9, [0, 5, 7, 10]],
		"F#m7b5": [6, [0, 3, 6, 10]],
	}
	for symbol in cases:
		var chord := Chord.parse(symbol)
		assert_not_null(chord, symbol)
		assert_eq(chord.root, cases[symbol][0], "%s root" % symbol)
		assert_eq(chord.intervals, cases[symbol][1] as Array[int], "%s intervals" % symbol)


func test_nonsense_does_not_parse() -> void:
	for symbol in ["", "H", "Cblah", "m7"]:
		assert_null(Chord.parse(symbol), "'%s'" % symbol)


func test_voicings_stay_inside_their_register() -> void:
	for symbol in ["Am", "B7", "Dm9", "Gm7", "C7sus4", "Bbmaj7"]:
		var notes := Chord.parse(symbol).voice(48, 67)
		assert_gt(notes.size(), 2, "%s keeps its tones" % symbol)
		for note in notes:
			assert_between(note, 48, 67, "%s: %d" % [symbol, note])


func test_a_voicing_holds_every_pitch_class_of_a_triad() -> void:
	var chord := Chord.parse("Em")
	var classes := {}
	for note in chord.voice(48, 67):
		classes[posmod(note, 12)] = true
	assert_eq(classes.size(), 3, "E, G and B")


func test_tones_between_lists_only_chord_tones() -> void:
	assert_eq(Chord.parse("C").tones_between(55, 67), [55, 60, 64, 67] as Array[int])


func test_root_at_or_above_finds_the_nearest_root_up() -> void:
	assert_eq(Chord.parse("A").root_at_or_above(28), 33, "A1 above E1")
	assert_eq(Chord.parse("E").root_at_or_above(28), 28, "E1 itself")


func test_transposed_moves_the_root_and_keeps_the_quality() -> void:
	var chord := Chord.parse("Am7")
	var up_a_fifth := chord.transposed(7)
	assert_eq(up_a_fifth.root, 4, "A + 7 semitones = E")
	assert_eq(up_a_fifth.intervals, chord.intervals, "Quality carries over unchanged")
	assert_eq(chord.root, 9, "The original chord is untouched")


func test_transposed_wraps_the_root_to_a_pitch_class() -> void:
	var chord := Chord.parse("C")
	assert_eq(chord.transposed(12).root, chord.root, "A full octave is no move at all")
	assert_eq(chord.transposed(19).root, chord.transposed(7).root, "Wraps past an octave")
	assert_eq(chord.transposed(-5).root, chord.transposed(7).root, "A fourth down is a fifth up")


func test_transposed_chord_still_voices_inside_its_register() -> void:
	var chord := Chord.parse("Dm9").transposed(6)
	var notes := chord.voice(48, 67)
	assert_gt(notes.size(), 2, "Keeps its tones")
	for note in notes:
		assert_between(note, 48, 67, "%d" % note)
