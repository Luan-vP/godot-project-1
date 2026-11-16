class_name DropDownPanel
extends PanelContainer
## A panel of sliders for the debug overlay ([LevelMeterOverlay]) under a
## header button that folds it away to a line. [MixPanel] and [SwingPanel]
## are each one of these with their own rows.

const WIDTH := 240.0
const NAME_WIDTH := 76.0
const VALUE_WIDTH := 44.0

## What the header says, after the fold arrow.
var title := ""

var _body: VBoxContainer
var _toggle: Button


func _ready() -> void:
	custom_minimum_size.x = WIDTH
	var column := VBoxContainer.new()
	add_child(column)
	_toggle = Button.new()
	_toggle.flat = true
	_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toggle.pressed.connect(func() -> void: set_collapsed(_body.visible))
	column.add_child(_toggle)
	_body = VBoxContainer.new()
	column.add_child(_body)
	_build_rows()
	set_collapsed(false)


## Add this panel's rows with [method add_slider]. Overridden by each panel.
func _build_rows() -> void:
	pass


func set_collapsed(collapsed: bool) -> void:
	_body.visible = not collapsed
	_toggle.text = "%s %s" % ["▸" if collapsed else "▾", title]
	reset_size()


func is_collapsed() -> bool:
	return not _body.visible


## A named slider across [param span] (x to y) starting at [param value],
## with its value beside it as [param format] writes it. [param changed] is
## called with every new value.
func add_slider(
	row_name: String, span: Vector2, step: float, value: float, format: Callable, changed: Callable
) -> HSlider:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = row_name
	name_label.custom_minimum_size.x = NAME_WIDTH
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = span.x
	slider.max_value = span.y
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = VALUE_WIDTH
	value_label.text = format.call(slider.value)
	row.add_child(value_label)
	slider.value_changed.connect(
		func(new_value: float) -> void:
			changed.call(new_value)
			value_label.text = format.call(new_value)
	)
	_body.add_child(row)
	return slider
