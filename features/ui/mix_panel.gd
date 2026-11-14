class_name MixPanel
extends PanelContainer
## Volume mix controls for the debug overlay ([LevelMeterOverlay]): a slider
## in dB for the band, the duck solo and the rhythm voices, set through
## [method AudioManager.set_mix_db]. A header button collapses it to a line.

const WIDTH := 240.0
const LABELS := {
	AudioManager.BAND_BUS: "band",
	AudioManager.SOLO_BUS: "duck solo",
	AudioManager.RHYTHM_BUS: "rhythm",
}

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
	for bus_name: String in LABELS:
		_body.add_child(_row(bus_name))
	set_collapsed(false)


func set_collapsed(collapsed: bool) -> void:
	_body.visible = not collapsed
	_toggle.text = "%s mix (dB)" % ("▸" if collapsed else "▾")
	reset_size()


func is_collapsed() -> bool:
	return not _body.visible


func _row(bus_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = LABELS[bus_name]
	name_label.custom_minimum_size.x = 76.0
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = AudioManager.MIX_MIN_DB
	slider.max_value = AudioManager.MIX_MAX_DB
	slider.step = 0.5
	slider.value = AudioManager.get_mix_db(bus_name)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 44.0
	value_label.text = "%+.1f" % slider.value
	row.add_child(value_label)
	slider.value_changed.connect(
		func(db: float) -> void:
			AudioManager.set_mix_db(bus_name, db)
			value_label.text = "%+.1f" % db
	)
	return row
