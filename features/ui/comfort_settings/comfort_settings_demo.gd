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
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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


func _build_row(
	label_text: String, min_value: float, max_value: float, value: float, setter: Callable
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP)

	var label := UiTheme.label(label_text, UiTheme.STATUS)
	label.custom_minimum_size = Vector2(200, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(280, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := UiTheme.label("%.2f" % value, UiTheme.CARD_INDEX)
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)

	slider.value_changed.connect(
		func(new_value: float):
			setter.call(new_value)
			value_label.text = "%.2f" % new_value
	)

	return row
