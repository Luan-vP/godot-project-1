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
	var moved := Chord.parse("Am7").transposed(5)
	assert_eq(moved.root, 2, "A up a fourth is D")
	assert_eq(moved.intervals, Chord.parse("Am7").intervals, "Still minor 7")
	assert_eq(Chord.parse("Am7").root, 9, "The original chord is untouched")


func test_transposed_wraps_the_root_rather_than_climbing() -> void:
	assert_eq(Chord.parse("C").transposed(11).root, 11, "B, not C an octave up")
	assert_eq(Chord.parse("C").transposed(-1).root, 11, "Wraps down to B too")


## Up a fourth (+5) and down a fifth (-7) name the same root, as #71 needs:
## whichever way the player nudges the key, the two moves must agree.
func test_a_fourth_up_and_a_fifth_down_land_on_the_same_root() -> void:
	var chord := Chord.parse("C")
	assert_eq(chord.transposed(5).root, chord.transposed(-7).root)


## Repeated calls (as #71's controls make them) must agree with one call for
## the accumulated total — nothing here depends on folding the offset to a
## smaller equivalent first.
func test_repeated_transposition_matches_the_accumulated_total() -> void:
	var stepped := Chord.parse("G").transposed(5).transposed(5)
	var direct := Chord.parse("G").transposed(10)
	assert_eq(stepped.root, direct.root)
