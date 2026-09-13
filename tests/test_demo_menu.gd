extends GutTest
## Covers [DemoMenu]: that every entry points at a real scene, which input
## counts as "back", and the open/close round trip with a stand-in demo so no
## real level (or GPU tank) has to start.

const STAND_IN_PATH := "user://test_demo_menu_stand_in.tscn"

var _menu: DemoMenu
var _previous_scene: Node


func before_all() -> void:
	var stand_in := Node2D.new()
	stand_in.name = "StandIn"
	var packed := PackedScene.new()
	packed.pack(stand_in)
	ResourceSaver.save(packed, STAND_IN_PATH)
	stand_in.free()


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STAND_IN_PATH))


func before_each() -> void:
	_previous_scene = get_tree().current_scene
	_menu = DemoMenu.new()
	# Scenes the menu opens sit beside it under the root, and the tree only
	# accepts a direct child of the root as the current scene.
	get_tree().root.add_child(_menu)


func after_each() -> void:
	_menu.close_demo()
	get_tree().root.remove_child(_menu)
	_menu.free()
	get_tree().current_scene = _previous_scene


func test_every_demo_points_at_a_scene_that_exists() -> void:
	for demo in DemoMenu.DEMOS:
		assert_true(ResourceLoader.exists(demo["path"]), "%s: %s" % [demo["name"], demo["path"]])


func test_demo_names_are_unique() -> void:
	var seen := {}
	for demo in DemoMenu.DEMOS:
		assert_false(seen.has(demo["name"]), "Duplicate name %s" % demo["name"])
		seen[demo["name"]] = true


func test_there_is_a_button_per_demo() -> void:
	var buttons := _menu.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), DemoMenu.DEMOS.size(), "One card per demo")


func test_backspace_and_select_go_back_but_other_input_does_not() -> void:
	assert_true(DemoMenu._is_back(_key(KEY_BACKSPACE, true, false)), "Backspace")
	assert_false(DemoMenu._is_back(_key(KEY_BACKSPACE, true, true)), "Held-key repeat")
	assert_false(DemoMenu._is_back(_key(KEY_BACKSPACE, false, false)), "Release")
	assert_false(DemoMenu._is_back(_key(KEY_ESCAPE, true, false)), "Escape frees the cursor")
	var select := InputEventJoypadButton.new()
	select.button_index = JOY_BUTTON_BACK
	select.pressed = true
	assert_true(DemoMenu._is_back(select), "Gamepad Select")


func test_opening_a_demo_hands_it_the_screen() -> void:
	_menu.open_demo(STAND_IN_PATH)
	assert_true(_menu.is_demo_open(), "A demo is running")
	assert_eq(get_tree().current_scene, _menu.get_demo(), "It is the current scene")
	assert_eq(_menu.get_demo().get_parent(), get_tree().root, "Beside the menu, not inside it")
	assert_false(_menu.visible, "The menu hides")


func test_closing_frees_the_demo_and_shows_the_menu() -> void:
	_menu.open_demo(STAND_IN_PATH)
	var demo := _menu.get_demo()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_menu.close_demo()
	assert_false(_menu.is_demo_open(), "Nothing running")
	assert_false(demo.is_inside_tree(), "The demo left the tree")
	assert_eq(get_tree().current_scene, _menu, "The menu is current again")
	assert_true(_menu.visible, "The menu shows")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "The cursor is given back")


func test_opening_a_second_demo_closes_the_first() -> void:
	_menu.open_demo(STAND_IN_PATH)
	var first := _menu.get_demo()
	_menu.open_demo(STAND_IN_PATH)
	assert_false(first.is_inside_tree(), "The first demo is gone")
	assert_true(_menu.is_demo_open(), "The second is running")


static func _key(code: Key, pressed: bool, echo: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event
