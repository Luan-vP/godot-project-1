class_name GameMenu
extends CanvasLayer
## The one control on the screen in every level: a menu button in the
## top-right corner that opens a panel with the level's hint and the band's
## controls.
##
## The panel holds the hint for the level playing ([member level], read
## through its [code]hint()[/code] method), the key moved by a fourth either
## way, the next scale ([method Band.cycle_scale]) and the next song
## ([method Band.next_song]). [SharedLayers] keeps one, so it stays put while
## levels slide under it; the carousel tells it which level has arrived.
##
## A tap anywhere outside the panel closes it, and the tap still reaches the
## level. The buttons never take focus, so Enter and the pad stay with the
## level.

## Big enough for a thumb on a phone or the Deck's screen.
const BUTTON_SIZE := Vector2(116, 52)
## The menu button: square, the same height as the others.
const MENU_BUTTON_SIZE := Vector2(52, 52)
## Bars drawn on the menu button, and their size.
const BAR_COUNT := 3
const BAR_SIZE := Vector2(24, 3)
const BAR_GAP := 7.0
## Over the levels' HUDs, under the tempo toast.
const LAYER := 90

var band: Band
## The level playing, whose hint the panel shows. Anything with a
## [code]hint() -> String[/code] method; anything else shows no hint.
var level: Node:
	set(value):
		level = value
		_refresh_hint()

var _corner: VBoxContainer
var _menu_button: Button
var _panel: PanelContainer
var _hint: Label


func _ready() -> void:
	layer = LAYER
	_corner = VBoxContainer.new()
	_corner.name = "Corner"
	_corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner.add_theme_constant_override("separation", 10)
	# A CanvasLayer is not a Control, so the menus' theme does not reach here.
	UiTheme.apply(_corner)
	add_child(_corner)

	_menu_button = _button("MenuButton", "", toggle)
	_menu_button.custom_minimum_size = MENU_BUTTON_SIZE
	_menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var bars := Control.new()
	bars.name = "Bars"
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.draw.connect(_draw_bars.bind(bars))
	_menu_button.add_child(bars)
	_corner.add_child(_menu_button)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme_type_variation = UiTheme.HUD_PANEL
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_panel.visible = false
	_corner.add_child(_panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)

	_hint = UiTheme.label("", UiTheme.HUD)
	_hint.name = "Hint"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = BUTTON_SIZE.x * 3 + 20
	column.add_child(_hint)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 10)
	row.add_child(_button("KeyDown", "key −4th", shift_key.bind(-KeyShiftInput.FOURTH)))
	row.add_child(_button("KeyUp", "key +4th", shift_key.bind(KeyShiftInput.FOURTH)))
	row.add_child(_button("NextScale", "scale ▸", next_scale))
	column.add_child(row)

	column.add_child(_button("NextSong", "next song ▸", next_song))

	_refresh_hint()
	_fit()
	get_viewport().size_changed.connect(_fit)


## Close the panel on a press anywhere outside it and the menu button. Watched
## in [method Node._input] and never consumed, so the level still gets it.
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var at := Vector2.INF
	var touch := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	if touch != null and touch.pressed:
		at = touch.position
	elif click != null and click.pressed:
		at = click.position
	if at == Vector2.INF:
		return
	if _panel.get_global_rect().has_point(at) or _menu_button.get_global_rect().has_point(at):
		return
	close()


## Open the panel if it is closed, close it if it is open.
func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	_refresh_hint()
	_panel.visible = true


func close() -> void:
	_panel.visible = false


func is_open() -> bool:
	return _panel != null and _panel.visible


## The hint the panel shows: the level's own, or an empty string.
func hint_text() -> String:
	return hint_for(level)


## [param node]'s hint, from its [code]hint()[/code] method, or an empty
## string when it has none.
static func hint_for(node: Node) -> String:
	if node == null or not is_instance_valid(node) or not node.has_method("hint"):
		return ""
	return str(node.call("hint"))


## Move the band's key by [param semitones], as a shoulder press would.
func shift_key(semitones: int) -> void:
	if band != null:
		band.set_key_offset(band.get_key_offset() + semitones)


## Step the band's scale on to the next in [constant PegScale.CYCLE].
func next_scale() -> void:
	if band != null:
		band.cycle_scale()


## Move the band on to another song, on the next bar line.
func next_song() -> void:
	if band != null:
		band.next_song()


func _button(button_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = BUTTON_SIZE
	button.pressed.connect(action)
	return button


func _refresh_hint() -> void:
	if _hint == null:
		return
	_hint.text = hint_text()
	_hint.visible = not _hint.text.is_empty()


## Three bars, centred on the menu button.
func _draw_bars(bars: Control) -> void:
	var height := BAR_COUNT * BAR_SIZE.y + (BAR_COUNT - 1) * BAR_GAP
	var top := (bars.size - Vector2(BAR_SIZE.x, height)) * 0.5
	for i in BAR_COUNT:
		var at := top + Vector2(0.0, i * (BAR_SIZE.y + BAR_GAP))
		bars.draw_rect(Rect2(at, BAR_SIZE), UiTokens.TEXT)


## Clear the phone's island and rounded corners.
func _fit() -> void:
	var viewport := get_viewport()
	var edges := SafeArea.insets(SafeArea.canvas_rect(viewport), viewport.get_visible_rect().size)
	_corner.offset_right = -(edges.z + 16.0)
	_corner.offset_top = edges.y + 12.0
