extends GutTest
## Covers the eye band's songs as written: each is sound, reachable end to end,
## slow, and never shrill, and the melody writer keeps to its rules over them.


func test_there_are_several_distinct_songs() -> void:
	var titles := {}
	for song in EyeBandSongs.all():
		titles[song.title] = true
	assert_between(titles.size(), 3, 4, "Three or four songs, each with its own title")


func test_every_song_is_written_without_mistakes() -> void:
	for song in EyeBandSongs.all():
		assert_eq(song.problems(), PackedStringArray(), song.title)


func test_every_section_can_be_reached_from_the_start() -> void:
	for song in EyeBandSongs.all():
		var reached := {song.start_section: true}
		var frontier: Array = [song.start_section]
		while not frontier.is_empty():
			var section: String = frontier.pop_back()
			for target in song.sections[section]["next"]:
				if not reached.has(target):
					reached[target] = true
					frontier.append(target)
		assert_eq(reached.size(), song.sections.size(), "%s: every section plays" % song.title)


func test_songs_are_slow_and_have_room_to_branch() -> void:
	for song in EyeBandSongs.all():
		assert_between(song.tempo_bpm, 55.0, 80.0, "%s tempo" % song.title)
		assert_gt(song.sections.size(), 2, "%s has at least three sections" % song.title)


func test_songs_carry_every_drum_part_and_a_fill() -> void:
	for song in EyeBandSongs.all():
		for layer in EyeBand.DRUM_PARTS + [EyeBand.FILL]:
			assert_has(song.drums, layer, "%s: %s" % [song.title, layer])


func test_nothing_climbs_above_a4() -> void:
	for song in EyeBandSongs.all():
		for range_value in [song.pad_range, song.arp_range, song.melody_range]:
			assert_lte(range_value.y, 69, "%s register top" % song.title)


func test_melodies_stay_in_range_and_land_on_chord_tones_on_the_beat() -> void:
	for song in EyeBandSongs.all():
		for section in song.sections:
			var bars := song.bars_of(section)
			var melody := MelodyWriter.write_section(song, section)
			assert_eq(melody.size(), bars.size(), "%s/%s one entry per bar" % [song.title, section])
			for bar_index in melody.size():
				for note in melody[bar_index]:
					assert_between(note[1], song.melody_range.x, song.melody_range.y)
					if note[0] % 4 == 0:
						var chord := song.chord_in_bar(bars[bar_index], note[0])
						assert_true(
							chord.contains(note[1]),
							(
								"%s/%s bar %d step %d on %s"
								% [song.title, section, bar_index, note[0], chord.symbol]
							)
						)


func test_a_section_melody_is_the_same_every_time() -> void:
	var song := EyeBandSongs.glass_tide()
	assert_eq(MelodyWriter.write_section(song, "B"), MelodyWriter.write_section(song, "B"))


func test_bass_symbols_pick_root_octave_fifth_and_third() -> void:
	var chord := Chord.parse("Am")
	assert_eq(EyeBand.bass_note(chord, "R", 28), 33, "A1")
	assert_eq(EyeBand.bass_note(chord, "O", 28), 45, "A2")
	assert_eq(EyeBand.bass_note(chord, "5", 28), 40, "E2")
	assert_eq(EyeBand.bass_note(chord, "3", 28), 36, "C2, the minor third")
	assert_eq(EyeBand.bass_note(chord, ".", 28), -1, "Rest")
