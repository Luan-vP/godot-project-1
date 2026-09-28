extends GutTest
## Covers [TapReader]: a bar of snare taps read against 3, 4 and 6 with the
## two-way least-squares fit, including nesting (3 inside 6), wrapping round
## the bar line, and when a reading is sure enough to count.

var _table: RhythmTable
var _reader: TapReader


func before_each() -> void:
	_table = RhythmTable.default_table()
	_reader = TapReader.new(4.0)


## Tap [param phases] of the bar starting at [param bar_start] beats, then read
## just before the next bar.
func _read(phases: Array, bar_start: float = 8.0) -> TapReader.Reading:
	for phase: float in phases:
		_reader.add_tap(bar_start + phase * 4.0)
	return _reader.read(bar_start + 3.99, _table)


func test_distance_wraps_round_the_bar_line() -> void:
	assert_almost_eq(TapReader.circular_distance(0.95, 0.05), 0.1, 0.0001, "Across the line")
	assert_almost_eq(TapReader.circular_distance(0.25, 0.75), 0.5, 0.0001, "Opposite")


func test_a_clean_three_reads_as_three_not_six() -> void:
	var reading := _read([0.0, 1.0 / 3.0, 2.0 / 3.0])
	assert_eq(reading.winner, 3, "Winner")
	assert_almost_eq(reading.fits[3], 1.0, 0.001, "Perfect fit")
	assert_lt(reading.fits[6], 0.5, "Untapped pulses of 6 count against it")
	assert_true(reading.unambiguous, "Clear")


func test_a_clean_six_reads_as_six_not_three() -> void:
	var reading := _read([0.0, 1.0 / 6.0, 2.0 / 6.0, 3.0 / 6.0, 4.0 / 6.0, 5.0 / 6.0])
	assert_eq(reading.winner, 6, "Winner")
	assert_lt(reading.fits[3], reading.fits[6], "Taps between 3's pulses count against it")
	assert_true(reading.unambiguous, "Clear")


func test_a_clean_four_reads_as_four() -> void:
	var reading := _read([0.0, 0.25, 0.5, 0.75])
	assert_eq(reading.winner, 4, "Winner")
	assert_true(reading.unambiguous, "Clear")
	assert_lt(reading.fits[3], 0.5, "3 is a poor fit")


func test_a_sloppy_four_still_reads_as_four() -> void:
	var reading := _read([0.015, 0.235, 0.52, 0.74])
	assert_eq(reading.winner, 4, "Winner")
	assert_true(reading.unambiguous, "A few percent of a bar off is still clear")


func test_a_lone_downbeat_is_never_unambiguous() -> void:
	var reading := _read([0.0])
	assert_eq(reading.tap_count, 1, "One tap")
	assert_false(reading.unambiguous, "Too few taps to mean anything")
	assert_almost_eq(reading.confidence, 1.0 / 3.0, 0.0001, "A third of the taps needed")


func test_off_grid_taps_are_not_unambiguous() -> void:
	var reading := _read([0.1, 0.45, 0.8])
	assert_false(reading.unambiguous, "Nothing fits well")


func test_a_pattern_straddling_the_bar_line_still_reads() -> void:
	# The downbeat pulse played a touch early, at the end of the previous bar.
	_reader.add_tap(8.0 - 0.05)
	_reader.add_tap(8.0 + 4.0 / 3.0)
	_reader.add_tap(8.0 + 8.0 / 3.0)
	var reading := _reader.read(8.0 + 3.5, _table)
	assert_eq(reading.winner, 3, "Early downbeat is still the downbeat")
	assert_true(reading.unambiguous, "Clear")


func test_the_window_forgets_taps_older_than_a_bar() -> void:
	_reader.add_tap(0.0)
	_reader.add_tap(1.0)
	_reader.add_tap(5.5)
	assert_eq(_reader.window(6.0).size(), 1, "Only the tap within the last bar")


func test_no_taps_reads_as_nothing() -> void:
	var reading := _reader.read(10.0, _table)
	assert_eq(reading.winner, 0, "No winner")
	assert_eq(reading.confidence, 0.0, "No confidence")
	assert_false(reading.unambiguous, "Not unambiguous")


func test_quantise_snaps_to_the_nearest_pulse() -> void:
	assert_almost_eq(_reader.quantise(4.9, 4), 5.0, 0.0001, "Nearest beat")
	assert_almost_eq(_reader.quantise(5.1, 3), 16.0 / 3.0, 0.0001, "Nearest third of a bar")
