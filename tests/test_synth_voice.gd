extends GutTest
## Covers [SynthVoice]'s envelope and glide, and [Synth]'s voice stealing —
## all driven by hand, with no audio device.

const EPSILON := 0.001


func test_attack_reaches_full_level_in_the_same_time_at_any_frame_rate() -> void:
	# 30 and 120 fps both divide 0.1 s exactly, so neither run over- or undershoots.
	for fps in [30, 120]:
		var level := 0.0
		for i in fps / 10:
			level = SynthVoice.step_envelope(level, true, 0.1, 0.3, 1.0 / fps)
		assert_almost_eq(level, 1.0, EPSILON, "Attack complete at %d fps" % fps)


func test_release_falls_to_silence_and_stops_there() -> void:
	var level := 1.0
	for i in 40:
		level = SynthVoice.step_envelope(level, false, 0.01, 0.3, 0.01)
	assert_almost_eq(level, 0.0, EPSILON, "Silent after the release")
	assert_eq(SynthVoice.step_envelope(0.0, false, 0.01, 0.3, 0.01), 0.0, "Never below zero")


func test_a_zero_attack_still_ramps_rather_than_clicking() -> void:
	var level := SynthVoice.step_envelope(0.0, true, 0.0, 0.3, 0.001)
	assert_lt(level, 1.0, "One millisecond is not enough to reach full level")
	assert_almost_eq(level, 0.001 / SynthVoice.MIN_ENVELOPE_SECONDS, EPSILON, "Minimum ramp")


func test_glide_is_the_same_at_any_frame_rate() -> void:
	# 40 and 120 fps both reach 0.05 s — half the 0.1 s glide — in whole steps.
	var slow := _voice()
	var fast := _voice()
	for pair in [[slow, 40], [fast, 120]]:
		var voice: SynthVoice = pair[0]
		voice.note_on(220.0)
		voice.set_frequency(440.0)
		for i in pair[1] / 20:
			voice.advance(1.0 / pair[1])
	assert_almost_eq(slow.frequency, fast.frequency, 0.01, "Same pitch mid-glide")


func test_glide_arrives_exactly_on_time() -> void:
	assert_eq(SynthVoice.glide_at(220.0, 440.0, 0.5, 0.5), 440.0, "Arrived at the glide time")
	assert_almost_eq(SynthVoice.glide_at(220.0, 440.0, 0.0, 0.5), 220.0, 0.001, "Starts there")


func test_glide_starts_from_rest_so_its_first_step_is_small() -> void:
	# The fault this curve exists to avoid: pitch changes once per ~10 ms mix
	# block, and an exponential glide takes its biggest step at the very start.
	var first_block := SynthVoice.glide_at(220.0, 880.0, 0.0107, 0.6)
	var octaves := log(first_block / 220.0) / log(2.0)
	assert_lt(octaves, 0.01, "Under a tenth of a semitone in the first mix block")


func test_glide_midpoint_is_the_musical_midpoint() -> void:
	# Halfway through an octave glide the note sits at the geometric mean, a
	# tritone up, not the arithmetic mean.
	var middle := SynthVoice.glide_at(220.0, 440.0, 0.25, 0.5)
	assert_almost_eq(middle, 220.0 * sqrt(2.0), 0.01, "Tritone above the start")


func test_a_zero_glide_arrives_immediately() -> void:
	assert_eq(SynthVoice.glide_at(220.0, 440.0, 0.0, 0.0), 440.0)


func test_retargeting_mid_glide_continues_from_the_current_pitch() -> void:
	var voice := _voice()
	voice.note_on(220.0)
	voice.set_frequency(880.0)
	voice.advance(0.05)
	var before := voice.frequency
	voice.set_frequency(330.0)
	voice.advance(0.0001)
	assert_almost_eq(voice.frequency, before, 1.0, "No jump when the target changes")


func test_a_note_starts_at_its_pitch_and_only_set_frequency_glides() -> void:
	var voice := _voice()
	voice.note_on(220.0)
	voice.advance(0.05)
	voice.note_on(330.0)
	assert_eq(voice.frequency, 330.0, "A new note jumps, even on a sounding voice")
	voice.set_frequency(440.0)
	voice.advance(0.01)
	assert_between(voice.frequency, 330.0, 440.0, "A held note glides")


func test_retriggering_a_sounding_voice_does_not_restart_from_silence() -> void:
	var voice := _voice()
	voice.note_on(220.0)
	voice.advance(0.2)
	var before := voice.envelope
	voice.note_on(330.0)
	assert_eq(voice.envelope, before, "Envelope carries on")


func test_a_released_voice_finishes_and_goes_idle() -> void:
	var voice := _voice()
	watch_signals(voice)
	voice.note_on(220.0)
	voice.advance(0.1)
	voice.note_off()
	for i in 50:
		voice.advance(0.01)
	assert_false(voice.is_sounding(), "Idle after the release")
	assert_signal_emitted(voice, "finished")


func test_stealing_prefers_an_idle_voice() -> void:
	var voices := _voices(3)
	voices[0].note_on(220.0)
	voices[0].advance(0.1)
	voices[2].note_on(330.0)
	voices[2].advance(0.1)
	assert_eq(Synth.pick_voice(voices), 1, "The idle one")


func test_stealing_then_takes_the_quietest_released_voice() -> void:
	var voices := _voices(3)
	for voice in voices:
		voice.note_on(220.0)
		voice.advance(0.1)
	voices[0].note_off()
	voices[0].advance(0.05)
	voices[2].note_off()
	voices[2].advance(0.2)
	assert_eq(Synth.pick_voice(voices), 2, "Released longest ago is quietest")


func test_stealing_finally_takes_the_oldest_held_voice() -> void:
	var voices := _voices(3)
	for voice in voices:
		voice.note_on(220.0)
		voice.advance(0.1)
	voices[0].started_usec = 300
	voices[1].started_usec = 100
	voices[2].started_usec = 200
	assert_eq(Synth.pick_voice(voices), 1, "Oldest held")


func _voice() -> SynthVoice:
	var voice: SynthVoice = autofree(SynthVoice.new())
	var patch := SynthPatch.new()
	patch.attack_seconds = 0.05
	patch.release_seconds = 0.2
	patch.glide_seconds = 0.1
	voice.patch = patch
	return voice


func _voices(count: int) -> Array[SynthVoice]:
	var voices: Array[SynthVoice] = []
	for i in count:
		voices.append(_voice())
	return voices
