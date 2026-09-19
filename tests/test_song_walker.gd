extends GutTest
## Covers [SongWalker]: branching only where a song allows, the path staying put
## once laid, and seeds reproducing a walk.


func _song() -> Song:
	var song := Song.new()
	song.title = "Test"
	song.start_section = "A"
	song.sections = {
		"A": {"bars": "Am | F", "next": {"B": 1, "C": 1}},
		"B": {"bars": "C | G | Em", "next": {"A": 1}},
		"C": {"bars": "Dm", "next": {"A": 1, "C": 1}},
	}
	return song


func _walker(seed_value: int) -> SongWalker:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return SongWalker.new(_song(), rng)


func test_the_walk_starts_on_the_start_section() -> void:
	var walker := _walker(1)
	assert_eq(walker.section_at(0), "A")
	assert_eq(walker.chord_at(0, 0).symbol, "Am")
	assert_eq(walker.chord_at(1, 0).symbol, "F")


func test_sections_only_follow_ones_that_lead_to_them() -> void:
	var song := _song()
	var walker := _walker(7)
	var previous := walker.section_at(0)
	for bar in range(1, 400):
		if walker.is_first_bar_of_section(bar):
			var section := walker.section_at(bar)
			assert_has(song.sections[previous]["next"], section, "%s -> %s" % [previous, section])
		previous = walker.section_at(bar)


func test_every_branch_gets_taken_over_a_long_walk() -> void:
	var walker := _walker(3)
	var seen := {}
	for bar in 400:
		seen[walker.section_at(bar)] = true
	assert_eq(seen.size(), 3, "A, B and C all come up")


func test_a_laid_path_does_not_change_when_asked_again() -> void:
	var walker := _walker(11)
	var far := walker.section_at(60)
	for bar in 60:
		walker.section_at(bar)
	assert_eq(walker.section_at(60), far, "Bar 60 is still the same section")


func test_the_same_seed_walks_the_same_way() -> void:
	var one := _walker(42)
	var two := _walker(42)
	for bar in 120:
		assert_eq(one.section_at(bar), two.section_at(bar), "bar %d" % bar)


func test_the_last_bar_of_a_section_is_marked_for_fills() -> void:
	var walker := _walker(1)
	assert_false(walker.is_last_bar_of_section(0), "Am starts A")
	assert_true(walker.is_last_bar_of_section(1), "F ends A")


func test_half_bars_split_the_bar_between_two_chords() -> void:
	var song := Song.new()
	song.sections = {"A": {"bars": "D,Bm7", "next": {"A": 1}}}
	var chords: Array = song.bars_of("A")[0]
	assert_eq(song.chord_in_bar(chords, 0).symbol, "D")
	assert_eq(song.chord_in_bar(chords, 7).symbol, "D")
	assert_eq(song.chord_in_bar(chords, 8).symbol, "Bm7")


func test_zero_weight_branches_are_never_picked() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 200:
		assert_eq(SongWalker.pick_weighted({"never": 0, "always": 3}, rng), "always")
