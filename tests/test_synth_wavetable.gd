extends GutTest
## Covers [SynthWavetable]: that no band can alias at any pitch it is used for,
## that the crossfade between bands is well formed, and the tables themselves.

const MIX_RATE := 48000.0
const EPSILON := 0.0001


func test_no_audible_band_ever_puts_a_harmonic_past_safe_nyquist() -> void:
	# The alias guarantee itself: sweep the playable range and check every band
	# that is audible at that pitch, for both harmonic-rich waveforms.
	var ceiling := SynthWavetable.SAFE_NYQUIST_FRACTION * MIX_RATE
	for waveform in [SynthWavetable.Waveform.SAW, SynthWavetable.Waveform.SQUARE]:
		var hz := 20.0
		while hz < 16000.0:
			var weights := SynthWavetable.band_weights(hz)
			for band in weights.size():
				if weights[band] > 0.0:
					var top_harmonic := SynthWavetable.harmonic_limit(waveform, band, MIX_RATE)
					assert_true(
						top_harmonic * hz <= ceiling + EPSILON,
						"Band %d at %.0f Hz reaches %.0f Hz" % [band, hz, top_harmonic * hz]
					)
			hz *= 1.03


func test_band_weights_sum_to_one_with_at_most_two_bands() -> void:
	var hz := 20.0
	while hz < 20000.0:
		var weights := SynthWavetable.band_weights(hz)
		var total := 0.0
		var used := 0
		for w in weights:
			total += w
			if w > 0.0:
				used += 1
		assert_almost_eq(total, 1.0, EPSILON, "Weights sum to one at %.0f Hz" % hz)
		assert_lte(used, 2, "At most two bands at %.0f Hz" % hz)
		hz *= 1.07


func test_band_weights_are_continuous_across_an_octave_boundary() -> void:
	var boundary := SynthWavetable.LOWEST_BAND_HZ * 8.0
	var below := SynthWavetable.band_weights(boundary * 0.9999)
	var above := SynthWavetable.band_weights(boundary * 1.0001)
	for band in below.size():
		assert_almost_eq(below[band], above[band], 0.01, "No jump in band %d" % band)


func test_lower_bands_hold_more_harmonics() -> void:
	var saw := SynthWavetable.Waveform.SAW
	for band in SynthWavetable.BAND_COUNT - 1:
		assert_gte(
			SynthWavetable.harmonic_limit(saw, band, MIX_RATE),
			SynthWavetable.harmonic_limit(saw, band + 1, MIX_RATE),
			"Band %d" % band
		)
	assert_eq(SynthWavetable.harmonic_limit(SynthWavetable.Waveform.SINE, 0, MIX_RATE), 1)


func test_a_one_harmonic_saw_is_a_scaled_sine() -> void:
	var cycle := SynthWavetable.build_cycle(SynthWavetable.Waveform.SAW, 1)
	var size := SynthWavetable.CYCLE_SAMPLES
	var peak := SynthWavetable.TABLE_GAIN * 2.0 / PI
	assert_almost_eq(cycle[size / 4], peak, 0.001, "Quarter cycle")
	assert_almost_eq(cycle[0], 0.0, 0.001, "Starts at zero")


func test_cycles_have_no_dc_and_stay_in_range() -> void:
	for waveform in [SynthWavetable.Waveform.SAW, SynthWavetable.Waveform.SQUARE]:
		var cycle := SynthWavetable.build_cycle(waveform, 540)
		var total := 0.0
		for sample in cycle:
			total += sample
			assert_between(sample, -1.0, 1.0, "In range")
		assert_almost_eq(total / cycle.size(), 0.0, 0.001, "No DC offset")


func test_a_square_holds_only_odd_harmonics() -> void:
	# Adding the even harmonic 2 to a square changes nothing.
	var one := SynthWavetable.build_cycle(SynthWavetable.Waveform.SQUARE, 1)
	var two := SynthWavetable.build_cycle(SynthWavetable.Waveform.SQUARE, 2)
	for i in range(0, one.size(), 97):
		assert_almost_eq(one[i], two[i], EPSILON, "Sample %d" % i)


func test_bands_are_looping_single_cycles_and_cached() -> void:
	var saw := SynthWavetable.bands(SynthWavetable.Waveform.SAW, MIX_RATE)
	assert_eq(saw.size(), SynthWavetable.BAND_COUNT, "One stream per band")
	assert_eq(SynthWavetable.bands(SynthWavetable.Waveform.SINE, MIX_RATE).size(), 1, "Sine")
	var stream: AudioStreamWAV = saw[0]
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Loops")
	assert_eq(stream.loop_end, SynthWavetable.CYCLE_SAMPLES, "Exactly one cycle")
	assert_eq(stream.data.size(), SynthWavetable.CYCLE_SAMPLES * 2, "16-bit mono")
	assert_same(SynthWavetable.bands(SynthWavetable.Waveform.SAW, MIX_RATE), saw, "Cached")
