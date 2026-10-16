extends GutTest
## Covers how the fluid carousel changes level: never on its own by default,
## and on a swipe along the bottom of the screen. Two stand-in levels take the
## place of the real ones, as in test_fluid_carousel.gd.

const STAND_IN_NAMES: Array[String] = ["SwipeStandInA", "SwipeStandInB"]
const STAND_IN_DIR := "user://test_carousel_swipe_"

var _carousel: FluidCarousel


func before_all() -> void:
	for stand_in_name in STAND_IN_NAMES:
		var level := Node2D.new()
		level.name = stand_in_name
		var packed := PackedScene.new()
		packed.pack(level)
		ResourceSaver.save(packed, _stand_in_path(stand_in_name))
		level.free()


func after_all() -> void:
	for stand_in_name in STAND_IN_NAMES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_stand_in_path(stand_in_name)))


func before_each() -> void:
	_carousel = FluidCarousel.new()
	_carousel.slide_seconds = 0.0
	var paths: Array[String] = []
	for stand_in_name in STAND_IN_NAMES:
		paths.append(_stand_in_path(stand_in_name))
	_carousel.level_paths = paths
	add_child_autofree(_carousel)


func after_each() -> void:
	AudioManager.set_tempo(120.0, 4)


func test_it_waits_for_the_player_by_default() -> void:
	assert_eq(_carousel.dwell_seconds, 0.0, "No dwell: it never moves on by itself")
	var timer := _carousel.get_node("DwellTimer") as Timer
	assert_true(timer.is_stopped(), "No timer running")


func test_a_swipe_left_along_the_bottom_is_next_and_right_is_back() -> void:
	var screen := Vector2(540, 960)
	var bottom := screen.y * 0.95
	assert_eq(
		FluidCarousel.swipe_step(Vector2(400, bottom), Vector2(150, bottom), screen), 1, "Left"
	)
	assert_eq(
		FluidCarousel.swipe_step(Vector2(150, bottom), Vector2(400, bottom - 30), screen),
		-1,
		"Right, a little upwards"
	)


func test_only_a_long_sideways_drag_from_the_bottom_is_a_swipe() -> void:
	var screen := Vector2(540, 960)
	var bottom := screen.y * 0.95
	assert_eq(
		FluidCarousel.swipe_step(Vector2(400, 300), Vector2(100, 300), screen), 0, "Too high up"
	)
	assert_eq(
		FluidCarousel.swipe_step(Vector2(300, bottom), Vector2(280, bottom), screen), 0, "Too short"
	)
	assert_eq(
		FluidCarousel.swipe_step(Vector2(300, bottom), Vector2(200, bottom - 300), screen),
		0,
		"More up than across"
	)


func test_a_touch_swipe_along_the_bottom_changes_level() -> void:
	var screen := _carousel.get_viewport_rect().size
	var y := screen.y * 0.97
	_carousel._input(_touch(Vector2(screen.x * 0.8, y), true))
	_carousel._input(_touch(Vector2(screen.x * 0.2, y), false))
	assert_eq(_carousel.current_index(), 1, "Swiped left: the next level")
	_carousel._input(_touch(Vector2(screen.x * 0.2, y), true))
	_carousel._input(_touch(Vector2(screen.x * 0.8, y), false))
	assert_eq(_carousel.current_index(), 0, "Swiped right: back again")


func test_a_tap_or_a_drag_up_in_the_tank_does_not() -> void:
	var screen := _carousel.get_viewport_rect().size
	_carousel._input(_touch(Vector2(screen.x * 0.5, screen.y * 0.97), true))
	_carousel._input(_touch(Vector2(screen.x * 0.5, screen.y * 0.97), false))
	_carousel._input(_touch(Vector2(screen.x * 0.8, screen.y * 0.4), true))
	_carousel._input(_touch(Vector2(screen.x * 0.2, screen.y * 0.4), false))
	assert_eq(_carousel.current_index(), 0, "Still on the first level")


func test_a_mouse_made_up_from_a_touch_is_not_a_second_swipe() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.device = InputEvent.DEVICE_ID_EMULATION
	assert_true(FluidCarousel._press_of(click).is_empty(), "Emulated: ignored")
	click.device = 0
	assert_false(FluidCarousel._press_of(click).is_empty(), "A real mouse counts")


func _stand_in_path(stand_in_name: String) -> String:
	return "%s%s.tscn" % [STAND_IN_DIR, stand_in_name]


func _touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = at
	touch.pressed = pressed
	return touch
