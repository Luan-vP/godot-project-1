extends GutTest
## Covers the procedural tone [AudioManager]'s demo plays, so "audible proof"
## is more than a claim in a PR description.


func test_stream_length_matches_the_requested_duration() -> void:
	var stream := AudioTestTone.generate(440.0, 0.5)
	var expected_frames := int(44100 * 0.5)
	assert_eq(stream.data.size(), expected_frames * 2, "16-bit mono: two bytes per frame")


func test_stream_is_not_silent() -> void:
	var stream := AudioTestTone.generate(440.0, 0.2, 0.8)
	var loudest := 0
	for i in stream.data.size() / 2:
		loudest = maxi(loudest, absi(stream.data.decode_s16(i * 2)))
	assert_gt(loudest, 20000, "A 0.8-amplitude tone should read well above silence")


func test_fades_in_from_silence_so_it_does_not_click() -> void:
	var stream := AudioTestTone.generate(440.0, 0.5, 0.8)
	assert_eq(stream.data.decode_s16(0), 0, "First sample should start at zero")


func test_is_mono_16_bit() -> void:
	var stream := AudioTestTone.generate()
	assert_false(stream.stereo, "Tone should be mono")
	assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
