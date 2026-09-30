extends GutTest
## Covers [MainLevel]: the entry point loads a real [Level] resource rather
## than hardcoding one, and wires the look to the medium.

const MAIN_SCENE := "res://features/levels/main/main_level.tscn"


func test_project_opens_on_the_main_level() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), MAIN_SCENE)


func test_level_resource_is_a_wrapping_level() -> void:
	var level := load(MainLevel.LEVEL_PATH) as Level
	assert_not_null(level, "The main level is a Level resource")
	assert_not_null(level.panorama_texture)
	assert_true(level.fluid_config.wrap_edges, "GazeFluidDriver needs a wrapping tank")


func test_builds_medium_floaters_and_gaze_driver() -> void:
	var main: MainLevel = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(main)
	assert_not_null(main.level, "Level loaded from the resource")
	assert_not_null(main.get_node_or_null("PanoramaLookCamera"))
	assert_not_null(main.get_node_or_null("GazeFluidDriver"))
	assert_not_null(main.find_child("Medium", true, false))
	assert_not_null(main.find_child("Floaters", true, false))
