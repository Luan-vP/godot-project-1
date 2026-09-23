extends "res://features/levels/secret_eyes/fluid_demo.gd"
## The eye tank, with a band in it: each eye plays one part of the music while
## it floats clear of the walls. Tilt (arrows) or stir to push eyes against a
## wall and strip the arrangement back; let them drift free to fill it out.
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

## Countdown ring while a part is about to start (white) or stop (red) — see
## [enum EyeBand.Pending].
const PENDING_START_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const PENDING_STOP_COLOR := Color(0.95, 0.25, 0.2, 0.95)
const PENDING_RING_WIDTH := 3.0

var _band: EyeBand
var _overlay: Node2D
var _parts_label: Label


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
	add_child(layer)


func _physics_process(delta: float) -> void:
	var centre := _simulation.get_world_rect().get_center()
	for child in get_children():
		var eye := child as FloatyEye
		if eye != null:
			eye.velocity += (centre - eye.global_position) * CENTRE_PULL * delta


func _process(delta: float) -> void:
	super(delta)
	_overlay.queue_redraw()
	var parts: PackedStringArray = []
	for part in EyeBand.PARTS:
		var mark := "●" if _band.is_playing(part) else "○"
		if _band.is_playing(part) != _band.wants_part(part):
			mark = "◐"
		parts.append("%s %s" % [mark, part])
	_parts_label.text = (
		"♪ %s · %s\n" % [_band.song_title(), _band.current_section()]
		+ "   ".join(parts)
		+ "      keep eyes off the walls to hear them"
	)


## A ring round each eye: bright while its part plays, red while it is pressed
## against a wall, faint while it waits silent. Its part is written beneath.
## While a part is due to start or stop at the next bar, the ring becomes a
## countdown instead — white or red, its arc shrinking to nothing as the bar
## line arrives (see [method EyeBand.pending]).
func _draw_rings() -> void:
	var font := ThemeDB.fallback_font
	var seconds_per_bar := AudioManager.get_music_clock().seconds_per_bar()
	var countdown := EyeBand.countdown_fraction(
		AudioManager.get_seconds_until_next_bar(), seconds_per_bar
	)
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
		var pending := _band.pending(part)
		if pending != EyeBand.Pending.NONE:
			color = (
				PENDING_START_COLOR
				if pending == EyeBand.Pending.STARTING
				else PENDING_STOP_COLOR
			)
			var sweep := TAU * countdown
			_overlay.draw_arc(
				eye.global_position,
				ring_radius,
				-PI / 2.0,
				-PI / 2.0 + sweep,
				48,
				color,
				PENDING_RING_WIDTH,
				true
			)
		else:
			_overlay.draw_arc(eye.global_position, ring_radius, 0.0, TAU, 48, color, 2.0, true)
		var text_at := eye.global_position + Vector2(-ring_radius, ring_radius + 16.0)
		_overlay.draw_string(
			font, text_at, part, HORIZONTAL_ALIGNMENT_CENTER, ring_radius * 2.0, 13, color
		)
