extends GutTest
## Covers [DrumKit]: velocity gates whether a hit plays, voices round-robin
## through the pool the way [AudioManager]'s SFX pool does, and a closed hat
## chokes a sounding open hat rather than letting both ring.
##
## What this cannot cover is the thing #75 is actually about: how tight a
## live hit lands against the grid. That is a manual_verification question —
## see core/audio/README.md and `scripts/run.sh band`.

var _kit: DrumKit


func before_each() -> void:
	_kit = DrumKit.new()
	_kit.polyphony = 4
	add_child_autofree(_kit)


func test_zero_or_negative_velocity_plays_nothing() -> void:
	_kit.hit(DrumSynth.Hit.KICK, 0.0)
	_kit.hit(DrumSynth.Hit.KICK, -1.0)
	assert_eq(_kit.sounding_count(), 0)


func test_a_hit_plays_one_voice() -> void:
	_kit.hit(DrumSynth.Hit.KICK, 0.8)
	assert_eq(_kit.sounding_count(), 1)


func test_velocity_is_linear_and_reaches_the_player_in_decibels() -> void:
	_kit.hit(DrumSynth.Hit.KICK, 0.5, -6.0)
	var player := _kit.get_child(0) as AudioStreamPlayer
	assert_almost_eq(player.volume_db, linear_to_db(0.5) - 6.0, 0.001, "Velocity plus part level")


func test_voices_fill_the_pool_round_robin() -> void:
	for i in 4:
		_kit.hit(DrumSynth.Hit.SNARE, 0.8)
	assert_eq(_kit.sounding_count(), 4, "Every voice in a 4-voice pool now sounding")


func test_a_hit_past_the_pool_size_steals_rather_than_growing_it() -> void:
	for i in 5:
		_kit.hit(DrumSynth.Hit.SNARE, 0.8)
	assert_eq(_kit.sounding_count(), 4, "Still capped at the pool size")


func test_a_closed_hat_chokes_a_sounding_open_hat() -> void:
	_kit.hit(DrumSynth.Hit.OPEN_HAT, 0.9)
	assert_eq(_kit.sounding_count(), 1)
	_kit.hit(DrumSynth.Hit.CLOSED_HAT, 0.9)
	# The choke is a tween, not instant — poll rather than a fixed wait, so
	# this does not depend on how many frames land within
	# CHOKE_FADE_SECONDS on whatever machine runs it.
	var choked := func(): return _kit.sounding_count() == 1
	var arrived: bool = await wait_until(choked, 1.0)
	assert_true(arrived, "The open hat stopped; the closed hat is still sounding")


func test_a_closed_hat_with_nothing_to_choke_does_not_error() -> void:
	_kit.hit(DrumSynth.Hit.CLOSED_HAT, 0.9)
	assert_eq(_kit.sounding_count(), 1)


func test_an_open_hat_stolen_before_it_is_choked_is_not_choked_again() -> void:
	# Pool size 4: three unrelated hits fill every other voice, so the fourth
	# hit — a plain steal, round-robin back to voice 0 — takes the open hat's
	# voice before any closed hat asked for it.
	_kit.hit(DrumSynth.Hit.OPEN_HAT, 0.9)  # Voice 0.
	for i in 3:
		_kit.hit(DrumSynth.Hit.SNARE, 0.8)  # Voices 1, 2, 3.
	_kit.hit(DrumSynth.Hit.SNARE, 0.8)  # Voice 0 again: steals the open hat.
	_kit.hit(DrumSynth.Hit.CLOSED_HAT, 0.9)  # Nothing left to choke; must not misfire.
	await wait_seconds(StepPattern.CHOKE_FADE_SECONDS * 4.0)
	assert_eq(_kit.sounding_count(), 4, "Pool stays full; the stale choke target caused no harm")


func test_the_same_hit_and_sample_rate_share_one_wav() -> void:
	_kit.hit(DrumSynth.Hit.KICK, 0.8)
	var first: AudioStreamWAV = (_kit.get_child(0) as AudioStreamPlayer).stream
	_kit.hit(DrumSynth.Hit.KICK, 0.8)
	var second: AudioStreamWAV = (_kit.get_child(1) as AudioStreamPlayer).stream
	assert_same(first, second, "Cached, not rebuilt per hit")
