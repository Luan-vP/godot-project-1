class_name GameHost
extends Node
## The game alone, as every build but the Deck's plays it: what the splash
## hands over to when there is no demo menu ([method DevTools.enabled]).
##
## It opens the fluid carousel and stays beside it under the root, out of
## sight, holding the debug overlay ([LevelMeterOverlay], hidden until asked
## for). The same launch options as the menu reach the levels a player can
## play ([constant SCENES]): [code]--open=[/code] and [code]--probe[/code], so a
## phone nobody is holding can still be checked from the command line.

## Emitted after a scene has been instanced and made the current scene.
signal scene_opened(path: String)

## What a player lands on.
const START_PATH := "res://features/levels/carousel/fluid_carousel.tscn"

## The scenes the launch options can reach: the carousel, and each of its
## levels on its own. Names match the menu's, so the same option works on both.
const SCENES: Array[Dictionary] = [
	{"name": "Eye band", "path": "res://features/levels/carousel/solo/eye_band.tscn"},
	{"name": "Spout", "path": "res://features/levels/carousel/solo/spout.tscn"},
	{"name": "Birds", "path": "res://features/levels/carousel/solo/birds.tscn"},
	{"name": "Waterboatmen", "path": "res://features/levels/carousel/solo/waterboatmen.tscn"},
	{"name": "Fluid carousel", "path": START_PATH},
]

## What it opens when no launch option says otherwise. Tests swap in
## something lighter than a tank.
var start_path := START_PATH
## Whether finishing a probe quits, as it must on a device nobody is holding.
## Tests turn it off.
var quits_after_probe := true

var _scene: Node


func _ready() -> void:
	var args := LaunchOptions.command_line()
	var meter := LevelMeterOverlay.new()
	meter.name = "LevelMeterOverlay"
	meter.visible = args.has("--meter")
	add_child(meter)
	_start.call_deferred(LaunchOptions.parse(args, SCENES))


## The running scene, or null between scenes.
func get_demo() -> Node:
	return _scene if is_instance_valid(_scene) else null


## Instance the scene at [param path] and hand it the screen.
func open_demo(path: String) -> void:
	close_demo()
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("GameHost could not load %s" % path)
		return
	_scene = packed.instantiate()
	var tree := get_tree()
	AudioManager.get_level_meter().set_note("demo", path.get_file().get_basename())
	tree.root.add_child(_scene)
	tree.current_scene = _scene
	scene_opened.emit(path)


## Free the running scene, if any.
func close_demo() -> void:
	if get_demo() == null:
		_scene = null
		return
	var tree := get_tree()
	tree.root.remove_child(_scene)
	_scene.queue_free()
	_scene = null
	AudioManager.get_level_meter().set_note("demo", "")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var audio := tree.root.get_node_or_null("AudioManager")
	if audio != null:
		audio.stop_loops()


func _start(options: Dictionary) -> void:
	if options.has("probe"):
		var which: Array[Dictionary] = options["probe"]
		var probe := FrameProbe.new(self, which)
		if quits_after_probe:
			probe.finished.connect(func(_report): get_tree().quit())
		add_child(probe)
	else:
		open_demo(options.get("open", start_path))
