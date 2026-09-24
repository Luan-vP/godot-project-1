class_name LevelSelect
extends Control
## The game's front door: pick a level, play it, come back.
##
## Cards are discovered from [Level] resources under [constant LEVELS_DIR]
## rather than a hardcoded list — dropping a new [code].tres[/code] there is
## enough to make it appear, see [method discover_levels]. Picking a card
## plays that [Level] through [constant PANORAMA_LEVEL_SCENE], the one scene
## every discovered level is instanced from.
##
## The menu never leaves the tree, the same reason [code]DemoMenu[/code]
## doesn't: staying alive is what lets it hear the back key while a level
## runs, without an autoload for the job. A picked level is instanced beside
## it under the root and made the current scene; going back frees that
## instance completely rather than hiding it, so returning to a level later
## always starts it fresh rather than resuming the one left behind, and
## [method PanoramaLevel._rebuild_medium]'s tank — [FluidGPU] resources and
## all — actually gets torn down rather than merely losing its reference.
##
## The secret eye tank ([code]features/levels/secret_eyes/[/code]) is not a
## [Level] and so is never discovered; it is reached by
## [method _is_secret_gesture] instead — see that method and the eye tank's
## README for why a level-select gesture replaced the Shift-at-startup flag
## that folder's README used to call for.

## Emitted after a card's scene has been instanced and made the current scene.
signal level_opened(entry_name: String)

## Emitted after the running level has been freed and the menu is showing.
signal level_closed

## Folder [method discover_levels] scans for [Level] resources. Keep in step
## with [code]resources/levels/README.md[/code].
const LEVELS_DIR := "res://resources/levels/"

## The scene every discovered [Level] is played through.
const PANORAMA_LEVEL_SCENE := "res://features/levels/panorama/panorama_level.tscn"

## The one entry [method get_entries] never discovers — see the class doc.
const SECRET_LEVEL_NAME := "Eyes"
const SECRET_LEVEL_SCENE := "res://features/levels/secret_eyes/fluid_demo.tscn"
const SECRET_LEVEL_BLURB := (
	"Secret level: the eye tank. Drag to stir and paint, arrows tilt," + " Space jogs."
)

const BACKGROUND := Color(0.08, 0.085, 0.1)
const TEXT := Color(0.86, 0.87, 0.9)
const MUTED := Color(0.56, 0.58, 0.63)

## Overridable so tests can point either at a stand-in instead of the real,
## GPU-backed scenes.
var level_scene_path: String = PANORAMA_LEVEL_SCENE
var secret_scene_path: String = SECRET_LEVEL_SCENE

var _level: Node
var _overlay: CanvasLayer
var _grid: GridContainer
var _first_button: Button
var _secret_revealed: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_overlay = _build_overlay()
	add_child(_overlay)
	_populate_grid()


## Every [Level] resource found directly under [constant LEVELS_DIR], sorted
## by display name so the list is stable regardless of directory order.
static func discover_levels() -> Array[Level]:
	var found: Array[Level] = []
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		return found
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			var resource := load(LEVELS_DIR + file_name)
			if resource is Level:
				found.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	found.sort_custom(_by_display_name)
	return found


static func _by_display_name(a: Level, b: Level) -> bool:
	return _display_name(a) < _display_name(b)


## Whether a level (or the secret entry) is running in front of the menu.
func is_level_open() -> bool:
	return is_instance_valid(_level)


## The running level's node, or null at the menu.
func get_level() -> Node:
	return _level if is_level_open() else null


## Every card the menu currently shows: one per [method discover_levels]
## result, plus the secret entry once its gesture has been seen.
func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for level in discover_levels():
		(
			entries
			. append(
				{
					"name": _display_name(level),
					"level": level,
					"scene_path": level_scene_path,
					"blurb": level.blurb,
				}
			)
		)
	if _secret_revealed:
		(
			entries
			. append(
				{
					"name": SECRET_LEVEL_NAME,
					"level": null,
					"scene_path": secret_scene_path,
					"blurb": SECRET_LEVEL_BLURB,
				}
			)
		)
	return entries


## Instance [param entry]'s scene and hand it the screen, tearing down
## whatever was already open first so a level never runs on top of another.
func open_entry(entry: Dictionary) -> void:
	close_level()
	var packed := load(entry["scene_path"]) as PackedScene
	if packed == null:
		push_warning("LevelSelect could not load %s" % entry["scene_path"])
		return
	_level = packed.instantiate()
	var level: Level = entry.get("level")
	if level != null:
		_level.level = level
	hide()
	_overlay.visible = true
	var tree := get_tree()
	tree.root.add_child(_level)
	tree.current_scene = _level
	level_opened.emit(entry["name"])


## Free the running level, if any, and come back to the menu.
func close_level() -> void:
	if not is_level_open():
		return
	var tree := get_tree()
	tree.root.remove_child(_level)
	_level.queue_free()
	_level = null
	tree.current_scene = self
	# The two things a level can leave behind: a captured cursor, and loops —
	# the secret eye band plays music, the same reason DemoMenu.close_demo
	# stops it.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var audio := tree.root.get_node_or_null("AudioManager")
	if audio != null:
		audio.stop_loops()
	_overlay.visible = false
	show()
	if _first_button != null:
		_first_button.grab_focus.call_deferred()
	level_closed.emit()


## [code]_input[/code], not unhandled: levels take keys in their own
## unhandled handlers, and nothing a level does should be able to swallow the
## way out.
func _input(event: InputEvent) -> void:
	if is_level_open():
		if _is_back(event):
			get_viewport().set_input_as_handled()
			close_level()
		return
	if not _secret_revealed and _is_secret_gesture(event):
		_reveal_secret()


static func _is_back(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.pressed and not key.echo and key.keycode == KEY_BACKSPACE
	var button := event as InputEventJoypadButton
	return button != null and button.pressed and button.button_index == JOY_BUTTON_BACK


## Shift on a keyboard, [constant JOY_BUTTON_Y] on a gamepad — no mouse
## needed either way, the same reason the rest of this screen works from
## focus and [code]ui_accept[/code]. Replaces the Shift-at-startup flag the
## secret eye tank's README used to call for: there was no menu yet for a
## gesture to live on when that was written.
static func _is_secret_gesture(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.pressed and not key.echo and key.keycode == KEY_SHIFT
	var button := event as InputEventJoypadButton
	return button != null and button.pressed and button.button_index == JOY_BUTTON_Y


func _reveal_secret() -> void:
	_secret_revealed = true
	_populate_grid()


func _populate_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_first_button = null
	for entry in get_entries():
		var button := _card(entry)
		_grid.add_child(button)
		if _first_button == null:
			_first_button = button
	if _first_button != null:
		_first_button.grab_focus.call_deferred()


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

	column.add_child(_label("Levels", 40, TEXT))
	column.add_child(_label("Pick one. Backspace or Select comes back here.", 16, MUTED))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_grid)


func _card(entry: Dictionary) -> Button:
	var button := Button.new()
	button.name = entry["name"]
	button.custom_minimum_size = Vector2(0.0, 96.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(open_entry.bind(entry))

	var text := VBoxContainer.new()
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 16.0
	text.offset_right = -16.0
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_label(entry["name"], 22, TEXT))
	var blurb: String = entry.get("blurb", "")
	if blurb != "":
		var blurb_label := _label(blurb, 14, MUTED)
		blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(blurb_label)
	button.add_child(text)
	return button


## A small reminder of the way out, over whatever the level draws.
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


static func _display_name(level: Level) -> String:
	if level.display_name != "":
		return level.display_name
	return level.resource_path.get_file().get_basename().capitalize()


static func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
