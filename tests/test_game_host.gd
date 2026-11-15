extends GutTest
## Covers [GameHost], the game alone as every build but the Deck's plays it:
## it opens its start scene beside itself, reads the same launch options as the
## menu against the levels a player can reach, and keeps the debug overlay
## hidden until asked for. A stand-in scene keeps any GPU tank out of it.

const STAND_IN_PATH := "user://test_game_host_stand_in.tscn"

var _host: GameHost
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
	_host = GameHost.new()
	_host.start_path = STAND_IN_PATH
	_host.quits_after_probe = false
	get_tree().root.add_child(_host)


func after_each() -> void:
	_host.close_demo()
	get_tree().root.remove_child(_host)
	_host.free()
	get_tree().current_scene = _previous_scene


func test_it_opens_its_start_scene_as_the_current_scene() -> void:
	await get_tree().process_frame
	var scene := _host.get_demo()
	assert_not_null(scene, "Opened")
	assert_eq(scene.scene_file_path, STAND_IN_PATH)
	assert_eq(get_tree().current_scene, scene, "Current")
	assert_eq(scene.get_parent(), get_tree().root, "Beside the host")


func test_a_player_starts_on_the_carousel() -> void:
	assert_eq(GameHost.START_PATH, Splash.START_PATH)


func test_the_debug_overlay_starts_hidden() -> void:
	var meter := _host.get_node("LevelMeterOverlay") as LevelMeterOverlay
	assert_not_null(meter)
	assert_false(meter.visible, "Hidden until asked for")


func test_close_frees_the_scene() -> void:
	await get_tree().process_frame
	var scene := _host.get_demo()
	_host.close_demo()
	assert_null(_host.get_demo())
	assert_true(scene.is_queued_for_deletion())


func test_every_scene_it_can_reach_exists() -> void:
	for scene in GameHost.SCENES:
		assert_true(ResourceLoader.exists(scene["path"]), scene["name"])
		assert_false(
			DevTools.DECK_ONLY_PATHS.any(
				func(p: String) -> bool: return scene["path"].trim_prefix("res://").match(p)
			),
			"%s ships everywhere" % scene["name"]
		)


func test_launch_options_reach_the_levels_by_the_menus_names() -> void:
	var opened := LaunchOptions.parse(PackedStringArray(["--open=eye_band"]), GameHost.SCENES)
	assert_eq(opened["open"], "res://features/levels/carousel/solo/eye_band.tscn")
	var probed := LaunchOptions.parse(PackedStringArray(["--probe"]), GameHost.SCENES)
	assert_eq((probed["probe"] as Array).size(), GameHost.SCENES.size(), "All of them")
	var none := LaunchOptions.parse(PackedStringArray(["--open=synth"]), GameHost.SCENES)
	assert_false(none.has("open"), "Deck-only demos are not there")
