extends GutTest
## Covers #109: [Band], the eye band's music with no eyes — every part playing
## by default, parts switched by hand, and the key reported to followers.

var _band: Band


func before_each() -> void:
	_band = Band.new()
	add_child_autofree(_band)


func after_each() -> void:
	AudioManager.set_tempo(120.0, 4)


func _start(song: Song) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	_band.start(song, rng)


func test_with_no_gate_every_part_is_wanted() -> void:
	for part in Band.PARTS:
		assert_true(_band.wants_part(part), "%s plays by default" % part)


func test_starting_plays_every_part_from_the_first_bar() -> void:
	_start(EyeBandSongs.glass_tide())
	for part in Band.PARTS:
		assert_true(_band.is_playing(part), "%s sounding" % part)


func test_set_part_wanted_switches_a_part() -> void:
	_band.set_part_wanted("bass", false)
	assert_false(_band.wants_part("bass"), "Bass switched off")
	assert_true(_band.wants_part("beat"), "The rest carry on")
	_band.set_part_wanted("bass", true)
	assert_true(_band.wants_part("bass"), "And back on")


func test_key_changed_fires_once_per_actual_change() -> void:
	watch_signals(_band)
	_band.set_key_offset(5)
	_band.set_key_offset(5)
	assert_signal_emit_count(_band, "key_changed", 1)
	assert_signal_emitted_with_parameters(_band, "key_changed", [5])


func test_key_root_and_mode_for_every_song() -> void:
	var expected := {
		"Glass Tide": [9, true],
		"Low Sun": [2, true],
		"Night Pool": [5, false],
		"Slow Orbit": [4, true],
	}
	for song in EyeBandSongs.all():
		var band := Band.new()
		add_child_autofree(band)
		var rng := RandomNumberGenerator.new()
		band.start(song, rng)
		assert_eq(band.key_root(), expected[song.title][0], "%s root" % song.title)
		assert_eq(band.is_minor(), expected[song.title][1], "%s mode" % song.title)


func test_key_root_follows_the_offset_round_the_circle() -> void:
	_start(EyeBandSongs.glass_tide())  # A minor.
	_band.set_key_offset(5)
	assert_eq(_band.key_root(), 2, "Up a fourth: D")
	_band.set_key_offset(-7)
	assert_eq(_band.key_root(), 2, "Down a fifth lands on D too")
	_band.set_key_offset(15)
	assert_eq(_band.key_root(), 0, "Wraps: A + 15 = C")
	assert_true(_band.is_minor(), "The mode never moves")


func test_stepped_is_emitted_after_each_step() -> void:
	_start(EyeBandSongs.glass_tide())
	watch_signals(_band)
	_band._on_step(0, 0, 3)
	assert_signal_emitted_with_parameters(_band, "stepped", [0, 3])
