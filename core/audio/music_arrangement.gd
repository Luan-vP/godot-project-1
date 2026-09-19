class_name MusicArrangement
extends Node
## Drives [AudioManager]'s loop layer stack from live scoring — the
## generative layer #34 asked for, on top of the mechanism #31 built and the
## data #26 publishes.
##
## Listens to [signal EventBus.scoring_updated], turns each snapshot into an
## intensity with [ScoringIntensity], and hands that to an
## [ArrangementDirector] for the hysteresis that keeps a flickering score from
## chattering a layer in and out. Only the changes the director actually
## decides on are applied, through [method AudioManager.set_layer_active] —
## which is what makes changes land on a bar boundary rather than the instant
## a floater arrives (#31), and what fades a layer in or out rather than
## clicking it.
##
## The layer stack and its thresholds are handed to [method configure] as
## data, not hardcoded here, since #34's notes call out that this will be
## retuned many times. A base "bed" layer that should play regardless of
## scoring is deliberately none of this class's business (#28: silence is
## never the right answer) — turn it on with [method AudioManager.set_layer_active]
## directly and leave it out of the stack given to [method configure].

## Emitted whenever a snapshot has been processed, with the raw intensity from
## [ScoringIntensity] and that value normalised 0..1 against the top of the
## configured threshold ladder (clamped, so intensity past the last threshold
## still reads as 1.0). For anything that should move continuously with
## scoring rather than step with the layer stack.
signal intensity_changed(raw: float, normalized: float)

## Continuous parameters to drive from intensity — e.g. a filter cutoff on the
## Music bus, fetched through [method AudioManager.get_bus_effect] and wired
## up by whoever configures this — advanced every frame with the normalised
## 0..1 intensity. What the fader is actually attached to is that caller's
## musical decision, not this class's; this only supplies the number, through
## [ParameterFader] (#32) so the movement is smoothed rather than stepped.
var effect_faders: Array[ParameterFader] = []

var _director: ArrangementDirector
var _last_intensity := 0.0


## Declares the ordered layer stack and its hysteresis, as data — see
## [ArrangementDirector] for what each argument means. Call once before
## scoring starts arriving; safe to call again to retune while it is not.
func configure(
	layers: Array[String],
	thresholds: Array[float],
	release_seconds: float = 2.0,
	min_hold_seconds: float = 0.0
) -> void:
	_director = ArrangementDirector.new(layers, thresholds, release_seconds, min_hold_seconds)


func _ready() -> void:
	EventBus.scoring_updated.connect(_on_scoring_updated)


func _exit_tree() -> void:
	if EventBus.scoring_updated.is_connected(_on_scoring_updated):
		EventBus.scoring_updated.disconnect(_on_scoring_updated)


func _process(delta: float) -> void:
	if effect_faders.is_empty():
		return
	var normalized := _normalized(_last_intensity)
	for fader in effect_faders:
		fader.advance(delta, normalized)


## The active layers, bottom to top, as of the last snapshot handled.
func active_layers() -> Array[String]:
	if _director == null:
		return []
	return _director.active_layers()


func current_level() -> int:
	return 0 if _director == null else _director.current_level()


func _on_scoring_updated(snapshot: ScoringSnapshot) -> void:
	if _director == null:
		return
	var intensity := ScoringIntensity.compute(snapshot)
	_last_intensity = intensity
	var beats := AudioManager.get_music_time_source().get_beats()
	var seconds := beats * AudioManager.get_music_clock().seconds_per_beat()
	var changes := _director.update(intensity, seconds)
	for layer_name: String in changes:
		AudioManager.set_layer_active(layer_name, changes[layer_name])
	intensity_changed.emit(intensity, _normalized(intensity))


func _normalized(intensity: float) -> float:
	if _director == null:
		return 0.0
	var top := _director.top_threshold()
	return 0.0 if top <= 0.0 else clampf(intensity / top, 0.0, 1.0)
