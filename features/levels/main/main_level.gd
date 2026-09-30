class_name MainLevel
extends PanoramaLevel
## The level the game opens on: the panorama, a clear medium over it, floaters
## drifting in that, and looking around swishing the medium.
##
## Nothing is hardcoded here. The level is [constant LEVEL_PATH], a [Level]
## resource, and the only thing this adds to [PanoramaLevel] is the
## [GazeFluidDriver] that joins the look to the medium. It has no goal: #9
## decides what the game is for.
##
## Backspace (or Select on a gamepad) leaves for the level select, which is
## also where the secret level is reached.

const LEVEL_PATH := "res://resources/main_level.tres"
const LEVEL_SELECT_SCENE := "res://features/ui/level_select/level_select.tscn"


func _ready() -> void:
	# This is run/main_scene, so it is also where a Deck build launches — see
	# LevelSelect._wants_demo_menu for the flags that must still reach DemoMenu.
	if LevelSelect._wants_demo_menu():
		get_tree().change_scene_to_file.call_deferred(LevelSelect.DEMO_MENU_SCENE)
		return
	level = load(LEVEL_PATH) as Level
	super._ready()
	var driver := GazeFluidDriver.new()
	driver.name = "GazeFluidDriver"
	add_child(driver)


func _unhandled_input(event: InputEvent) -> void:
	if LevelSelect.is_back(event):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)
