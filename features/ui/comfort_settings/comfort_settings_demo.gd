extends Control
## Manual proof that [ComfortSettings] works and is reachable in-game: a
## slider per comfort option, bound straight to its setter the same way
## `audio_demo.gd`'s bus sliders are bound to [AudioManager]. Haptics strength
## applies to the next pulse; feel it in Spout B, which ticks once per ball.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = "Comfort options demo (#17)"
	root.add_child(title)

	var blurb := Label.new()
	blurb.text = (
		"Defaults are the tuned values, not the accessible ones. Pulling a "
		+ "slider down widens who can play comfortably; it does not change "
		+ "what the game plays like at the default."
	)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(blurb)

	root.add_child(
		_build_row(
			"Haptics strength",
			0.0,
			1.0,
			ComfortSettings.haptics_strength,
			ComfortSettings.set_haptics_strength
		)
	)


func _build_row(
	label_text: String, min_value: float, max_value: float, value: float, setter: Callable
) -> HBoxContainer:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(240, 0)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.text = "%.2f" % value
	row.add_child(value_label)

	slider.value_changed.connect(
		func(new_value: float):
			setter.call(new_value)
			value_label.text = "%.2f" % new_value
	)

	return row
