extends Control
## Manual proof that [ComfortSettings] works and is reachable in-game: a
## slider per comfort option, bound straight to its setter the same way
## `audio_demo.gd`'s bus sliders are bound to [AudioManager]. Haptics strength
## applies to the next pulse; feel it in Spout B, which ticks once per ball.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.apply(self)
	add_child(ArcaneBackdrop.new())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(UiTokens.MARGIN))
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UiTokens.GAP)
	margin.add_child(root)

	root.add_child(
		UiTheme.header(
			"COMFORT OPTIONS · #17",
			"Comfort",
			(
				"Defaults are the tuned values, not the accessible ones. Pulling a "
				+ "slider down widens who can play comfortably; it does not change "
				+ "what the game plays like at the default."
			)
		)
	)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	panel.add_child(
		_build_row(
			"Haptics strength",
			0.0,
			1.0,
			ComfortSettings.haptics_strength,
			ComfortSettings.set_haptics_strength
		)
	)


## A name and its value on one line, the slider across the full width under
## them, so the row fits a phone's 540-unit canvas as well as a Deck's.
func _build_row(
	label_text: String, min_value: float, max_value: float, value: float, setter: Callable
) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var head := HBoxContainer.new()
	row.add_child(head)
	var label := UiTheme.label(label_text, UiTheme.STATUS)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	var value_label := UiTheme.label("%.2f" % value, UiTheme.CARD_INDEX)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	slider.value_changed.connect(
		func(new_value: float):
			setter.call(new_value)
			value_label.text = "%.2f" % new_value
	)

	return row
