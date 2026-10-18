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
## wants the triggers, as both versions do: RT pours. A key move scrolls the pins over to
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

## Big enough for a thumb on the Deck's screen.
const TOUCH_BUTTON_SIZE := Vector2(116, 52)
## A key change prints the key's name into the middle of the tank, as the
## splash prints its logo, to swirl away with the water: this wide, as a
## share of the screen, and never taller than this share of it.
const KEY_PRINT_WIDTH := 0.42
const KEY_PRINT_MAX_HEIGHT := 0.2
## Pigment the name is printed with, and the size it is rendered at before
## it is scaled into the tank.
const KEY_PRINT_DENSITY := 1.5
const KEY_PRINT_FONT_SIZE := 96

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
## strings, frets 9 to 21 (the default), or the older staggered rows, pitch
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
	band.stepped.connect(_on_band_stepped)
	peg_scale.set_key(band.key_root(), band.is_minor())
	peg_scale.snap()

	_build_hud()


func _exit_tree() -> void:
	# The host's band outlives this level, so stop following it. Godot would
	# drop the connections to a freed level anyway; this just says so.
	if band != null:
		if band.key_changed.is_connected(_on_key_changed):
			band.key_changed.disconnect(_on_key_changed)
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


## Swap the pins to [param intervals]; it scrolls in from the left.
func set_pin_scale(intervals: Array[int], scale_name: String = "") -> void:
	peg_scale.set_scale(intervals, scale_name)


## Swap the pins to the next scale in [constant PegScale.CYCLE].
func cycle_scale() -> void:
	peg_scale.set_scale_named(peg_scale.next_scale_name())


func _on_key_changed(_offset: int) -> void:
	peg_scale.set_key(band.key_root(), band.is_minor())
	print_key_name()


## The key as it is printed into the tank: "F# minor".
static func key_name(root: int, minor: bool) -> String:
	return "%s %s" % [PinField.NOTE_NAMES[posmod(root, 12)], "minor" if minor else "major"]


## Where a printed name of [param aspect] (height over width) sits on a
## [param screen]-sized tank: centred, a share of the width, but never taller
## than a share of the height.
static func key_print_rect(screen: Vector2, aspect: float) -> Rect2:
	var width := minf(screen.x * KEY_PRINT_WIDTH, screen.y * KEY_PRINT_MAX_HEIGHT / aspect)
	var size := Vector2(width, width * aspect)
	return Rect2((screen - size) * 0.5, size)


## Print the band's key into the middle of the tank, in the root's pin
## colour, to drift and swirl with the water. Takes a frame to render the
## name; a no-op without a tank to print into.
func print_key_name() -> void:
	if _shared == null or _shared.fluid == null or not FluidGPU.is_available():
		return
	var fluid := _shared.fluid
	var root := band.key_root()
	var text := key_name(root, band.is_minor())
	var mask: Image = await DyePrint.render_text(
		self, text, UiTheme.display_font(), KEY_PRINT_FONT_SIZE
	)
	if mask == null or not is_instance_valid(fluid):
		return
	var world := fluid.get_world_rect()
	var aspect := float(mask.get_height()) / mask.get_width()
	var rect := key_print_rect(get_viewport_rect().size, aspect)
	rect.position -= world.position
	var cells := DyePrint.cells_for(rect, world.size, fluid.config.simulation_size())
	var color := PinField.note_color(root, 1.0).lightened(0.2)
	fluid.add_dye(DyePrint.tinted(mask, cells.size, color, KEY_PRINT_DENSITY), cells.position)


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
