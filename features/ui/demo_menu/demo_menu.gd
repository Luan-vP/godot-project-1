class_name DemoMenu
extends Control
## Click or tap into any level or demo, and come back out with Backspace, or
## the "menu" button in the corner.
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
##
## On a phone there is no Backspace, so the corner hint is a real button, and
## the layout keeps clear of the Dynamic Island and home indicator (see
## [SafeArea]). The card grid drops to one column in portrait.
##
## Two launch options exist for a device nobody is holding, where the only
## way in is the command line (see "Building for iPhone" in the README):
## [code]--open=eyes[/code] goes straight into a demo, and
## [code]--probe[/code] or [code]--probe=eyes,vitreous[/code] hands the menu to
## a [FrameProbe], which quits the app when it is done.

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
		"name": "Eye Gaze",
		"path": "res://core/look/gaze/gaze_debug_demo.tscn",
		"blurb": "Eye tracking readout: state, gaze, the turn it makes. Calibrate, then look.",
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
]

## Below this canvas width, cards stack in one column. Two columns of cards
## narrower than about 320 units wrap every blurb onto four or more lines.
const TWO_COLUMN_MIN_WIDTH := 720.0

## Space kept between the safe area and the content.
const MARGIN := 48.0
const NARROW_MARGIN := 24.0

## A tap target, in canvas units. Apple's 44 pt minimum is about 55 units at
## the phone's canvas scale.
const BACK_BUTTON_SIZE := Vector2(112.0, 56.0)

const BACKGROUND := Color(0.08, 0.085, 0.1)
const TEXT := Color(0.86, 0.87, 0.9)
const MUTED := Color(0.56, 0.58, 0.63)

var _demo: Node
var _overlay: CanvasLayer
var _back_button: Button
var _margin: MarginContainer
var _grid: GridContainer
var _first_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_overlay = _build_overlay()
	add_child(_overlay)
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)
	_focus_first_card()
	_apply_launch_options.call_deferred(launch_options(_command_line()))


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
	_focus_first_card()
	demo_closed.emit()


## [code]_input[/code], not unhandled: demos take keys in their own unhandled
## handlers, and nothing a demo does should be able to swallow the way out.
func _input(event: InputEvent) -> void:
	if not is_demo_open() or not _is_back(event):
		return
	get_viewport().set_input_as_handled()
	close_demo()


## The demos a comma-separated [param names] list picks, matched loosely:
## "eyes", "Overcast Sky" and "overcast_sky" all work. Empty picks them all.
static func demos_named(names: String) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	var wanted := PackedStringArray()
	for part in names.split(",", false):
		wanted.append(_slug(part))
	for demo in DEMOS:
		if wanted.is_empty() or wanted.has(_slug(demo["name"])):
			picked.append(demo)
	return picked


## Read [code]--open=[/code] and [code]--probe[=][/code] out of command-line
## [param args]. Unknown arguments are left alone; they belong to Godot.
static func launch_options(args: PackedStringArray) -> Dictionary:
	var options := {}
	for arg in args:
		if arg.begins_with("--open="):
			var found := demos_named(arg.trim_prefix("--open="))
			if found.size() > 0 and not arg.trim_prefix("--open=").is_empty():
				options["open"] = found[0]["path"]
		elif arg == "--probe":
			options["probe"] = demos_named("")
		elif arg.begins_with("--probe="):
			options["probe"] = demos_named(arg.trim_prefix("--probe="))
	return options


static func _slug(text: String) -> String:
	return text.strip_edges().to_lower().replace(" ", "_")


func _command_line() -> PackedStringArray:
	return OS.get_cmdline_args() + OS.get_cmdline_user_args()


func _apply_launch_options(options: Dictionary) -> void:
	if options.has("probe"):
		var which: Array[Dictionary] = options["probe"]
		var probe := FrameProbe.new(self, which)
		# Unattended: nobody is there to close the app, and devicectl's console
		# waits for it to exit.
		probe.finished.connect(func(_report): get_tree().quit())
		add_child(probe)
	elif options.has("open"):
		open_demo(options["open"])


## How many columns of cards fit a canvas [param width] units wide.
static func columns_for_width(width: float) -> int:
	return 2 if width >= TWO_COLUMN_MIN_WIDTH else 1


## Keyboard and gamepad players need a focused card to start from. On a touch
## screen the focus ring just reads as a card stuck half-pressed.
func _focus_first_card() -> void:
	if not DisplayServer.is_touchscreen_available():
		_first_button.grab_focus.call_deferred()


## Lay the menu out for the canvas it is actually on: margins that clear the
## safe area, and one column when the screen is narrow.
func _fit_to_screen() -> void:
	var viewport := get_viewport()
	var canvas := viewport.get_visible_rect().size
	var edges := SafeArea.insets(SafeArea.canvas_rect(viewport), canvas)
	var columns := columns_for_width(canvas.x)
	var margin := MARGIN if columns > 1 else NARROW_MARGIN
	_margin.add_theme_constant_override("margin_left", int(edges.x + margin))
	_margin.add_theme_constant_override("margin_top", int(edges.y + margin))
	_margin.add_theme_constant_override("margin_right", int(edges.z + margin))
	_margin.add_theme_constant_override("margin_bottom", int(edges.w + margin))
	_grid.columns = columns
	_back_button.offset_right = -(edges.z + 8.0)
	_back_button.offset_bottom = -(edges.w + 4.0)


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

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_margin.add_child(column)

	column.add_child(_label("Demos", 40, TEXT))
	var hint := _label("Pick one. Backspace, Select or the menu button comes back here.", 16, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_grid = GridContainer.new()
	_grid.name = "Cards"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_grid)

	for demo in DEMOS:
		var button := _card(demo)
		_grid.add_child(button)
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


## A small reminder of the way out, over whatever the demo draws — and on a
## phone, the only way out, so it is a button with a thumb-sized target.
##
## It never takes focus: several demos play notes on Space, and a focused
## button would swallow that and close the demo instead.
func _build_overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.visible = false
	_back_button = Button.new()
	_back_button.name = "BackToMenu"
	_back_button.text = "⌫ menu"
	_back_button.flat = true
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_back_button.custom_minimum_size = BACK_BUTTON_SIZE
	_back_button.add_theme_font_size_override("font_size", 15)
	var muted := Color(0.5, 0.52, 0.56, 0.7)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		_back_button.add_theme_color_override(state, muted)
	_back_button.add_theme_color_override("font_pressed_color", TEXT)
	_back_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_back_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_back_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_back_button.pressed.connect(close_demo)
	layer.add_child(_back_button)
	return layer


static func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
