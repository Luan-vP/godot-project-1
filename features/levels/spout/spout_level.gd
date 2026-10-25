class_name SpoutLevel
extends Node2D
## Level 3: a spout at the top, pins at the bottom, over the host's tank and
## band ([SharedLayers]).
##
## Swing the [Spout] with either stick or A/D, or touch the screen (or hold
## the mouse button) where you want it to point; whatever comes out of it —
## the [SpoutEmitter] in [member emitter_script] — falls through the
## [PinField], and every pin it hits plays its note. The pins carry a scale
## laid out as a scale diagram on a guitar's six strings ([FretboardScale]),
## or low to high, left to right ([PegScale]) — [member pin_layout] — starting
## on the pentatonic that matches the song.
##
## Behind it the host's band plays its song in full, with the eye band's
## key moves: L1/R1 (Q/E) a fourth, L2/R2 (Z/X) a fifth — unless the emitter
## wants the triggers, as the bubbles do: RT fires. A key move scrolls the pins over to
## the new key, one column per step of the music, left to right. So does a
## change of the band's scale ([signal Band.scale_changed]), which every level
## shares: [method cycle_scale] on the pad's Y or [kbd]Enter[/kbd] (the Deck's
## A outside Steam), or the host's scale button ([KeyScaleButtons]), as
## stand-ins until the real input is decided (#117). Not Tab: on a Deck
## outside Steam, View sends Tab, and that leaves the level.
## [method set_pin_scale] sets a scale on the pins alone.
##
## The host's buttons in the top-right corner move the key and the scale by
## touch, for a phone, or a Deck run outside Steam, where the shoulder buttons
## do not reach the game.
##
## Built in code, like the eye tank: the scene file is a single node, and the
## level ([code]bubbles/level_three.tscn[/code]) is a scene of this script
## with [BubbleEmitter] as its [member emitter_script].

## The [SpoutEmitter] script to put in the slot. Left empty, the level uses
## [DebugSpoutEmitter].
@export var emitter_script: Script
## The level's name on the HUD.
@export var title: String = "Level 3"
## Fraction of the screen height the spout's pivot hangs at.
@export var spout_height: float = 0.07
## The pin field's rectangle, as fractions of the screen, the bottom row at
## 80%.
@export var pin_area: Rect2 = Rect2(0.1, 0.65, 0.8, 0.15)
## The same for the fretboard: a little taller, 60% to 80% of the height, so
## its six strings sit close together but clear of each other, and the drop
## from the spout stays long.
@export var fretboard_area: Rect2 = Rect2(0.1, 0.6, 0.8, 0.2)
## How the pins lay the scale out: a scale diagram on the guitar's six
## strings, frets 9 to 20 (the default), or the older staggered rows, pitch
## rising left to right. See [PinField].
@export var pin_layout: PinField.Layout = PinField.Layout.FRETBOARD

var band: Band
var peg_scale: PegScale
var spout: Spout
var pins: PinField
var emitter: SpoutEmitter
var haptics: Haptics
var pointer: SpoutPointer

## The level's host: the tank behind it and the band. See [SharedLayers].
var _shared: SharedLayers
var _key_shift := KeyShiftInput.new()
var _hud: Label
var _status: Label
## The scale whose name was last printed into the tank.
var _printed_scale := ""


func _ready() -> void:
	var extent := get_viewport_rect().size
	_shared = SharedLayers.host_of(self)
	if _shared == null:
		process_mode = PROCESS_MODE_DISABLED
		return

	haptics = Haptics.new()
	haptics.name = "Haptics"
	add_child(haptics)

	pins = PinField.new()
	pins.name = "Pins"
	var fraction := fretboard_area if pin_layout == PinField.Layout.FRETBOARD else pin_area
	pins.area = Rect2(fraction.position * extent, fraction.size * extent)
	pins.layout = pin_layout
	add_child(pins)
	peg_scale = pins.new_scale()
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

	# The music carries on from the level before; this one only joins it, with
	# the whole arrangement.
	band = _shared.band
	for part in Band.PARTS:
		band.set_part_wanted(part, true)
	band.key_changed.connect(_on_key_changed)
	band.scale_changed.connect(_on_scale_changed)
	band.stepped.connect(_on_band_stepped)
	peg_scale.set_key(band.key_root(), band.is_minor())
	if not band.follows_key_scale():
		peg_scale.set_scale_named(band.scale_name())
	peg_scale.snap()

	_build_hud()
	print_scale_name(true)


func _exit_tree() -> void:
	# The host's band outlives this level, so stop following it. Godot would
	# drop the connections to a freed level anyway; this just says so.
	if band != null:
		if band.key_changed.is_connected(_on_key_changed):
			band.key_changed.disconnect(_on_key_changed)
		if band.scale_changed.is_connected(_on_scale_changed):
			band.scale_changed.disconnect(_on_scale_changed)
		if band.stepped.is_connected(_on_band_stepped):
			band.stepped.disconnect(_on_band_stepped)


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


## Swap the pins alone to [param intervals]; it scrolls in from the left.
## The band's scale, and every other level, stay as they are.
func set_pin_scale(intervals: Array[int], scale_name: String = "") -> void:
	peg_scale.set_scale(intervals, scale_name)
	print_scale_name()


## Move the band, and so the pins and every level, on to the next scale in
## [constant PegScale.CYCLE].
func cycle_scale() -> void:
	band.cycle_scale()


## Print the pins' scale's name into the tank (see [KeyPrint]) on arrival, and
## for a scale set on the pins alone; the host prints the band's own changes.
## Only when it differs from the last printed, unless [param again].
func print_scale_name(again: bool = false) -> void:
	var scale_name := peg_scale.scale_name()
	if scale_name.is_empty() or (scale_name == _printed_scale and not again):
		return
	_printed_scale = scale_name
	if _shared != null and _shared.key_print != null:
		_shared.key_print.print_scale(scale_name)


func _on_key_changed(_offset: int) -> void:
	peg_scale.set_key(band.key_root(), band.is_minor())


## The band's scale moved, and the host has printed its name: the pins
## scroll over to it.
func _on_scale_changed(scale_name: String) -> void:
	if band.follows_key_scale():
		peg_scale.use_key_pentatonic()
	else:
		peg_scale.set_scale_named(scale_name)
	_printed_scale = scale_name


func _on_band_stepped(_bar: int, _step_in_bar: int) -> void:
	peg_scale.advance()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	_hud = UiTheme.label("", UiTheme.HUD)
	_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hud.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hud.offset_left = 16.0
	_hud.offset_bottom = -12.0
	layer.add_child(_hud)
	_status = UiTheme.label("", UiTheme.HUD_FAINT)
	_status.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status.offset_left = 16.0
	_status.offset_top = 12.0
	layer.add_child(_status)
	add_child(layer)


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
