extends "res://features/levels/secret_eyes/fluid_demo.gd"
## The eye tank, with a band in it: each eye plays one part of the music while
## it floats clear of the walls. Tilt (WASD) or stir to push eyes against a
## wall and strip the arrangement back; let them drift free to fill it out.
## L1/R1 (or Q/E) move the key down/up a fourth, L2/R2 (or Z/X) a fifth — see
## [KeyShiftInput].
##
## Everything else — the tank, the eyes, the controls — is the secret level as
## it is. See [EyeBand] for how eyes become parts.

## Left alone, the eyes in this tank random-walk into the walls within ten
## seconds and stay there, which would leave the band silent almost at once.
## A soft spring towards the middle, in 1/second^2, keeps them afloat by
## default, weak enough that holding a tilt still pins them to a wall. At 0.8
## even a full tilt pinned nothing; at 0.4 a free tank played nearly the whole
## arrangement. 0.1, chosen by ear, leaves the eyes looser: more drifting onto
## walls on their own, and more work to keep the band playing.
const CENTRE_PULL := 0.1

const RING_GAP := 7.0
const PLAYING_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const SILENT_COLOR := Color(1.0, 1.0, 1.0, 0.14)
const TOUCHING_COLOR := Color(0.95, 0.45, 0.38, 0.85)

## Read straight from [Input], not [KeyShiftInput], so the debug line shows
## whether the hardware event reaches Godot at all — independent of any bug
## or remap in the key-shift path it would otherwise be used to diagnose.
const DEBUG_BUTTONS := {
	"L1": JOY_BUTTON_LEFT_SHOULDER,
	"R1": JOY_BUTTON_RIGHT_SHOULDER,
}
const DEBUG_AXES := {
	"L2": JOY_AXIS_TRIGGER_LEFT,
	"R2": JOY_AXIS_TRIGGER_RIGHT,
}

var _band: EyeBand
var _overlay: Node2D
var _parts_label: Label
var _debug_label: Label
var _key_shift := KeyShiftInput.new()


func _ready() -> void:
	super()
	_band = EyeBand.new()
	_band.name = "EyeBand"
	add_child(_band)
	_band.start()

	_overlay = Node2D.new()
	_overlay.name = "PartRings"
	_overlay.z_index = 50
	_overlay.draw.connect(_draw_rings)
	add_child(_overlay)

	var layer := CanvasLayer.new()
	_parts_label = Label.new()
	_parts_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))
	_parts_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_parts_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_parts_label.offset_left = 16.0
	_parts_label.offset_bottom = -12.0
	layer.add_child(_parts_label)

	_debug_label = Label.new()
	_debug_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.7))
	_debug_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_label.offset_left = 16.0
	_debug_label.offset_top = 12.0
	layer.add_child(_debug_label)
	add_child(layer)
	_update_label()


func _physics_process(delta: float) -> void:
	var centre := _simulation.get_world_rect().get_center()
	for child in get_children():
		var eye := child as FloatyEye
		if eye != null:
			eye.velocity += (centre - eye.global_position) * CENTRE_PULL * delta


func _unhandled_input(event: InputEvent) -> void:
	var step := _key_shift.step_for(event)
	if step != 0:
		_band.set_key_offset(_band.get_key_offset() + step)
		get_viewport().set_input_as_handled()
		# The readout shows the key we just set, not the one still sounding:
		# chords, bass, arp and melody only catch up from the next step (see
		# [method EyeBand.set_key_offset]), but the press itself is instant.
		_update_label()


func _process(delta: float) -> void:
	super(delta)
	_overlay.queue_redraw()
	_update_label()
	_update_debug_label()


func _update_label() -> void:
	var parts: PackedStringArray = []
	for part in EyeBand.PARTS:
		var mark := "●" if _band.is_playing(part) else "○"
		if _band.is_playing(part) != _band.wants_part(part):
			mark = "◐"
		parts.append("%s %s" % [mark, part])
	_parts_label.text = (
		(
			"♪ %s · %s · key %+d\n"
			% [
				_band.song_title(),
				_band.current_section(),
				KeyShiftInput.display_offset(_band.get_key_offset()),
			]
		)
		+ "   ".join(parts)
		+ "      keep eyes off the walls to hear them"
	)


## Raw pad state for L1/R1/L2/R2, to tell a controller that is not sending
## these events at all apart from one whose events just aren't reaching
## [method _unhandled_input].
func _update_debug_label() -> void:
	var pads := Input.get_connected_joypads()
	var device := pads[0] if not pads.is_empty() else 0
	var line: PackedStringArray = []
	for label in DEBUG_BUTTONS:
		var pressed := Input.is_joy_button_pressed(device, DEBUG_BUTTONS[label])
		line.append("%s %s" % [label, "●" if pressed else "○"])
	for label in DEBUG_AXES:
		line.append("%s %.2f" % [label, Input.get_joy_axis(device, DEBUG_AXES[label])])
	_debug_label.text = "   ".join(line)


## A ring round each eye: bright while its part plays, red while it is pressed
## against a wall, faint while it waits silent. Its part is written beneath.
func _draw_rings() -> void:
	var font := ThemeDB.fallback_font
	for child in get_children():
		var eye := child as FloatyEye
		if eye == null:
			continue
		var part := _band.part_for(eye)
		if part.is_empty():
			continue
		var color := PLAYING_COLOR if _band.is_playing(part) else SILENT_COLOR
		if _band.is_touching(eye):
			color = TOUCHING_COLOR
		var ring_radius := eye.radius + RING_GAP
		_overlay.draw_arc(eye.global_position, ring_radius, 0.0, TAU, 48, color, 2.0, true)
		var text_at := eye.global_position + Vector2(-ring_radius, ring_radius + 16.0)
		_overlay.draw_string(
			font, text_at, part, HORIZONTAL_ALIGNMENT_CENTER, ring_radius * 2.0, 13, color
		)
