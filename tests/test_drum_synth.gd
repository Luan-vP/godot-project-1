extends GutTest
## Covers [DrumSynth]: every hit renders, at the same peak, identically every
## time, and sounds roughly like what it is named.

const RATE := 48000


func test_every_hit_renders_at_the_normalised_peak() -> void:
	for hit in DrumSynth.Hit.values():
		var sound := DrumSynth.render(hit, RATE)
		assert_gt(sound.size(), RATE / 50, "Hit %d is at least 20 ms" % hit)
		assert_almost_eq(_peak(sound), DrumSynth.HIT_PEAK, 0.001, "Hit %d peak" % hit)


func test_hits_are_deterministic() -> void:
	var first := DrumSynth._normalised(DrumSynth._build(DrumSynth.Hit.SNARE, RATE))
	var second := DrumSynth._normalised(DrumSynth._build(DrumSynth.Hit.SNARE, RATE))
	assert_eq(first, second, "Same noise every build")


func test_a_kick_falls_in_pitch() -> void:
	var kick := DrumSynth.render(DrumSynth.Hit.KICK, RATE)
	var window := int(0.025 * RATE)
	var early := _crossings(kick, int(0.005 * RATE), window)
	var late := _crossings(kick, int(0.15 * RATE), window)
	assert_gt(early, late, "More crossings early than late")


func test_hats_are_bright_and_kicks_are_not() -> void:
	var window := int(0.02 * RATE)
	var hat := _crossings(DrumSynth.render(DrumSynth.Hit.CLOSED_HAT, RATE), 0, window)
	var kick := _crossings(DrumSynth.render(DrumSynth.Hit.KICK, RATE), int(0.01 * RATE), window)
	assert_gt(hat, kick * 20, "Hat crosses zero far more often")


func test_an_open_hat_rings_longer_than_a_closed_one() -> void:
	var closed := DrumSynth.render(DrumSynth.Hit.CLOSED_HAT, RATE)
	var open := DrumSynth.render(DrumSynth.Hit.OPEN_HAT, RATE)
	assert_gt(open.size(), closed.size() * 4)


func test_hit_names_resolve() -> void:
	assert_eq(DrumSynth.hit_from_name("kick"), DrumSynth.Hit.KICK)
	assert_eq(DrumSynth.hit_from_name("Hat"), DrumSynth.Hit.CLOSED_HAT)
	assert_eq(DrumSynth.hit_from_name("open_hat"), DrumSynth.Hit.OPEN_HAT)
	assert_eq(DrumSynth.hit_from_name("cowbell"), -1, "Unknown")


func _peak(sound: PackedFloat32Array) -> float:
	var peak := 0.0
	for sample in sound:
		peak = maxf(peak, absf(sample))
	return peak


## Sign changes, ignoring samples within a hair of zero: a decayed noise
## residue jitters around zero crossings and would count as many.
func _crossings(sound: PackedFloat32Array, from: int, length: int) -> int:
	var count := 0
	var last_sign := 0
	for i in range(from, mini(from + length, sound.size())):
		if absf(sound[i]) < 0.001:
			continue
		var sign := 1 if sound[i] > 0.0 else -1
		if last_sign != 0 and sign != last_sign:
			count += 1
		last_sign = sign
	return count
