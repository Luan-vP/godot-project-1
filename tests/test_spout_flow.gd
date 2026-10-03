extends GutTest
## Covers the spout's stepped pour: trigger depth and touch distance to steps
## of 2-16 droplets a bar, droplets falling on the bar's grid, and the level
## pouring from RT or a touch.

const LEVEL := preload("res://features/levels/spout/a_fluid/level_three_a.tscn")


func after_each() -> void:
	AudioManager.set_tempo(120.0, 4)


func test_the_steps_are_the_bar_subdivisions_asked_for() -> void:
	assert_eq(SpoutFlow.STEPS, [2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16] as Array[int])


func test_trigger_depth_climbs_the_steps() -> void:
	assert_eq(SpoutFlow.step_for_depth(0.0), -1, "Released: closed")
	assert_eq(SpoutFlow.step_for_depth(SpoutFlow.DEADZONE), -1, "Inside the deadzone")
	assert_eq(SpoutFlow.per_bar(SpoutFlow.step_for_depth(0.1)), 2, "A gentle press: 2 a bar")
	assert_eq(SpoutFlow.per_bar(SpoutFlow.step_for_depth(1.0)), 16, "Fully pressed: 16")
	var last := -1
	for i in 101:
		var step := SpoutFlow.step_for_depth(i / 100.0)
		assert_gte(step, last, "Never steps back as the trigger goes down")
		last = step


func test_every_step_is_reachable_by_trigger() -> void:
	var seen := {}
	for i in 1001:
		seen[SpoutFlow.step_for_depth(i / 1000.0)] = true
	for step in SpoutFlow.STEPS.size():
		assert_true(seen.has(step), "Step %d" % step)


func test_touch_distance_climbs_the_steps_and_always_pours() -> void:
	assert_eq(SpoutFlow.step_for_distance(10.0, 100.0, 700.0), 0, "By the nozzle: gentlest")
	assert_eq(SpoutFlow.step_for_distance(900.0, 100.0, 700.0), 11, "Past reach: fullest")
	assert_eq(SpoutFlow.step_for_distance(149.0, 100.0, 700.0), 0, "First band")
	assert_eq(SpoutFlow.step_for_distance(151.0, 100.0, 700.0), 1, "Second band")


func test_bands_match_the_distance_steps() -> void:
	for step in SpoutFlow.STEPS.size():
		var outer := SpoutFlow.band_outer(step, 100.0, 700.0)
		assert_eq(SpoutFlow.step_for_distance(outer - 1.0, 100.0, 700.0), step)


func test_droplets_fall_on_the_grid() -> void:
	# Four a bar: one each quarter.
	assert_eq(SpoutFlow.due(0.1, 0.2, 4), 0, "No quarter crossed")
	assert_eq(SpoutFlow.due(0.2, 0.3, 4), 1, "Crossed 1/4")
	assert_eq(SpoutFlow.due(0.95, 1.05, 4), 1, "Crossed the bar line")
	assert_eq(SpoutFlow.due(0.0, 0.01, 3), 0, "Starting on a beat is not crossing it")


func test_a_bar_at_each_step_drops_that_many() -> void:
	for count in SpoutFlow.STEPS:
		var dropped := 0
		# One bar, in small frames, starting just before its downbeat so the
		# downbeat itself counts.
		var t := -0.0001
		for i in 240:
			var next := t + 1.0 / 240.0
			dropped += SpoutFlow.due(t, next, count)
			t = next
		assert_eq(dropped, count, "%d a bar" % count)


func test_a_stall_never_dumps_a_burst() -> void:
	assert_eq(SpoutFlow.due(0.0, 2.0, 16), SpoutFlow.MAX_DUE)


func test_the_level_is_closed_until_rt_or_a_touch() -> void:
	var level: SpoutLevel = LEVEL.instantiate()
	add_child_autofree(level)
	var emitter: FluidEmitter = level.emitter
	emitter.reads_input = false
	assert_eq(emitter.current_step(), -1, "Nothing held: closed")
	emitter.set_depth(1.0)
	assert_eq(SpoutFlow.per_bar(emitter.current_step()), 16, "RT fully pressed")
	emitter.set_depth(0.0)
	level.pointer.press(level.spout.global_position + Vector2(0, emitter.flow_inner() - 5.0))
	assert_eq(SpoutFlow.per_bar(emitter.current_step()), 2, "A touch by the nozzle")
	level.pointer.move_to(level.spout.global_position + Vector2(0, emitter.flow_reach() + 10.0))
	assert_eq(SpoutFlow.per_bar(emitter.current_step()), 16, "A touch down at the pins")
	level.pointer.release()


func test_rt_is_not_a_key_move_on_the_spout_level() -> void:
	var level: SpoutLevel = LEVEL.instantiate()
	add_child_autofree(level)
	assert_false(level._key_shift.use_triggers)


func test_overlay_shows_while_touching_and_fades_after() -> void:
	var overlay := SpoutFlowOverlay.new()
	add_child_autofree(overlay)
	overlay.show_flow(4, true, Vector2(100, 300))
	overlay._process(1.0)
	assert_almost_eq(overlay.visibility(), 1.0, 0.001, "Fully shown while touching")
	overlay.show_flow(-1, false)
	overlay._process(0.1)
	assert_gt(overlay.visibility(), 0.0, "Fading, not gone at once")
	overlay._process(1.0)
	assert_eq(overlay.visibility(), 0.0, "Gone")


func test_overlay_is_faint_for_a_trigger() -> void:
	var overlay := SpoutFlowOverlay.new()
	add_child_autofree(overlay)
	overlay.show_flow(4, false)
	overlay._process(1.0)
	assert_almost_eq(overlay.visibility(), 0.35, 0.001)


func test_pouring_drops_droplets_on_the_grid_as_the_music_moves() -> void:
	var scripted := ScriptedMusicTime.new()
	AudioManager.set_music_time_source(scripted)
	var level: SpoutLevel = LEVEL.instantiate()
	add_child_autofree(level)
	var emitter: FluidEmitter = level.emitter
	emitter.reads_input = false
	emitter.set_depth(1.0)  # 16 a bar.
	var beats_per_bar := AudioManager.get_music_clock().beats_per_bar
	emitter._physics_process(1.0 / 60.0)  # Opens the spout; starts counting.
	var before := emitter.fired_count()
	# One bar, in sixty-fourths.
	for i in 64:
		scripted.advance(beats_per_bar / 64.0)
		emitter._physics_process(1.0 / 60.0)
	assert_eq(emitter.fired_count() - before, 16, "Sixteen droplets in a bar")
	emitter.set_depth(0.0)
	emitter._physics_process(1.0 / 60.0)
	var closed_at := emitter.fired_count()
	for i in 64:
		scripted.advance(beats_per_bar / 64.0)
		emitter._physics_process(1.0 / 60.0)
	assert_eq(emitter.fired_count(), closed_at, "Closed: nothing pours")
	AudioManager.set_music_time_source(WallClockMusicTime.new())
