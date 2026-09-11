extends Control
## Manual, audible proof that the audio foundation works. Open this scene and
## run it directly (F6) — nothing here is game-specific, it only exercises
## [AudioManager]: a slider and mute box per bus, a focus-mute toggle, and two
## buttons that play a procedural [AudioTestTone] through SFX and Music.

const _BUSES: Array[String] = [
	AudioManager.MASTER_BUS, AudioManager.MUSIC_BUS, AudioManager.SFX_BUS
]

var _music_playing := false
var _music_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = "Audio foundation demo"
	root.add_child(title)

	for bus_name in _BUSES:
		root.add_child(_build_bus_row(bus_name))

	root.add_child(_build_focus_mute_row())

	var sfx_button := Button.new()
	sfx_button.text = "Play SFX test tone"
	sfx_button.pressed.connect(
		func(): AudioManager.play_sfx(AudioTestTone.generate(880.0, 0.25))
	)
	root.add_child(sfx_button)

	_music_button = Button.new()
	_music_button.text = "Play music test tone (loops)"
	_music_button.pressed.connect(_on_music_pressed)
	root.add_child(_music_button)


func _build_bus_row(bus_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = bus_name
	label.custom_minimum_size = Vector2(80, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = AudioManager.get_bus_volume_linear(bus_name)
	slider.custom_minimum_size = Vector2(200, 0)
	slider.value_changed.connect(
		func(value: float): AudioManager.set_bus_volume_linear(bus_name, value)
	)
	row.add_child(slider)

	var mute_box := CheckBox.new()
	mute_box.text = "Mute"
	mute_box.button_pressed = AudioManager.is_bus_mute(bus_name)
	mute_box.toggled.connect(func(muted: bool): AudioManager.set_bus_mute(bus_name, muted))
	row.add_child(mute_box)

	return row


func _build_focus_mute_row() -> CheckBox:
	var check_box := CheckBox.new()
	check_box.text = "Mute everything when the window loses focus"
	check_box.button_pressed = AudioManager.mute_on_focus_loss
	check_box.toggled.connect(AudioManager.set_mute_on_focus_loss)
	return check_box


func _on_music_pressed() -> void:
	_music_playing = not _music_playing
	if _music_playing:
		var stream := AudioTestTone.generate(220.0, 1.0, 0.4)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size() / 2
		AudioManager.play_music(stream)
		_music_button.text = "Stop music test tone"
	else:
		AudioManager.stop_music()
		_music_button.text = "Play music test tone (loops)"
