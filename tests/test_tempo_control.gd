extends GutTest
## Covers [code]TempoControl[/code], the live tempo control every scene gets:
## which input moves the tempo by how much, the clamp, and that a nudge lands
## on [AudioManager].

const TempoControlScript := preload("res://autoload/TempoControl.gd")


func after_each() -> void:
	AudioManager.set_tempo(120.0, 4)


func _action(action: StringName, pressed: bool = true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func test_up_and_down_nudge_by_two_left_and_right_by_ten() -> void:
	assert_eq(TempoControlScript.step_for(_action(TempoControlScript.TEMPO_UP)), 2.0, "Up")
	assert_eq(TempoControlScript.step_for(_action(TempoControlScript.TEMPO_DOWN)), -2.0, "Down")
	assert_eq(TempoControlScript.step_for(_action(TempoControlScript.TEMPO_UP_BIG)), 10.0, "Right")
	assert_eq(
		TempoControlScript.step_for(_action(TempoControlScript.TEMPO_DOWN_BIG)), -10.0, "Left"
	)


func test_releases_and_other_actions_do_nothing() -> void:
	assert_eq(TempoControlScript.step_for(_action(TempoControlScript.TEMPO_UP, false)), 0.0)
	assert_eq(TempoControlScript.step_for(_action(&"ui_accept")), 0.0)


func test_the_arrow_keys_are_bound() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_RIGHT
	key.pressed = true
	assert_eq(TempoControlScript.step_for(key), 10.0, "Right arrow jumps up ten")


func test_tempo_is_clamped() -> void:
	assert_eq(TempoControlScript.next_tempo(34.0, -10.0), TempoControlScript.MIN_BPM, "Floor")
	assert_eq(TempoControlScript.next_tempo(176.0, 10.0), TempoControlScript.MAX_BPM, "Ceiling")
	assert_eq(TempoControlScript.next_tempo(84.0, 2.0), 86.0, "In range")


func test_a_nudge_moves_the_music_tempo() -> void:
	AudioManager.set_tempo(84.0, 4)
	var landed: float = TempoControl.nudge(-10.0)
	assert_eq(landed, 74.0, "Landed")
	assert_eq(AudioManager.get_tempo(), 74.0, "AudioManager follows")
	assert_eq(AudioManager.get_music_clock().beats_per_bar, 4, "Bar length untouched")
