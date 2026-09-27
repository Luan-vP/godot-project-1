extends Node
## Live tempo control, in every scene (#72): up and down nudge the tempo by
## [constant SMALL_STEP] bpm, left and right jump it by [constant BIG_STEP].
## Arrow keys on a keyboard, the d-pad on a gamepad.
##
## It changes [AudioManager]'s tempo and nothing else. Whatever plays music
## already follows that live — [StepClock] and the loop layers read beats from
## the [MusicTimeSource], note lengths read [method AudioManager.get_music_clock]
## — so nothing here knows about any level.
##
## Keys are read in [method _unhandled_input], so a scene that wants the same
## keys for something else gets them first: the demo menu's focus navigation,
## for one, takes the arrows before they ever reach here.
##
## A short readout shows the new tempo after every nudge, then fades. A scene
## setting its own starting tempo does not trigger it.

const SMALL_STEP := 2.0
const BIG_STEP := 10.0

## The songs sit at 60-90 bpm; this leaves room to play either side, and
## keeps [MusicClock] well clear of a tempo at or below zero.
const MIN_BPM := 30.0
const MAX_BPM := 180.0

const TEMPO_UP := &"tempo_up"
const TEMPO_DOWN := &"tempo_down"
const TEMPO_UP_BIG := &"tempo_up_big"
const TEMPO_DOWN_BIG := &"tempo_down_big"

const READOUT_SECONDS := 1.4

var _readout: Label
var _readout_left := 0.0


func _ready() -> void:
	InputActions.ensure(TEMPO_UP, [KEY_UP] as Array[Key], [JOY_BUTTON_DPAD_UP] as Array[JoyButton])
	InputActions.ensure(
		TEMPO_DOWN, [KEY_DOWN] as Array[Key], [JOY_BUTTON_DPAD_DOWN] as Array[JoyButton]
	)
	InputActions.ensure(
		TEMPO_UP_BIG, [KEY_RIGHT] as Array[Key], [JOY_BUTTON_DPAD_RIGHT] as Array[JoyButton]
	)
	InputActions.ensure(
		TEMPO_DOWN_BIG, [KEY_LEFT] as Array[Key], [JOY_BUTTON_DPAD_LEFT] as Array[JoyButton]
	)
	_readout = _build_readout()


func _process(delta: float) -> void:
	if _readout_left <= 0.0:
		return
	_readout_left = maxf(_readout_left - delta, 0.0)
	_readout.modulate.a = clampf(_readout_left / 0.4, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	var change := step_for(event)
	if change == 0.0:
		return
	get_viewport().set_input_as_handled()
	nudge(change)


## Move the tempo by [param bpm], clamped to [constant MIN_BPM] and
## [constant MAX_BPM]. Returns the tempo it landed on.
func nudge(bpm: float) -> float:
	var tempo := next_tempo(AudioManager.get_tempo(), bpm)
	if tempo != AudioManager.get_tempo():
		AudioManager.set_bpm(tempo)
	_show(tempo)
	return tempo


## Where [param current] lands after a change of [param bpm].
static func next_tempo(current: float, bpm: float) -> float:
	return clampf(current + bpm, MIN_BPM, MAX_BPM)


## The bpm change [param event] asks for, or 0 for anything else. Held keys do
## repeat, so holding up walks the tempo steadily.
static func step_for(event: InputEvent) -> float:
	if not event.is_pressed():
		return 0.0
	if event.is_action(TEMPO_UP):
		return SMALL_STEP
	if event.is_action(TEMPO_DOWN):
		return -SMALL_STEP
	if event.is_action(TEMPO_UP_BIG):
		return BIG_STEP
	if event.is_action(TEMPO_DOWN_BIG):
		return -BIG_STEP
	return 0.0


func _show(tempo_bpm: float) -> void:
	_readout.text = "♩ %d bpm" % roundi(tempo_bpm)
	_readout_left = READOUT_SECONDS
	_readout.modulate.a = 1.0


func _build_readout() -> Label:
	var layer := CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.offset_right = -16.0
	label.offset_top = 12.0
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	return label
