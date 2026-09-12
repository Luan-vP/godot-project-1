extends Control
## Manual, audible proof that the audio foundation works. Open this scene and
## run it directly (F6) — nothing here is game-specific, it only exercises
## [AudioManager]: a slider and mute box per bus, a focus-mute toggle, two
## buttons that play a procedural [AudioTestTone] through SFX and Music, and a
## [ParameterFader] demo sweeping a filter cutoff and a reverb wet mix.

const _BUSES: Array[String] = [
	AudioManager.MASTER_BUS, AudioManager.MUSIC_BUS, AudioManager.SFX_BUS
]

## One full sweep, low to high and back, every this many seconds — fast enough
## that a per-frame direct assignment audibly steps and zippers.
const _SWEEP_PERIOD := 3.0

const _CUTOFF_RANGE := Vector2(200.0, 6000.0)

var _music_playing := false
var _music_button: Button

var _sfx_loop_playing := false
var _sfx_loop_button: Button

var _smooth_check: CheckBox
var _sweep_time := 0.0
var _cutoff_effect: AudioEffectLowPassFilter
var _cutoff_effect_index := -1
var _cutoff_fader: ParameterFader
var _wet_effect: AudioEffectReverb
var _wet_effect_index := -1
var _wet_fader: ParameterFader
var _sfx_loop_player: AudioStreamPlayer


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

	root.add_child(_build_fader_demo_row())


func _exit_tree() -> void:
	# Leave the buses as this demo found them rather than leaking a filter and
	# a reverb into whatever runs after it in the same process.
	if _cutoff_effect_index != -1:
		AudioManager.remove_bus_effect(AudioManager.SFX_BUS, _cutoff_effect_index)
	if _wet_effect_index != -1:
		AudioManager.remove_bus_effect(AudioManager.MUSIC_BUS, _wet_effect_index)


func _process(delta: float) -> void:
	if _cutoff_fader == null:
		return

	_sweep_time += delta
	# A triangle wave in [0, 1]: linear, so the gap-closing shape in the
	# smoothed curve is due to the fader, not to an easing already baked into
	# the input.
	var phase := fmod(_sweep_time / _SWEEP_PERIOD, 1.0)
	var lfo_value := 1.0 - absf(phase * 2.0 - 1.0)

	if _smooth_check.button_pressed:
		_cutoff_fader.advance(delta, lfo_value)
		_wet_fader.advance(delta, lfo_value)
	else:
		# The naive version this whole feature exists to replace: assign the
		# mapped value directly, every frame.
		_cutoff_effect.cutoff_hz = ParameterFader.remap(
			lfo_value, 0.0, 1.0, _CUTOFF_RANGE.x, _CUTOFF_RANGE.y
		)
		_wet_effect.wet = ParameterFader.remap(lfo_value, 0.0, 1.0, 0.0, 1.0)


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


## Adds a low-pass filter to SFX and a reverb to Music, each driven by a
## [ParameterFader] from the same swept value in [method _process] — the
## checkbox bypasses both faders at once so the naive and smoothed versions
## are one toggle apart, everything else held equal.
func _build_fader_demo_row() -> VBoxContainer:
	var section := VBoxContainer.new()

	var label := Label.new()
	label.text = (
		"ParameterFader demo: filter cutoff (SFX) + reverb wet (Music), swept every %.0fs"
		% _SWEEP_PERIOD
	)
	section.add_child(label)

	_smooth_check = CheckBox.new()
	_smooth_check.text = "Smooth (uncheck to hear the naive per-frame jump)"
	_smooth_check.button_pressed = true
	section.add_child(_smooth_check)

	_cutoff_effect = AudioEffectLowPassFilter.new()
	_cutoff_effect_index = AudioManager.add_bus_effect(AudioManager.SFX_BUS, _cutoff_effect)
	_cutoff_fader = ParameterFader.new()
	_cutoff_fader.target = _cutoff_effect
	_cutoff_fader.property = &"cutoff_hz"
	_cutoff_fader.output_min = _CUTOFF_RANGE.x
	_cutoff_fader.output_max = _CUTOFF_RANGE.y
	_cutoff_fader.retention_per_second = 0.01
	_cutoff_fader.rest_value = _CUTOFF_RANGE.y

	_wet_effect = AudioEffectReverb.new()
	_wet_effect_index = AudioManager.add_bus_effect(AudioManager.MUSIC_BUS, _wet_effect)
	_wet_fader = ParameterFader.new()
	_wet_fader.target = _wet_effect
	_wet_fader.property = &"wet"
	_wet_fader.output_min = 0.0
	_wet_fader.output_max = 1.0
	_wet_fader.retention_per_second = 0.01
	_wet_fader.rest_value = 0.0

	_sfx_loop_button = Button.new()
	_sfx_loop_button.text = "Play looping filtered tone (SFX bus)"
	_sfx_loop_button.pressed.connect(_on_sfx_loop_pressed)
	section.add_child(_sfx_loop_button)

	return section


func _on_sfx_loop_pressed() -> void:
	_sfx_loop_playing = not _sfx_loop_playing
	if _sfx_loop_playing:
		var tone := AudioTestTone.generate(440.0, 1.0, 0.5)
		tone.loop_mode = AudioStreamWAV.LOOP_FORWARD
		tone.loop_end = tone.data.size() / 2
		_sfx_loop_player = AudioManager.play_sfx(tone)
		_sfx_loop_button.text = "Stop looping filtered tone"
	else:
		if _sfx_loop_player != null:
			_sfx_loop_player.stop()
		_sfx_loop_button.text = "Play looping filtered tone (SFX bus)"
