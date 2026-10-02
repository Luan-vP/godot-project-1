extends GutTest
## Covers #110: [PegScale] laying a scale low to high across the pins, and
## scrolling a new one in from the left, one pin per advance.

var _scale: PegScale


func before_each() -> void:
	_scale = PegScale.new()
	_scale.configure(8, 48)


func _notes() -> Array[int]:
	var notes: Array[int] = []
	for pin in _scale.pin_count():
		notes.append(_scale.note_for(pin))
	return notes


func _finish() -> void:
	while _scale.is_scrolling():
		_scale.advance()


func test_notes_climb_left_to_right_across_octaves() -> void:
	# C major pentatonic from C3.
	var notes := PegScale.notes_for(0, PegScale.MAJOR_PENTATONIC, 48, 8)
	assert_eq(notes, [48, 50, 52, 55, 57, 60, 62, 64] as Array[int])


func test_lowest_pin_is_the_first_scale_tone_at_or_above_low_note() -> void:
	# A minor pentatonic from C3: C D E G A, then up.
	var notes := PegScale.notes_for(9, PegScale.MINOR_PENTATONIC, 48, 6)
	assert_eq(notes, [48, 50, 52, 55, 57, 60] as Array[int])


func test_pentatonic_matches_each_songs_key() -> void:
	for song in EyeBandSongs.all():
		var minor := song.scale[2] == 3
		var scale := PegScale.new()
		scale.configure(10, 48)
		scale.set_key(song.key_root, minor)
		scale.snap()
		for pin in 10:
			var degree := posmod(scale.note_for(pin) - song.key_root, 12)
			assert_has(PegScale.pentatonic_for(minor), degree, "%s pin %d" % [song.title, pin])


func test_a_scale_swap_flips_one_pin_per_advance_left_to_right() -> void:
	_scale.set_key(0, false)
	_finish()
	var before := _notes()
	_scale.set_scale_named("blues")
	var after := PegScale.notes_for(0, [0, 3, 5, 6, 7, 10] as Array[int], 48, 8)
	for flipped in 8:
		_scale.advance()
		for pin in 8:
			var expected := after[pin] if pin <= flipped else before[pin]
			assert_eq(_scale.note_for(pin), expected, "After %d, pin %d" % [flipped, pin])
	assert_false(_scale.is_scrolling(), "Settled at the right-hand end")


func test_a_key_change_scrolls_too() -> void:
	_scale.set_key(9, true)
	_finish()
	_scale.set_key(2, true)
	assert_true(_scale.is_scrolling(), "New key scrolls in")
	assert_eq(_scale.pending_for(2), 53, "E waits to become F")
	_finish()
	assert_eq(_notes(), PegScale.notes_for(2, PegScale.MINOR_PENTATONIC, 48, 8))


func test_following_the_key_swaps_pentatonic_with_the_mode() -> void:
	_scale.set_key(0, false)
	_scale.snap()
	assert_eq(_scale.scale_name(), "major pentatonic")
	_scale.set_key(0, true)
	assert_eq(_scale.scale_name(), "minor pentatonic")


func test_a_picked_scale_survives_a_key_change() -> void:
	_scale.set_scale_named("dorian")
	_scale.set_key(4, true)
	_finish()
	assert_eq(_scale.scale_name(), "dorian")
	assert_eq(_notes(), PegScale.notes_for(4, [0, 2, 3, 5, 7, 9, 10] as Array[int], 48, 8))


func test_a_change_mid_scroll_restarts_from_the_left_towards_the_newest() -> void:
	_scale.set_key(0, false)
	_finish()
	_scale.set_scale_named("major")
	_scale.advance()
	_scale.advance()
	_scale.advance()
	_scale.set_scale_named("blues")
	assert_eq(_scale.scroll_position(), 0, "Back to the left")
	_finish()
	assert_eq(_notes(), PegScale.notes_for(0, [0, 3, 5, 6, 7, 10] as Array[int], 48, 8))


func test_pin_changed_fires_once_per_flip() -> void:
	_scale.set_key(0, false)
	_finish()
	watch_signals(_scale)
	_scale.set_key(7, false)
	_finish()
	var changed := 0
	var target := PegScale.notes_for(7, PegScale.MAJOR_PENTATONIC, 48, 8)
	var before := PegScale.notes_for(0, PegScale.MAJOR_PENTATONIC, 48, 8)
	for pin in 8:
		if target[pin] != before[pin]:
			changed += 1
	assert_signal_emit_count(_scale, "pin_changed", changed)


func test_pending_is_minus_one_once_settled() -> void:
	_finish()
	for pin in 8:
		assert_eq(_scale.pending_for(pin), -1)


func test_cycle_walks_every_scale() -> void:
	var seen := {}
	var name := _scale.scale_name()
	for i in PegScale.CYCLE.size():
		name = _scale.next_scale_name()
		_scale.set_scale_named(name)
		seen[name] = true
	assert_eq(seen.size(), PegScale.CYCLE.size())
