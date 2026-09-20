class_name DemoMenu
extends Control
## Click into any level or demo, and come back out with Backspace.
##
## The menu never leaves the tree. A picked demo is instanced beside it under
## the root and made the current scene, and the menu hides; going back frees
## the demo and shows the menu again. Staying alive is what lets it hear the
## back key while a demo runs, without an autoload for the job.
##
## Demos are written to run on their own, so going back also undoes the two
## things that outlive them: a captured mouse, and music loops still playing on
## [code]AudioManager[/code].
##
## A development tool, and [code]run/main_scene[/code] only until a main level
## exists. It lists the secret eye level, which is meant to be reached with
## Shift once there is a game to hide it behind — see that level's README.

## Emitted after a demo has been instanced and made the current scene.
signal demo_opened(path: String)

## Emitted after the running demo has been freed and the menu is showing.
signal demo_closed

## Every level and demo, in the order shown. Keep in step with scripts/run.sh.
const DEMOS: Array[Dictionary] = [
	{
		"name": "Eyes",
		"path": "res://features/levels/secret_eyes/fluid_demo.tscn",
		"blurb": "Secret level: the eye tank. Drag to stir and paint, arrows tilt, Space jogs.",
	},
	{
		"name": "Eye band",
		"path": "res://features/levels/secret_eyes/eye_band_demo.tscn",
		"blurb":
		"Each eye plays a part while it stays off the walls. Tilt or stir to thin the music.",
	},
	{
		"name": "Vitreous",
		"path": "res://features/levels/vitreous/vitreous_tank.tscn",
		"blurb": "Out-of-focus floaters in a coasting gel. Drag to push, +/- floaters.",
	},
	{
		"name": "Overcast Sky",
		"path": "res://features/levels/panorama/overcast_sky.tscn",
		"blurb":
		"Bright panorama level, floaters unmissable. Mouse/stick to look, Esc frees cursor.",
	},
	{
		"name": "Dim Interior",
		"path": "res://features/levels/panorama/dim_interior.tscn",
		"blurb":
		"Dim panorama level, floaters barely there. Mouse/stick to look, Esc frees cursor.",
	},
	{
		"name": "Refraction",
		"path": "res://features/fluid/refraction_demo.tscn",
		"blurb": "Clear medium over a checkerboard. Drag to stir, +/- tune strength.",
	},
	{
		"name": "Synth",
		"path": "res://core/audio/synth_demo.tscn",
		"blurb": "Synth voices. A-K hold notes, Up/Down glide, R plays a phrase.",
	},
	{
		"name": "Groove",
		"path": "res://core/audio/groove_demo.tscn",
		"blurb": "Synthwave loop at 70 bpm. Space plays, 1/2 drums, B bass, P pads.",
	},
	{
		"name": "Audio",
		"path": "res://core/audio/audio_demo.tscn",
		"blurb": "Bus sliders and mutes, loop layers, the smoothed effect fader.",
	},
	{
		"name": "Comfort",
		"path": "res://features/ui/comfort_settings/comfort_settings_demo.tscn",
		"blurb":
		"Distortion, look sensitivity, floater overshoot — adjust, then open a panorama level.",
	},
]

const BACKGROUND := Color(0.08, 0.085, 0.1)
const TEXT := Color(0.86, 0.87, 0.9)
const MUTED := Color(0.56, 0.58, 0.63)

var _demo: Node
var _overlay: CanvasLayer
var _first_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_overlay = _build_overlay()
	add_child(_overlay)
	_first_button.grab_focus.call_deferred()


## Whether a demo is running in front of the menu.
func is_demo_open() -> bool:
	return is_instance_valid(_demo)


## The running demo, or null at the menu.
func get_demo() -> Node:
	return _demo if is_demo_open() else null


## Instance the scene at [param path] and hand it the screen.
func open_demo(path: String) -> void:
	close_demo()
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("DemoMenu could not load %s" % path)
		return
	_demo = scene.instantiate()
	hide()
	_overlay.visible = true
	var tree := get_tree()
	tree.root.add_child(_demo)
	tree.current_scene = _demo
	demo_opened.emit(path)


## Free the running demo, if any, and come back to the menu.
func close_demo() -> void:
	if not is_demo_open():
		return
	var tree := get_tree()
	tree.root.remove_child(_demo)
	_demo.queue_free()
	_demo = null
	tree.current_scene = self
	# The two things a demo leaves behind: a captured cursor, and loops.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var audio := tree.root.get_node_or_null("AudioManager")
	if audio != null:
		audio.stop_loops()
	_overlay.visible = false
	show()
	_first_button.grab_focus.call_deferred()
	demo_closed.emit()


## [code]_input[/code], not unhandled: demos take keys in their own unhandled
## handlers, and nothing a demo does should be able to swallow the way out.
func _input(event: InputEvent) -> void:
	if not is_demo_open() or not _is_back(event):
		return
	get_viewport().set_input_as_handled()
	close_demo()


static func _is_back(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.pressed and not key.echo and key.keycode == KEY_BACKSPACE
	var button := event as InputEventJoypadButton
	return button != null and button.pressed and button.button_index == JOY_BUTTON_BACK


func _build() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	column.add_child(_label("Demos", 40, TEXT))
	column.add_child(_label("Pick one. Backspace or Select comes back here.", 16, MUTED))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)

	for demo in DEMOS:
		var button := _card(demo)
		grid.add_child(button)
		if _first_button == null:
			_first_button = button


func _card(demo: Dictionary) -> Button:
	var button := Button.new()
	button.name = demo["name"]
	button.custom_minimum_size = Vector2(0.0, 96.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = demo["path"]
	button.pressed.connect(open_demo.bind(demo["path"]))

	var text := VBoxContainer.new()
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 16.0
	text.offset_right = -16.0
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_label(demo["name"], 22, TEXT))
	var blurb := _label(demo["blurb"], 14, MUTED)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(blurb)
	button.add_child(text)
	return button


## A small reminder of the way out, over whatever the demo draws.
func _build_overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.visible = false
	var hint := _label("⌫ menu", 13, Color(0.5, 0.52, 0.56, 0.7))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -12.0
	hint.offset_bottom = -8.0
	layer.add_child(hint)
	return layer


static func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
