class_name SwingPanel
extends DropDownPanel
## The swing control for the debug overlay ([LevelMeterOverlay]): one slider
## for [method AudioManager.set_swing], in the percent a drum machine shows —
## 50 straight, 67 a triplet shuffle, 75 the hardest. Everything on the music
## clock follows it: the band, the flocks and their dial, the spout's pins.

var _slider: HSlider


func _init() -> void:
	title = "swing (%)"


func _build_rows() -> void:
	_slider = add_slider(
		"swing",
		Vector2(Swing.STRAIGHT, Swing.MAX) * 100.0,
		1.0,
		percent_for(AudioManager.get_swing()),
		func(percent: float) -> String: return str(roundi(percent)),
		_on_slider_moved
	)
	AudioManager.swing_changed.connect(_on_swing_changed)


## [param ratio] as the whole percent the slider shows.
static func percent_for(ratio: float) -> float:
	return roundf(ratio * 100.0)


func _on_slider_moved(percent: float) -> void:
	# A swing set elsewhere is shown to the nearest percent, not rounded to it.
	if percent != percent_for(AudioManager.get_swing()):
		AudioManager.set_swing(percent / 100.0)


## Swing set from somewhere else moves the slider too.
func _on_swing_changed(ratio: float) -> void:
	_slider.value = percent_for(ratio)
