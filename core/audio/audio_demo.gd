extends Control
## Manual, audible proof that the audio foundation works. Open this scene and
## run it directly (F6) — nothing here is game-specific, it only exercises
## [AudioManager]: a slider and mute box per bus, a focus-mute toggle, two
## buttons that play a procedural [AudioTestTone] through SFX and Music, and a
## loop layering section (#31) that plays two phase-locked test-tone loops
## and toggles them on a bar boundary.

const _BUSES: Array[String] = [
	AudioManager.MASTER_BUS, AudioManager.MUSIC_BUS, AudioManager.SFX_BUS
]

var _music_playing := false
var _music_button: Button

var _play_loops_button: Button
var _bar_beat_label: Label


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
	sfx_button.pressed.connect(func(): AudioManager.play_sfx(AudioTestTone.generate(880.0, 0.25)))
	root.add_child(sfx_button)

	_music_button = Button.new()
	_music_button.text = "Play music test tone (loops)"
	_music_button.pressed.connect(_on_music_pressed)
	root.add_child(_music_button)

	root.add_child(_build_loop_layer_demo_section())


func _process(_delta: float) -> void:
	if _bar_beat_label == null:
		return
	if not AudioManager.is_loops_playing():
		_bar_beat_label.text = "Bar —, beat —"
		return
	var bar := AudioManager.get_current_bar()
	var beat := AudioManager.get_current_beat()
	_bar_beat_label.text = "Bar %d, beat %.2f" % [bar, beat]


## Manual proof of #31: two procedural loops configured as [LoopLayer] data,
## played phase-locked through [method AudioManager.play_loops], with each
## layer toggled on a bar boundary rather than restarting anything. Listen
## for the pad layer fading in cleanly on the next bar, not clicking in
## immediately, and watch the bar/beat label keep counting without either
## layer drifting out of phase with the other.
func _build_loop_layer_demo_section() -> VBoxContainer:
	var section := VBoxContainer.new()

	var title := Label.new()
	title.text = "Loop layering demo (#31)"
	section.add_child(title)

	_configure_demo_loops()

	_play_loops_button = Button.new()
	_play_loops_button.text = "Play loops"
	_play_loops_button.pressed.connect(_on_play_loops_pressed)
	section.add_child(_play_loops_button)

	var bass_box := CheckBox.new()
	bass_box.text = "Bass layer"
	bass_box.toggled.connect(func(pressed: bool): AudioManager.set_layer_active("bass", pressed))
	section.add_child(bass_box)

	var pad_box := CheckBox.new()
	pad_box.text = "Pad layer"
	pad_box.toggled.connect(func(pressed: bool): AudioManager.set_layer_active("pad", pressed))
	section.add_child(pad_box)

	_bar_beat_label = Label.new()
	section.add_child(_bar_beat_label)

	return section


func _configure_demo_loops() -> void:
	AudioManager.set_tempo(96.0, 4)

	var bass := LoopLayer.new()
	bass.layer_name = "bass"
	bass.stream = _looping_demo_tone(110.0)

	var pad := LoopLayer.new()
	pad.layer_name = "pad"
	pad.stream = _looping_demo_tone(330.0)

	var layers: Array[LoopLayer] = [bass, pad]
	AudioManager.configure_loop_layers(layers)


func _looping_demo_tone(frequency: float) -> AudioStreamWAV:
	var stream := AudioTestTone.generate(frequency, 2.0, 0.3)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	return stream


func _on_play_loops_pressed() -> void:
	if AudioManager.is_loops_playing():
		AudioManager.stop_loops()
		_play_loops_button.text = "Play loops"
	else:
		AudioManager.play_loops()
		_play_loops_button.text = "Stop loops"


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
