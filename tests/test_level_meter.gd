extends GutTest
## Covers LevelMeter's log lines and notes, the Master bus capture and limiter
## it reads, and the overlay's scale.

var _meter: LevelMeter


func before_each() -> void:
	_meter = LevelMeter.new()
	_meter.set_process(false)
	add_child_autofree(_meter)


func test_audio_manager_owns_a_meter() -> void:
	assert_not_null(AudioManager.get_level_meter(), "Meter")


func test_master_has_a_capture_before_its_limiter() -> void:
	var master := AudioServer.get_bus_index(AudioManager.MASTER_BUS)
	var count := AudioServer.get_bus_effect_count(master)
	assert_eq(count, 2, "Two effects")
	assert_true(AudioServer.get_bus_effect(master, 0) is AudioEffectCapture, "Capture first")
	assert_true(AudioServer.get_bus_effect(master, 1) is AudioEffectHardLimiter, "Then limiter")


func test_notes_print_in_order() -> void:
	_meter.set_note("song", "Glass Tide")
	_meter.set_note("level", "BoidsLevel")
	_meter.set_note("demo", "fluid_carousel")
	assert_eq(_meter.describe(), "demo=fluid_carousel · level=BoidsLevel · song=Glass Tide")
	_meter.set_note("level", "")
	assert_eq(_meter.describe(), "demo=fluid_carousel · song=Glass Tide", "Cleared")


func test_an_over_line_says_how_loud_how_long_where() -> void:
	_meter.set_note("song", "Glass Tide")
	var over := ClipWatch.Episode.new()
	over.peak = db_to_linear(1.4)
	over.start_seconds = 2.0
	over.end_seconds = 2.12
	over.bar = 37
	assert_eq(
		_meter.format_over(over), "[level] OVER +1.4 dBFS for 0.12 s at bar 37 · song=Glass Tide"
	)


func test_changing_level_ends_the_segment() -> void:
	_meter.set_note("level", "A")
	_meter.watch.feed(0.5, 0.0)
	_meter.set_note("level", "B")
	assert_eq(_meter.watch.segment_peak, 0.0, "New segment")
	assert_almost_eq(_meter.watch.session_peak, 0.5, 0.0001, "Session kept")


func test_an_over_still_open_is_reported_when_the_level_changes() -> void:
	watch_signals(_meter)
	_meter.watch.feed(1.2, 0.0)
	_meter.set_note("level", "Next")
	assert_signal_emitted(_meter, "over_ended")


func test_the_overlay_scale() -> void:
	assert_eq(LevelMeterOverlay.fraction_for_db(LevelMeterOverlay.FLOOR_DB), 0.0)
	assert_eq(LevelMeterOverlay.fraction_for_db(LevelMeterOverlay.TOP_DB), 1.0)
	assert_eq(LevelMeterOverlay.fraction_for_db(100.0), 1.0, "Clamped")
	assert_ne(LevelMeterOverlay.colour_for_db(0.0), LevelMeterOverlay.colour_for_db(-20.0))
