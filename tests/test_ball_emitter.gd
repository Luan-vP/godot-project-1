extends GutTest
## Covers version B: hit strength from impact speed, a haptic tick per ball
## fired, the capped pool, and firing in steps of the bar like the fluid
## spout ([SpoutFlow]; the steps themselves are in test_spout_flow.gd).

const Hosting := preload("res://tests/hosting.gd")

const _TEST_SETTINGS_PATH := "user://test_ball_emitter_settings.cfg"
const LEVEL_B := preload("res://features/levels/spout/b_balls/level_three_b.tscn")


func before_each() -> void:
	SaveManager.settings_path = _TEST_SETTINGS_PATH
	SaveManager.reload()


func after_each() -> void:
	if FileAccess.file_exists(_TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(_TEST_SETTINGS_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()
	AudioManager.set_tempo(120.0, 4)


func test_closing_speed_is_the_part_along_the_line_to_the_pin() -> void:
	var straight := SpoutBall.closing_speed(Vector2(0, 400), Vector2(0, -10), Vector2.ZERO)
	assert_almost_eq(straight, 400.0, 0.001, "Dropped straight on")
	var glancing := SpoutBall.closing_speed(Vector2(400, 0), Vector2(0, -10), Vector2.ZERO)
	assert_almost_eq(glancing, 0.0, 0.001, "Rolling across the top")
	var leaving := SpoutBall.closing_speed(Vector2(0, -400), Vector2(0, -10), Vector2.ZERO)
	assert_eq(leaving, 0.0, "Moving away")


func test_strength_follows_impact_speed() -> void:
	assert_eq(BallEmitter.strength_for(20.0), -1.0, "A roll stays quiet")
	assert_lt(BallEmitter.strength_for(150.0), BallEmitter.strength_for(500.0))
	assert_eq(BallEmitter.strength_for(5000.0), 1.0, "Capped")


func test_every_ball_fired_ticks_the_haptics() -> void:
	var level: SpoutLevel = LEVEL_B.instantiate()
	Hosting.host(self, level)
	var output := NullHapticsOutput.new()
	output.available = true
	var outputs: Array[HapticsOutput] = [output]
	level.haptics.set_outputs(outputs)
	level.haptics.get_limiter().min_interval = 0.0
	var emitter: BallEmitter = level.emitter
	emitter.reads_input = false
	emitter.fire()
	emitter.fire()
	emitter.fire()
	assert_eq(output.pulses.size(), 3, "One tick per ball")
	assert_eq(emitter.in_play(), 3)


func test_version_b_takes_the_triggers_from_key_moves() -> void:
	var level: SpoutLevel = LEVEL_B.instantiate()
	Hosting.host(self, level)
	assert_false(level._key_shift.use_triggers, "RT fires, it does not move the key")
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	assert_eq(level._key_shift.step_for(rt), 0)


func test_the_pool_is_capped() -> void:
	var level: SpoutLevel = LEVEL_B.instantiate()
	Hosting.host(self, level)
	var emitter: BallEmitter = level.emitter
	emitter.reads_input = false
	for i in BallEmitter.MAX_BALLS + 5:
		emitter.fire()
	assert_eq(emitter.in_play(), BallEmitter.MAX_BALLS)


func test_a_touch_fires_in_version_b() -> void:
	var level: SpoutLevel = LEVEL_B.instantiate()
	Hosting.host(self, level)
	var emitter: BallEmitter = level.emitter
	emitter.reads_input = false
	assert_eq(emitter.current_step(), -1, "Nothing touching: closed")
	level.pointer.press(level.spout.global_position + Vector2(0, 300))
	assert_gte(emitter.current_step(), 0, "A touch fires")
	level.pointer.release()


func test_balls_fire_on_the_grid_as_the_music_moves() -> void:
	var scripted := ScriptedMusicTime.new()
	AudioManager.set_music_time_source(scripted)
	var level: SpoutLevel = LEVEL_B.instantiate()
	Hosting.host(self, level)
	var emitter: BallEmitter = level.emitter
	emitter.reads_input = false
	emitter.set_depth(SpoutFlow.DEADZONE + 0.01)  # The gentlest step: 2 a bar.
	assert_eq(SpoutFlow.per_bar(emitter.current_step()), 2)
	emitter._physics_process(1.0 / 60.0)  # Opens; starts counting.
	var before := emitter.fired_count()
	var beats_per_bar := AudioManager.get_music_clock().beats_per_bar
	for i in 64:
		scripted.advance(beats_per_bar / 64.0)
		emitter._physics_process(1.0 / 60.0)
	assert_eq(emitter.fired_count() - before, 2, "Two balls in a bar")
	AudioManager.set_music_time_source(WallClockMusicTime.new())
