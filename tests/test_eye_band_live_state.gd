extends GutTest
## Covers #76: [EyeBand] reading live tempo and key from [AudioManager] and its
## own offset instead of a [Song] baked once at [method EyeBand.start]. Driven
## directly — [method EyeBand._on_step] called by hand and [method
## EyeBand.set_key_offset] — the way the issue asks: no input map, no player,
## no waiting on real audio.

var _band: EyeBand
var _song: Song


func before_each() -> void:
	_song = _test_song()
	_band = EyeBand.new()
	add_child_autofree(_band)
	var eyes: Array[FloatyEye] = []
	for i in EyeBand.PARTS.size():
		eyes.append(_eye(40.0, Vector2(500, 300)))
	_band.bind_eyes(eyes)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_band.start(_song, rng)


func after_each() -> void:
	AudioManager.set_tempo(120.0, 4)


func test_seconds_per_step_follows_the_live_clock_not_the_songs_starting_tempo() -> void:
	var baked := 60.0 / _song.tempo_bpm / 4.0
	assert_almost_eq(_band._seconds_per_step(), baked, 0.0001, "Starts at the song's tempo")
	AudioManager.set_bpm(_song.tempo_bpm * 2.0)
	assert_almost_eq(
		_band._seconds_per_step(), baked / 2.0, 0.0001, "Doubling live tempo halves the step"
	)


func test_setting_the_same_key_offset_again_is_a_no_op() -> void:
	_band.set_key_offset(5)
	assert_eq(_band.get_key_offset(), 5)
	_band.set_key_offset(5)
	assert_eq(_band.get_key_offset(), 5)


func test_key_offset_transposes_chords_bass_arp_and_pads_together() -> void:
	_band.set_key_offset(7)  # Up a fifth: Dm9 -> Am9.
	_band._on_step(0, 0, 0)
	var expected_chord := Chord.parse("Dm9").transposed(7)

	var bass_voice: SynthVoice = _band._synths["bass"].get_voices()[0]
	var expected_bass := EyeBand.bass_note(expected_chord, "R", _song.bass_range.x)
	assert_almost_eq(
		bass_voice.target_frequency, EyeBand.midi_to_hz(expected_bass), 0.01, "Bass follows suit"
	)

	var arp_tones := expected_chord.tones_between(_song.arp_range.x, _song.arp_range.y)
	var arp_voice: SynthVoice = _band._synths["arp"].get_voices()[0]
	assert_almost_eq(
		arp_voice.target_frequency, EyeBand.midi_to_hz(arp_tones[0]), 0.01, "Arp follows suit"
	)

	var pad_notes := expected_chord.voice(_song.pad_range.x, _song.pad_range.y)
	var pad_voices: Array = _band._synths["pads"].get_voices()
	for i in pad_notes.size():
		assert_almost_eq(
			pad_voices[i].target_frequency,
			EyeBand.midi_to_hz(pad_notes[i]),
			0.01,
			"Pad note %d follows suit" % i
		)


func test_fold_melody_folds_down_when_transposition_pushes_past_the_top() -> void:
	var bars := [[[0, 65, 4], [4, 69, 4]]]  # One bar: a note mid-range, one at the ceiling.
	var register := Vector2i(57, 69)
	var folded: Array = EyeBand._fold_melody(bars, 7, register)
	# +7 alone would push 69 to 76, past the ceiling, so the whole bar folds
	# down an octave together rather than just the note that overflowed.
	assert_eq(folded[0][0][1], 65 + 7 - 12, "First note folds too, keeping the shape")
	assert_eq(folded[0][1][1], 69 + 7 - 12)
	for note in folded[0]:
		assert_between(note[1], register.x, register.y)


func test_fold_melody_does_not_fold_when_the_shift_already_fits() -> void:
	var bars := [[[0, 57, 4]]]
	var register := Vector2i(57, 69)
	var folded: Array = EyeBand._fold_melody(bars, 4, register)
	assert_eq(folded[0][0][1], 61, "No fold needed: 57 + 4 = 61 is already in range")


func test_fold_melody_preserves_step_to_step_contour() -> void:
	var written: Array = MelodyWriter.write_section(_song, "A")
	var folded: Array = EyeBand._fold_melody(written, 7, _song.melody_range)
	for bar_index in written.size():
		assert_eq(folded[bar_index].size(), written[bar_index].size(), "Same notes per bar")
		for note_index in written[bar_index].size():
			var original: Array = written[bar_index][note_index]
			var shifted: Array = folded[bar_index][note_index]
			assert_eq(shifted[0], original[0], "Same step")
			assert_eq(shifted[2], original[2], "Same length")
		for note_index in range(1, written[bar_index].size()):
			var original_step: int = (
				written[bar_index][note_index][1] - written[bar_index][note_index - 1][1]
			)
			var folded_step: int = (
				folded[bar_index][note_index][1] - folded[bar_index][note_index - 1][1]
			)
			assert_eq(folded_step, original_step, "Interval between notes is preserved")


func test_key_change_crossfades_pads_without_stealing_the_outgoing_voicing() -> void:
	_band._on_step(0, 0, 0)  # Dm9 pads voice in: five notes.
	var pad_synth: Synth = _band._synths["pads"]
	var outgoing_voices: Array[SynthVoice] = []
	for voice in pad_synth.get_voices():
		if voice.is_held():
			outgoing_voices.append(voice)
			# Past SynthVoice.START_TIMEOUT_SECONDS in one hand-driven step, so
			# the envelope moves regardless of whether the audio thread has
			# actually started mixing this voice yet — see SynthVoice.advance.
			voice.advance(0.3)
	assert_gt(outgoing_voices.size(), 2, "Dm9 voices several pad notes")

	_band.set_key_offset(7)  # Re-voices pads with the transposed shape at once.

	for voice in outgoing_voices:
		assert_false(voice.is_held(), "Outgoing voice is releasing, not cut")
		assert_true(voice.is_sounding(), "Outgoing voice is still audible, not stolen")

	var incoming_voices: Array[SynthVoice] = []
	for voice in pad_synth.get_voices():
		if voice.is_held():
			incoming_voices.append(voice)
	assert_eq(incoming_voices.size(), outgoing_voices.size(), "Same shape, transposed")
	for voice in incoming_voices:
		assert_false(voice in outgoing_voices, "The new voicing did not reuse an outgoing voice")

	# Ten voices in flight together is exactly why pads need more than the
	# eight every other part manages with — see PATCHES's comment.
	assert_gt(outgoing_voices.size() + incoming_voices.size(), 8)


func _test_song() -> Song:
	var song := Song.new()
	song.title = "Test Song"
	song.tempo_bpm = 70.0
	song.key_root = 2
	song.scale = [0, 2, 3, 5, 7, 9, 10]
	song.start_section = "A"
	song.sections = {"A": {"bars": "Dm9 | G", "next": {"A": 1}}}
	var silence := ".".repeat(16)
	song.drums = {
		"beat": {"kick": silence},
		"ghost": {"kick": silence},
		"shimmer": {"kick": silence},
		"fill": {"kick": silence},
	}
	song.bass_line = "R" + silence.substr(1)
	song.bass_hold_steps = 4
	song.arp_pattern = "0" + silence.substr(1)
	song.melody_rhythms = ["x-------x-------"]
	return song


func _eye(radius: float, at: Vector2) -> FloatyEye:
	var eye := FloatyEye.new()
	eye.radius = radius
	add_child_autofree(eye)
	eye.global_position = at
	return eye
