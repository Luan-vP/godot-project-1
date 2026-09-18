extends GutTest
## Covers [DrumKit]: velocity becomes level, the pool steals in the same order
## as [Synth], the pool never grows, and a closed hat chokes an open one.

var _kit: DrumKit


func before_each() -> void:
	_kit = DrumKit.new()
	add_child_autofree(_kit)


func test_zero_velocity_plays_nothing() -> void:
	_kit.play(DrumSynth.Hit.KICK, 0.0)
	assert_eq(_sounding_players().size(), 0, "Nothing triggered")


func test_full_velocity_is_unity_gain_at_zero_level() -> void:
	_kit.play(DrumSynth.Hit.KICK, 1.0)
	var sounding := _sounding_players()
	assert_eq(sounding.size(), 1, "One voice used")
	assert_almost_eq(sounding[0].volume_db, 0.0, 0.001, "Full velocity, no part attenuation")


func test_velocity_and_level_both_attenuate() -> void:
	_kit.play(DrumSynth.Hit.SNARE, 0.5, -6.0)
	var sounding := _sounding_players()
	assert_almost_eq(sounding[0].volume_db, linear_to_db(0.5) - 6.0, 0.001)


func test_concurrent_hits_use_different_players() -> void:
	_kit.play(DrumSynth.Hit.KICK, 1.0)
	_kit.play(DrumSynth.Hit.SNARE, 1.0)
	assert_eq(_sounding_players().size(), 2, "Two independent voices")


func test_the_pool_reuses_players_rather_than_growing() -> void:
	var before := _kit.get_child_count()
	for i in 20:
		_kit.play(DrumSynth.Hit.KICK, 1.0)
	assert_eq(_kit.get_child_count(), before, "Same players reused, not new ones added")


func test_a_closed_hat_chokes_a_sounding_open_hat() -> void:
	_kit.play(DrumSynth.Hit.OPEN_HAT, 1.0)
	_kit.play(DrumSynth.Hit.CLOSED_HAT, 1.0)
	assert_eq(_sounding_players().size(), 1, "Closed hat stops the open one, not layered with it")


func test_a_snare_does_not_choke_an_open_hat() -> void:
	_kit.play(DrumSynth.Hit.OPEN_HAT, 1.0)
	_kit.play(DrumSynth.Hit.SNARE, 1.0)
	assert_eq(_sounding_players().size(), 2, "Only a closed hat chokes; both still sound")


func test_pick_player_prefers_an_idle_one() -> void:
	assert_eq(DrumKit.pick_player([true, false, true], [10, 20, 30]), 1, "The idle one")


func test_pick_player_steals_the_one_sounding_longest() -> void:
	assert_eq(DrumKit.pick_player([true, true, true], [30, 10, 20]), 1, "Oldest started")


func _sounding_players() -> Array:
	var found := []
	for player in _kit.get_children():
		if player.playing:
			found.append(player)
	return found
