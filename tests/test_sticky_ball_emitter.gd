extends GutTest
## Covers version C: balls fired on its own steps (8-20 a bar) at twice B's
## speed, one ball sticking to a pin, stuck pins playing together on the next
## sixteenth and popping until the next bar.

const Hosting := preload("res://tests/hosting.gd")

const _TEST_SETTINGS_PATH := "user://test_sticky_ball_emitter_settings.cfg"
const LEVEL_C := preload("res://features/levels/spout/c_sticky/level_three_c.tscn")


func before_each() -> void:
	SaveManager.settings_path = _TEST_SETTINGS_PATH
	SaveManager.reload()


func after_each() -> void:
	if FileAccess.file_exists(_TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(_TEST_SETTINGS_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()
	AudioManager.set_tempo(120.0, 4)
	AudioManager.set_music_time_source(WallClockMusicTime.new())


## The level, with the music held still so its own physics frames never move
## the clock under a test: the tests move it with [method tick_clock].
func _level() -> SpoutLevel:
	AudioManager.set_music_time_source(ScriptedMusicTime.new())
	var level: SpoutLevel = LEVEL_C.instantiate()
	Hosting.host(self, level)
	level.emitter.reads_input = false
	return level


func test_version_c_fires_eight_to_twenty_a_bar() -> void:
	var level := _level()
	var emitter: StickyBallEmitter = level.emitter
	assert_eq(emitter.flow_steps(), [8, 12, 16, 20] as Array[int])
	emitter.set_depth(SpoutFlow.DEADZONE + 0.01)
	emitter.set_step(emitter.current_step())
	assert_eq(emitter.flow_per_bar(), 8, "A gentle press: 8 a bar")
	emitter.set_depth(1.0)
	emitter.set_step(emitter.current_step())
	assert_eq(emitter.flow_per_bar(), 20, "Fully pressed: 20")
	assert_eq(emitter.overlay.steps, [8, 12, 16, 20] as Array[int], "The rings show C's steps")


func test_balls_leave_at_twice_version_bs_speed() -> void:
	var level := _level()
	var emitter: StickyBallEmitter = level.emitter
	var ball := emitter.fire()
	assert_almost_eq(ball.linear_velocity.length(), BallEmitter.MUZZLE_SPEED * 2.0, 0.01)


func test_the_other_versions_keep_the_shared_steps() -> void:
	assert_eq(SpoutFlow.per_bar(4), 24)
	assert_eq(SpoutFlow.per_bar(3, StickyBallEmitter.STEPS), 20)
	assert_eq(SpoutFlow.per_bar(4, StickyBallEmitter.STEPS), 0, "No fifth step in C")


func test_the_clock_runs_ahead_by_the_lookahead_like_the_bands() -> void:
	var scripted := ScriptedMusicTime.new()
	AudioManager.set_music_time_source(scripted)
	scripted.start()
	scripted.set_beats(2.0)
	var clock := AudioManager.get_music_clock()
	assert_almost_eq(StickyBallEmitter.heard_bars(), 2.0 / clock.beats_per_bar, 0.0001)
	scripted.lookahead = clock.seconds_per_beat()
	assert_almost_eq(
		StickyBallEmitter.heard_bars(), 3.0 / clock.beats_per_bar, 0.0001, "A beat ahead"
	)


func test_only_one_ball_sticks_to_a_pin() -> void:
	var level := _level()
	var emitter: StickyBallEmitter = level.emitter
	var first := emitter.fire()
	var second := emitter.fire()
	assert_true(emitter.stick(first, 3, 300.0), "A free pin takes the ball")
	assert_false(emitter.stick(second, 3, 300.0), "A pin holds one ball")
	assert_true(emitter.stick(second, 5, 300.0), "It can stick elsewhere")
	assert_false(emitter.stick(first, 7, 300.0), "A stuck ball stays where it is")
	assert_eq(emitter.stuck_count(), 2)
	assert_eq(emitter.ball_on(3), first)
	assert_true(first.is_stuck())


func test_a_stuck_pin_waits_for_the_next_sixteenth_then_pops() -> void:
	var level := _level()
	var emitter: StickyBallEmitter = level.emitter
	var heard: Array[int] = []
	level.pins.pin_hit.connect(func(pin: int, _note: int, _strength: float): heard.append(pin))
	var sixteenth := 1.0 / StickyBallEmitter.sixteenths_per_bar()
	emitter.tick_clock(0.01)
	emitter.stick(emitter.fire(), 2, 400.0)
	assert_eq(heard.size(), 0, "Sticking does not sound")
	emitter.tick_clock(sixteenth - 0.001)
	assert_eq(heard.size(), 0, "Not before the sixteenth")
	emitter.tick_clock(sixteenth + 0.001)
	assert_eq(heard, [2] as Array[int], "On the sixteenth")
	assert_true(level.pins.is_popped(2), "Then it pops")
	assert_eq(emitter.stuck_count(), 0)
	assert_eq(emitter.in_play(), 0, "Its ball goes with it")
	var where := level.pins.to_global(level.pins.pin_position(2))
	assert_ne(level.pins.pin_at(where), 2, "Not found where it was")
	assert_false(level.pins.hit(2, 1.0), "A popped pin is silent")


func test_pins_stuck_together_play_together_on_the_next_sixteenth() -> void:
	var level := _level()
	var emitter: StickyBallEmitter = level.emitter
	var heard: Array[int] = []
	level.pins.pin_hit.connect(func(pin: int, _note: int, _strength: float): heard.append(pin))
	var sixteenth := 1.0 / StickyBallEmitter.sixteenths_per_bar()
	emitter.tick_clock(0.01)
	emitter.stick(emitter.fire(), 6, 400.0)
	emitter.stick(emitter.fire(), 1, 400.0)
	emitter.tick_clock(sixteenth + 0.001)
	assert_eq(heard, [6, 1] as Array[int], "Both on the one sixteenth")
	assert_true(level.pins.is_popped(6) and level.pins.is_popped(1), "Both pop")
	emitter.tick_clock(2.0 * sixteenth + 0.001)
	assert_eq(heard.size(), 2, "Nothing left for the next")


func test_popped_pins_come_back_at_the_next_bar() -> void:
	var level := _level()
	var emitter: StickyBallEmitter = level.emitter
	emitter.tick_clock(0.5)
	emitter.stick(emitter.fire(), 4, 400.0)
	emitter.tick_clock(0.5 + 1.0 / StickyBallEmitter.sixteenths_per_bar())
	assert_true(level.pins.is_popped(4))
	emitter.tick_clock(0.99)
	assert_true(level.pins.is_popped(4), "Gone for the rest of the bar")
	assert_false(emitter.stick(emitter.fire(), 4, 400.0), "Nothing sticks to a popped pin")
	emitter.tick_clock(1.01)
	assert_false(level.pins.is_popped(4), "Back on the bar line")
	assert_eq(level.pins.popped_count(), 0)


func test_a_pin_played_on_the_downbeat_stays_gone_that_bar() -> void:
	var level := _level()
	var emitter: StickyBallEmitter = level.emitter
	emitter.tick_clock(0.97)
	emitter.stick(emitter.fire(), 0, 400.0)
	emitter.tick_clock(1.001)
	assert_true(level.pins.is_popped(0), "Played on the downbeat, then popped")
	emitter.tick_clock(1.9)
	assert_true(level.pins.is_popped(0))
	emitter.tick_clock(2.001)
	assert_false(level.pins.is_popped(0))


func test_retiring_a_stuck_ball_frees_its_pin() -> void:
	var level := _level()
	var emitter: StickyBallEmitter = level.emitter
	var ball := emitter.fire()
	emitter.stick(ball, 3, 400.0)
	emitter._retire(ball)
	assert_eq(emitter.stuck_count(), 0)
	assert_eq(emitter.play_waiting(), [] as Array[int], "Nothing left waiting")
	assert_true(emitter.stick(emitter.fire(), 3, 400.0), "The pin is free again")


func test_a_ball_settles_frozen_against_its_pin() -> void:
	var level := _level()
	var emitter: StickyBallEmitter = level.emitter
	var ball := emitter.fire()
	var centre := level.pins.to_global(level.pins.pin_position(3))
	ball.global_position = centre + Vector2(0, -30)
	emitter.stick(ball, 3, 400.0)
	await wait_physics_frames(2)
	assert_true(ball.freeze, "Frozen in place")
	var touching := level.pins.pin_radius + SpoutBall.RADIUS
	assert_almost_eq(ball.global_position.distance_to(centre), touching, 0.5)
