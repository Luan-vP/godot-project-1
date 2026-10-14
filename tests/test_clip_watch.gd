extends GutTest
## Covers how ClipWatch groups peak readings into overs and keeps the loudest
## reading per segment and per session.

var _watch: ClipWatch


func before_each() -> void:
	_watch = ClipWatch.new()


func test_readings_under_full_scale_are_never_an_over() -> void:
	for i in 10:
		assert_null(_watch.feed(0.9, i * 0.1), "No over")
	assert_false(_watch.is_over(), "Nothing open")
	assert_eq(_watch.session_overs, 0, "No overs")
	assert_almost_eq(_watch.session_peak, 0.9, 0.0001, "Peak kept")


func test_an_over_is_reported_once_it_has_been_quiet_for_the_gap() -> void:
	assert_null(_watch.feed(1.2, 1.0, 37), "Opens, not reported yet")
	assert_null(_watch.feed(1.5, 1.1), "Still going")
	assert_null(_watch.feed(0.5, 1.3), "Quiet, but not for long enough")
	var over := _watch.feed(0.5, 1.1 + ClipWatch.GAP_SECONDS)
	assert_not_null(over, "Ended")
	assert_almost_eq(over.peak, 1.5, 0.0001, "Loudest reading")
	assert_almost_eq(over.duration(), 0.1, 0.0001, "First to last over")
	assert_eq(over.bar, 37, "The bar it started in")
	assert_eq(_watch.session_overs, 1, "Counted once")


func test_loud_beats_close_together_are_one_over() -> void:
	for beat in 4:
		_watch.feed(1.1, beat * 0.3)
		_watch.feed(0.4, beat * 0.3 + 0.1)
	assert_eq(_watch.session_overs, 1, "One over")
	assert_true(_watch.is_over(), "Still open")


func test_flush_ends_an_open_over() -> void:
	_watch.feed(1.1, 0.0)
	assert_not_null(_watch.flush(), "Returned")
	assert_false(_watch.is_over(), "Closed")
	assert_null(_watch.flush(), "Nothing left")


func test_a_segment_resets_but_the_session_does_not() -> void:
	_watch.feed(1.3, 0.0)
	_watch.flush()
	var first := _watch.end_segment()
	assert_eq(first["overs"], 1, "Segment overs")
	assert_almost_eq(first["peak"], 1.3, 0.0001, "Segment peak")
	_watch.feed(0.6, 2.0)
	var second := _watch.end_segment()
	assert_eq(second["overs"], 0, "New segment starts clean")
	assert_almost_eq(second["peak"], 0.6, 0.0001, "Its own peak")
	assert_almost_eq(_watch.session_peak, 1.3, 0.0001, "Session keeps the loudest")
	assert_eq(_watch.session_overs, 1, "And the count")


func test_format_db() -> void:
	assert_eq(ClipWatch.format_db(1.0), "+0.0 dBFS")
	assert_eq(ClipWatch.format_db(0.5), "-6.0 dBFS")
	assert_eq(ClipWatch.format_db(0.0), "silent")
