extends GutTest
## Covers [method MelodyWriter.transposed]: moving a written melody by a
## key shift (#71) without rewriting it, and folding back into range by
## whole octaves — preserving contour — when a shift pushes it out.

const LOW := 57
const HIGH := 69


func test_every_note_moves_by_the_same_amount_when_nothing_leaves_range() -> void:
	var written := [[[0, 60, 1], [4, 64, 1]], [[0, 67, 2]]]
	var moved := MelodyWriter.transposed(written, 2, LOW, HIGH)
	assert_eq(moved, [[[0, 62, 1], [4, 66, 1]], [[0, 69, 2]]])


func test_start_step_and_length_are_left_alone() -> void:
	var written := [[[3, 60, 2]]]
	var moved := MelodyWriter.transposed(written, -1, LOW, HIGH)
	assert_eq(moved[0][0][0], 3, "Start step")
	assert_eq(moved[0][0][2], 2, "Length")


func test_the_input_is_not_mutated() -> void:
	var written := [[[0, 60, 1]]]
	MelodyWriter.transposed(written, 5, LOW, HIGH)
	assert_eq(written[0][0][1], 60, "Original notes untouched")


func test_a_shift_past_the_top_folds_the_whole_line_down_an_octave() -> void:
	# +7 alone would put the highest note at 69 + 7 = 76, over HIGH.
	var written := [[[0, 65, 1]], [[0, 69, 1]]]
	var moved := MelodyWriter.transposed(written, 7, LOW, HIGH)
	assert_eq(moved[0][0][1], 65 + 7 - 12, "First note folded down an octave")
	assert_eq(moved[1][0][1], 69 + 7 - 12, "Second note folded by the same octave")
	assert_between(moved[1][0][1], LOW, HIGH, "Back in range")


func test_folding_preserves_the_interval_between_notes() -> void:
	# Contour is the point: every note must move by exactly the same amount,
	# never note by note, or a step turns into a leap.
	var written := [[[0, 60, 1], [4, 64, 1], [8, 67, 1]]]
	var moved := MelodyWriter.transposed(written, 9, LOW, HIGH)
	var shift: int = moved[0][0][1] - 60
	for i in 3:
		assert_eq(moved[0][i][1], written[0][i][1] + shift, "Note %d moved by the same shift" % i)


func test_a_zero_shift_that_still_fits_changes_nothing() -> void:
	var written := [[[0, 60, 1]]]
	assert_eq(MelodyWriter.transposed(written, 0, LOW, HIGH), written)


func test_an_empty_line_is_returned_unchanged() -> void:
	var written := [[], []]
	assert_eq(MelodyWriter.transposed(written, 5, LOW, HIGH), written)
