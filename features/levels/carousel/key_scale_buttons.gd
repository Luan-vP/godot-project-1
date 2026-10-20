class_name KeyScaleButtons
extends CanvasLayer
## The key and the scale, on the screen in every level: three buttons in the
## top-right corner, big enough for a thumb, since most players are on a
## touch screen with no shoulder buttons to move the key.
##
## They move the [Band]'s key by a fourth either way and step its scale
## ([method Band.cycle_scale]): the palette of notes the levels play over the
## song — the spout's pins, the flocks' arpeggios. [SharedLayers] keeps one,
## so it stays put while levels slide under it.
##
## The buttons never take focus, so Enter and the pad stay with the level.

## Big enough for a thumb on a phone or the Deck's screen.
const BUTTON_SIZE := Vector2(116, 52)
## Over the levels' HUDs, under the menu's corner button and the tempo toast.
const LAYER := 90

var band: Band

var _row: HBoxContainer


func _ready() -> void:
	layer = LAYER
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_row.add_theme_constant_override("separation", 10)
	var buttons := [
		["KeyDown", "key −4th", shift_key.bind(-KeyShiftInput.FOURTH)],
		["KeyUp", "key +4th", shift_key.bind(KeyShiftInput.FOURTH)],
		["NextScale", "scale ▸", next_scale],
	]
	for spec in buttons:
		var button := Button.new()
		button.name = spec[0]
		button.text = spec[1]
		# A CanvasLayer is not a Control, so the menus' theme does not reach here.
		UiTheme.apply(button)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = BUTTON_SIZE
		button.pressed.connect(spec[2])
		_row.add_child(button)
	add_child(_row)
	_fit()
	get_viewport().size_changed.connect(_fit)


## Move the band's key by [param semitones], as a shoulder press would.
func shift_key(semitones: int) -> void:
	if band != null:
		band.set_key_offset(band.get_key_offset() + semitones)


## Step the band's scale on to the next in [constant PegScale.CYCLE].
func next_scale() -> void:
	if band != null:
		band.cycle_scale()


## Clear the phone's island and rounded corners.
func _fit() -> void:
	var viewport := get_viewport()
	var edges := SafeArea.insets(SafeArea.canvas_rect(viewport), viewport.get_visible_rect().size)
	_row.offset_right = -(edges.z + 16.0)
	_row.offset_top = edges.y + 12.0
