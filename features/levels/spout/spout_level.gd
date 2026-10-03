class_name SpoutLevel
extends Node2D
## Level 3: a spout at the top, pins at the bottom, a band behind it all.
##
## Swing the [Spout] with either stick or A/D, or touch the screen (or hold
## the mouse button) where you want it to point; whatever comes out of it —
## the [SpoutEmitter] in [member emitter_script] — falls through the
## [PinField], and every pin it hits plays its note. The pins carry a scale
## laid out low to high, left to right ([PegScale]), starting on the
## pentatonic that matches the song.
##
## Behind it the eye band's songs play in full ([Band]), with the eye band's
## key moves: L1/R1 (Q/E) a fourth, L2/R2 (Z/X) a fifth — unless the emitter
## wants the triggers, as version B does. A key move scrolls the pins over to
## the new key, one column per step of the music, left to right. So does a
## change of scale: [method set_pin_scale] / [method cycle_scale], for now on
## the pad's Y, [kbd]Enter[/kbd] (the Deck's A outside Steam) or the touch
## button, as stand-ins until the real input is decided (#117). Not Tab: on a
## Deck outside Steam, View sends Tab, and that leaves the level.
##
## Buttons in the top-right corner move the key and the scale by touch, for a
## Deck run outside Steam, where the shoulder buttons do not reach the game.
##
## Built in code, like the eye tank: the scene file is a single node, and the
## two versions are scenes of this script with a different
## [member emitter_script].

## Paper the level is painted on.
const PAPER := Color(0.94, 0.91, 0.85)
const INK := Color(0.2, 0.17, 0.16, 0.8)
const FAINT := Color(0.2, 0.17, 0.16, 0.45)
const INK_ON_DARK := Color(0.95, 0.92, 0.86, 0.85)
const FAINT_ON_DARK := Color(0.95, 0.92, 0.86, 0.5)
## Big enough for a thumb on the Deck's screen.
const TOUCH_BUTTON_SIZE := Vector2(116, 52)

## The [SpoutEmitter] script to put in the slot. Left empty, the level uses
## [DebugSpoutEmitter].
@export var emitter_script: Script
## The level's name on the HUD.
@export var title: String = "Level 3"
## Fraction of the screen height the spout's pivot hangs at.
@export var spout_height: float = 0.07
## The pin field's rectangle, as fractions of the screen.
@export var pin_area: Rect2 = Rect2(0.1, 0.5, 0.8, 0.3)

var band: Band
var peg_scale: PegScale
var spout: Spout
var pins: PinField
var emitter: SpoutEmitter
var haptics: Haptics
var pointer: SpoutPointer

var _key_shift := KeyShiftInput.new()
var _hud: Label
var _status: Label


func _ready() -> void:
	var extent := get_viewport_rect().size

	var backdrop := ColorRect.new()
	backdrop.name = "Paper"
	backdrop.color = PAPER
	backdrop.size = extent
	backdrop.z_index = -200
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	haptics = Haptics.new()
	haptics.name = "Haptics"
	add_child(haptics)

	pins = PinField.new()
	pins.name = "Pins"
	pins.area = Rect2(pin_area.position * extent, pin_area.size * extent)
	add_child(pins)
	peg_scale = PegScale.new()
	pins.bind_scale(peg_scale)

	pointer = SpoutPointer.new()
	pointer.name = "Pointer"
	add_child(pointer)

	spout = Spout.new()
	spout.name = "Spout"
	spout.position = Vector2(extent.x * 0.5, extent.y * spout_height)
	spout.z_index = 20
	spout.pointer = pointer
	add_child(spout)

	var script: Script = emitter_script if emitter_script != null else DebugSpoutEmitter
	emitter = script.new()
	emitter.name = "Emitter"
	add_child(emitter)
	emitter.bind(self, spout, pins)
	_key_shift.use_triggers = emitter.leaves_triggers_free()
	pins.on_dark = emitter.dark_backdrop()

	band = Band.new()
	band.name = "Band"
	add_child(band)
	band.key_changed.connect(_on_key_changed)
	band.stepped.connect(_on_band_stepped)
	band.start()
	peg_scale.set_key(band.key_root(), band.is_minor())
	peg_scale.snap()

	_build_hud()


func _unhandled_input(event: InputEvent) -> void:
	var step := _key_shift.step_for(event)
	if step != 0:
		shift_key(step)
		get_viewport().set_input_as_handled()
		return
	if is_scale_press(event):
		cycle_scale()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_update_hud()


## Whether [param event] asks for the next scale: the pad's Y, or
## [kbd]Enter[/kbd] — the Deck's A under Steam's desktop layout. Temporary,
## until #117 settles the real input.
static func is_scale_press(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return key.pressed and not key.echo and (code == KEY_ENTER or code == KEY_KP_ENTER)
	var button := event as InputEventJoypadButton
	return button != null and button.pressed and button.button_index == JOY_BUTTON_Y


## Move the band's key by [param semitones], as a shoulder press would.
func shift_key(semitones: int) -> void:
	band.set_key_offset(band.get_key_offset() + semitones)


## Swap the pins to [param intervals]; it scrolls in from the left.
func set_pin_scale(intervals: Array[int], scale_name: String = "") -> void:
	peg_scale.set_scale(intervals, scale_name)


## Swap the pins to the next scale in [constant PegScale.CYCLE].
func cycle_scale() -> void:
	peg_scale.set_scale_named(peg_scale.next_scale_name())


func _on_key_changed(_offset: int) -> void:
	peg_scale.set_key(band.key_root(), band.is_minor())


func _on_band_stepped(_bar: int, _step_in_bar: int) -> void:
	peg_scale.advance()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	_hud = Label.new()
	var dark := emitter.dark_backdrop()
	_hud.add_theme_color_override("font_color", INK_ON_DARK if dark else INK)
	_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.offset_left = 16.0
	_hud.offset_bottom = -12.0
	layer.add_child(_hud)
	_status = Label.new()
	_status.add_theme_color_override("font_color", FAINT_ON_DARK if dark else FAINT)
	_status.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status.offset_left = 16.0
	_status.offset_top = 12.0
	layer.add_child(_status)
	layer.add_child(_build_touch_buttons())
	add_child(layer)


## Key and scale on the screen, top right, big enough for a thumb. They never
## take focus, so Enter and the pad stay with the level.
func _build_touch_buttons() -> Control:
	var row := HBoxContainer.new()
	row.name = "TouchButtons"
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_right = -16.0
	row.offset_top = 12.0
	row.add_theme_constant_override("separation", 10)
	var buttons := [
		["KeyDown", "key −4th", func(): shift_key(-KeyShiftInput.FOURTH)],
		["KeyUp", "key +4th", func(): shift_key(KeyShiftInput.FOURTH)],
		["NextScale", "scale ▸", cycle_scale],
	]
	for spec in buttons:
		var button := Button.new()
		button.name = spec[0]
		button.text = spec[1]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = TOUCH_BUTTON_SIZE
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(spec[2])
		row.add_child(button)
	return row


func _update_hud() -> void:
	if _hud == null:
		return
	var scale_line := peg_scale.scale_name()
	if peg_scale.is_scrolling():
		scale_line += " · scrolling…"
	var keys := "L1/R1 (Q/E) key ±4th"
	if _key_shift.use_triggers:
		keys += " · L2/R2 (Z/X) ±5th"
	var hint := PackedStringArray(["stick, A/D or touch aims", keys, "Y / Enter scale (temporary)"])
	if not emitter.controls_hint().is_empty():
		hint.append(emitter.controls_hint())
	_hud.text = (
		"%s · ♪ %s · %s · key %s (%+d) · %s\n%s"
		% [
			title,
			band.song_title(),
			band.current_section(),
			PinField.NOTE_NAMES[band.key_root()] + ("m" if band.is_minor() else ""),
			KeyShiftInput.display_offset(band.get_key_offset()),
			scale_line,
			" · ".join(hint),
		]
	)
	_status.text = emitter.describe()
