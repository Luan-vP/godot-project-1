extends GutTest
## Covers [LevelSelect]: every discovered [Level] resource is real and
## uniquely named, cards match what was discovered, back input, the secret
## gesture and its reveal, and that opening and closing a real level actually
## tears its fluid tank down rather than just losing the reference to it.

const SECRET_STAND_IN_PATH := "user://test_level_select_secret_stand_in.tscn"

var _menu: LevelSelect
var _previous_scene: Node


func before_all() -> void:
	var stand_in := Node2D.new()
	stand_in.name = "SecretStandIn"
	var packed := PackedScene.new()
	packed.pack(stand_in)
	ResourceSaver.save(packed, SECRET_STAND_IN_PATH)
	stand_in.free()


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SECRET_STAND_IN_PATH))


func before_each() -> void:
	_previous_scene = get_tree().current_scene
	_menu = LevelSelect.new()
	# A stand-in scene path, the same reason test_demo_menu.gd uses one: so no
	# real level (or GPU tank) has to start for tests that don't need it.
	_menu.secret_scene_path = SECRET_STAND_IN_PATH
	# Scenes the menu opens sit beside it under the root, and the tree only
	# accepts a direct child of the root as the current scene.
	get_tree().root.add_child(_menu)


func after_each() -> void:
	_menu.close_level()
	get_tree().root.remove_child(_menu)
	_menu.free()
	get_tree().current_scene = _previous_scene


func test_discovers_the_two_shipped_level_resources() -> void:
	var names: Array[String] = []
	for level in LevelSelect.discover_levels():
		assert_true(level is Level, "Only Level resources are discovered")
		names.append(level.display_name)
	assert_true(names.has("Overcast Sky"), "Overcast Sky is discovered")
	assert_true(names.has("Dim Interior"), "Dim Interior is discovered")


func test_discovered_level_names_are_unique() -> void:
	var seen := {}
	for level in LevelSelect.discover_levels():
		assert_false(seen.has(level.display_name), "Duplicate name %s" % level.display_name)
		seen[level.display_name] = true


func test_there_is_a_card_per_discovered_level_and_no_secret_yet() -> void:
	var buttons := _menu.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), LevelSelect.discover_levels().size(), "One card per discovered level")


func test_backspace_and_select_go_back_but_other_input_does_not() -> void:
	assert_true(LevelSelect._is_back(_key(KEY_BACKSPACE, true, false)), "Backspace")
	assert_false(LevelSelect._is_back(_key(KEY_BACKSPACE, true, true)), "Held-key repeat")
	assert_false(LevelSelect._is_back(_key(KEY_BACKSPACE, false, false)), "Release")
	assert_false(LevelSelect._is_back(_key(KEY_ESCAPE, true, false)), "Escape is not back")
	var select := InputEventJoypadButton.new()
	select.button_index = JOY_BUTTON_BACK
	select.pressed = true
	assert_true(LevelSelect._is_back(select), "Gamepad Select")


func test_secret_gesture_is_shift_or_gamepad_y_only() -> void:
	assert_true(LevelSelect._is_secret_gesture(_key(KEY_SHIFT, true, false)), "Shift")
	assert_false(LevelSelect._is_secret_gesture(_key(KEY_SHIFT, true, true)), "Held-key repeat")
	assert_false(LevelSelect._is_secret_gesture(_key(KEY_SHIFT, false, false)), "Release")
	assert_false(LevelSelect._is_secret_gesture(_key(KEY_CTRL, true, false)), "Ctrl is not it")
	var y_button := InputEventJoypadButton.new()
	y_button.button_index = JOY_BUTTON_Y
	y_button.pressed = true
	assert_true(LevelSelect._is_secret_gesture(y_button), "Gamepad Y")


func test_secret_gesture_reveals_an_extra_card() -> void:
	var before := _menu.find_children("*", "Button", true, false).size()
	_menu._input(_key(KEY_SHIFT, true, false))
	var after := _menu.find_children("*", "Button", true, false).size()
	assert_eq(after, before + 1, "One more card than before")
	assert_true(_has_entry_named(_menu.get_entries(), LevelSelect.SECRET_LEVEL_NAME), "Eyes is listed")


func test_secret_gesture_does_nothing_while_a_level_is_open() -> void:
	_menu.open_entry({"name": "Stand-in", "level": null, "scene_path": SECRET_STAND_IN_PATH})
	_menu._input(_key(KEY_SHIFT, true, false))
	assert_false(
		_has_entry_named(_menu.get_entries(), LevelSelect.SECRET_LEVEL_NAME),
		"The gesture is only read at the menu"
	)


func test_opening_an_entry_hands_it_the_screen() -> void:
	_menu.open_entry({"name": "Stand-in", "level": null, "scene_path": SECRET_STAND_IN_PATH})
	assert_true(_menu.is_level_open(), "A level is running")
	assert_eq(get_tree().current_scene, _menu.get_level(), "It is the current scene")
	assert_eq(_menu.get_level().get_parent(), get_tree().root, "Beside the menu, not inside it")
	assert_false(_menu.visible, "The menu hides")


func test_closing_frees_the_level_and_shows_the_menu() -> void:
	_menu.open_entry({"name": "Stand-in", "level": null, "scene_path": SECRET_STAND_IN_PATH})
	var level := _menu.get_level()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_menu.close_level()
	assert_false(_menu.is_level_open(), "Nothing running")
	assert_false(level.is_inside_tree(), "The level left the tree")
	assert_eq(get_tree().current_scene, _menu, "The menu is current again")
	assert_true(_menu.visible, "The menu shows")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "The cursor is given back")


func test_opening_a_second_entry_closes_the_first() -> void:
	_menu.open_entry({"name": "A", "level": null, "scene_path": SECRET_STAND_IN_PATH})
	var first := _menu.get_level()
	_menu.open_entry({"name": "B", "level": null, "scene_path": SECRET_STAND_IN_PATH})
	assert_false(first.is_inside_tree(), "The first level is gone")
	assert_true(_menu.is_level_open(), "The second is running")


func test_opening_a_discovered_level_tears_down_its_fluid_tank_on_close() -> void:
	var levels := LevelSelect.discover_levels()
	assert_gt(levels.size(), 0, "Something to test against")
	var entry := {
		"name": "Real",
		"level": levels[0],
		"scene_path": LevelSelect.PANORAMA_LEVEL_SCENE,
	}
	_menu.open_entry(entry)
	var tanks := _menu.get_level().find_children("*", "FluidSimulation", true, false)
	assert_eq(tanks.size(), 1, "PanoramaLevel builds one tank")
	var tank := tanks[0]
	_menu.close_level()
	assert_false(tank.is_inside_tree(), "The tank left the tree with the rest of the level")


static func _has_entry_named(entries: Array[Dictionary], entry_name: String) -> bool:
	for entry in entries:
		if entry["name"] == entry_name:
			return true
	return false


static func _key(code: Key, pressed: bool, echo: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event
