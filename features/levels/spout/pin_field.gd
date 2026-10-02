class_name PinField
extends Node2D
## The pins at the bottom of the spout level, in staggered rows like a
## falling-balls board, each playing its note when something hits it.
##
## Pitch rises left to right across the whole field, not row by row: pins are
## grouped into [i]columns[/i] by x, the staggered rows interleaving so that
## every column is a distinct x, and a [PegScale] gives each column one note.
## Pins in the same column share it. Pins are indexed left to right by x,
## ties broken top to bottom, so pin 0 is the leftmost.
##
## What hits a pin is not this field's business. Version B's balls bounce off
## the [StaticBody2D] every pin carries; version A's droplets look pins up with
## [method pin_at]. Both report a hit through [method hit], which plays the
## note, flashes the pin and emits [signal pin_hit].

## Emitted for every hit that sounds (not those inside a pin's cooldown).
signal pin_hit(pin: int, note: int, strength: float)

const NOTE_NAMES: Array[String] = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
## Seconds a hit's glow takes to fade, and a flip's pop.
const FLASH_SECONDS := 0.45
const FLIP_SECONDS := 0.3

## The rectangle the field fills, in local coordinates.
@export var area: Rect2 = Rect2(0, 0, 1000, 300)
## Rows of pins, top to bottom. Even rows hold [member pins_per_row], odd rows
## one fewer, set in by half a gap.
@export var rows: int = 6
@export var pins_per_row: int = 7
@export var pin_radius: float = 9.0
## The lowest note the leftmost column may play, as MIDI.
@export var low_note: int = 48
## A pin hit again within this many seconds stays quiet, so a stream of fluid
## or a ball rattling on it does not machine-gun.
@export var retrigger_seconds: float = 0.06

@export_group("Physics")
## Physics layer the pins' bodies sit on.
@export_flags_2d_physics var pin_layer: int = 1 << 2
@export var bounce: float = 0.6
@export var friction: float = 0.1

@export_group("Sound")
@export var voices: int = 16
## Seconds a pluck is held before it starts to ring out over the patch's
## release.
@export var hold_seconds: float = 0.04

@export_group("Look")
@export var show_note_names: bool = true

var _positions: Array[Vector2] = []
## Column (index into the scale) of each pin.
var _columns: Array[int] = []
var _column_count := 0
var _scale: PegScale
var _last_hit_usec: Array[int] = []
var _flash: Array[float] = []
## Per column, how far through its flip animation it is (1 just flipped).
var _flip: Array[float] = []
var _bodies: Array[StaticBody2D] = []
var _pluck: Synth
var _sparkle: Synth


func _ready() -> void:
	if _positions.is_empty():
		build()
	_pluck = _make_synth(0.003, 0.9, 0.11)
	_sparkle = _make_synth(0.002, 0.35, 0.035)


func _process(delta: float) -> void:
	var animating := false
	for i in _flash.size():
		if _flash[i] > 0.0:
			_flash[i] = maxf(0.0, _flash[i] - delta / FLASH_SECONDS)
			animating = true
	for i in _flip.size():
		if _flip[i] > 0.0:
			_flip[i] = maxf(0.0, _flip[i] - delta / FLIP_SECONDS)
			animating = true
	if animating or (_scale != null and _scale.is_scrolling()):
		queue_redraw()


## Lay the pins out over [member area] and give each one a body. Called from
## [method _ready]; call again after changing the layout.
func build() -> void:
	for body in _bodies:
		body.queue_free()
	_bodies.clear()
	var layout := layout_pins(area, rows, pins_per_row)
	_positions = layout[0]
	_columns = layout[1]
	_column_count = 0
	for column in _columns:
		_column_count = maxi(_column_count, column + 1)
	_last_hit_usec.resize(_positions.size())
	_last_hit_usec.fill(-1_000_000_000)
	_flash.resize(_positions.size())
	_flash.fill(0.0)
	_flip.resize(_column_count)
	_flip.fill(0.0)
	var material := PhysicsMaterial.new()
	material.bounce = bounce
	material.friction = friction
	for i in _positions.size():
		var body := StaticBody2D.new()
		body.name = "Pin%d" % i
		body.collision_layer = pin_layer
		body.collision_mask = 0
		body.physics_material_override = material
		body.position = _positions[i]
		body.set_meta("pin", i)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = pin_radius
		shape.shape = circle
		body.add_child(shape)
		add_child(body)
		_bodies.append(body)
	if _scale != null:
		_scale.configure(_column_count, low_note)
	queue_redraw()


## Follow [param scale] for every pin's note, configuring it for this field's
## columns.
func bind_scale(scale: PegScale) -> void:
	if _scale != null and _scale.pin_changed.is_connected(_on_pin_changed):
		_scale.pin_changed.disconnect(_on_pin_changed)
	_scale = scale
	_scale.configure(_column_count, low_note)
	_scale.pin_changed.connect(_on_pin_changed)
	queue_redraw()


## Pins' positions and columns for a field of [param row_count] rows over
## [param rect]: [code][positions, columns][/code], both indexed left to right
## by x, ties top to bottom.
static func layout_pins(rect: Rect2, row_count: int, per_row: int) -> Array:
	var gap := rect.size.x / maxf(1.0, per_row - 1)
	var row_gap := rect.size.y / maxf(1.0, row_count - 1)
	var found: Array = []
	for row in row_count:
		var offset := row % 2 == 1
		var count := per_row - 1 if offset else per_row
		for i in count:
			var x := rect.position.x + gap * (i + (0.5 if offset else 0.0))
			var y := rect.position.y + row_gap * row
			# Half-gap units, so staggered columns sort as whole numbers.
			var column := i * 2 + (1 if offset else 0)
			found.append([column, row, Vector2(x, y)])
	found.sort_custom(
		func(a: Array, b: Array): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])
	)
	var positions: Array[Vector2] = []
	var columns: Array[int] = []
	for entry in found:
		positions.append(entry[2])
		columns.append(entry[0])
	return [positions, columns]


func pin_count() -> int:
	return _positions.size()


func column_count() -> int:
	return _column_count


func column_of(pin: int) -> int:
	return _columns[pin]


## A pin's centre, in local coordinates.
func pin_position(pin: int) -> Vector2:
	return _positions[pin]


func note_for(pin: int) -> int:
	return _scale.note_for(_columns[pin]) if _scale != null else -1


## The pin a circle of [param radius] at [param world_position] overlaps, the
## nearest if several, or -1.
func pin_at(world_position: Vector2, radius: float = 0.0) -> int:
	var local := to_local(world_position)
	var best := -1
	var best_distance := pin_radius + radius
	for i in _positions.size():
		var distance := local.distance_to(_positions[i])
		if distance <= best_distance:
			best = i
			best_distance = distance
	return best


## The pin [param body] belongs to, or -1 if it is not one of this field's.
func pin_for_body(body: Node) -> int:
	if body == null or not body.has_meta("pin") or body.get_parent() != self:
		return -1
	return int(body.get_meta("pin"))


## Sound [param pin] at [param strength] (0..1): play its current note,
## flash it, emit [signal pin_hit]. Ignored inside the pin's
## [member retrigger_seconds]. Returns whether it sounded.
## [param now_usec] is for tests; it defaults to the real clock.
func hit(pin: int, strength: float, now_usec: int = -1) -> bool:
	if pin < 0 or pin >= _positions.size() or _scale == null:
		return false
	var now := now_usec if now_usec >= 0 else Time.get_ticks_usec()
	if now - _last_hit_usec[pin] < int(retrigger_seconds * 1_000_000.0):
		return false
	_last_hit_usec[pin] = now
	var note := note_for(pin)
	var velocity := clampf(strength, 0.05, 1.0)
	_flash[pin] = maxf(_flash[pin], 0.35 + 0.65 * velocity)
	_play(note, velocity)
	pin_hit.emit(pin, note, velocity)
	queue_redraw()
	return true


static func note_name(note: int) -> String:
	return "%s%d" % [NOTE_NAMES[posmod(note, 12)], floori(note / 12.0) - 1]


## A pin's hue by pitch class, so the same note reads the same anywhere on the
## field and a new scale visibly changes the colours as it scrolls in.
static func note_color(note: int, brightness: float = 1.0) -> Color:
	var hue := fposmod(posmod(note, 12) * 7.0 / 12.0, 1.0)
	return Color.from_hsv(hue, 0.42, clampf(0.55 + 0.4 * brightness, 0.0, 1.0))


func _play(note: int, velocity: float) -> void:
	if _pluck == null:
		return
	var hz := Band.midi_to_hz(note)
	for synth in [_pluck, _sparkle]:
		var voice: SynthVoice = synth.note_on(hz * (1.0 if synth == _pluck else 2.0), velocity)
		if voice != null and is_inside_tree():
			get_tree().create_timer(hold_seconds).timeout.connect(
				_release.bind(voice, voice.started_usec)
			)


func _release(voice: SynthVoice, started_usec: int) -> void:
	if is_instance_valid(voice) and voice.started_usec == started_usec:
		voice.note_off()


func _make_synth(attack: float, release: float, level: float) -> Synth:
	var patch := SynthPatch.new()
	patch.waveform = SynthWavetable.Waveform.SINE
	patch.attack_seconds = attack
	patch.release_seconds = release
	patch.level = level
	patch.glide_seconds = 0.0
	var synth := Synth.new()
	synth.patch = patch
	synth.polyphony = voices
	add_child(synth)
	return synth


func _on_pin_changed(column: int, _old_note: int, _new_note: int) -> void:
	if column < _flip.size():
		_flip[column] = 1.0
	queue_redraw()


func _draw() -> void:
	if _positions.is_empty():
		return
	var font := ThemeDB.fallback_font
	var scrolling_at := _scale.scroll_position() if _scale != null else -1
	var shimmer := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
	for i in _positions.size():
		var column := _columns[i]
		var at := _positions[i]
		var note := note_for(i)
		var color := note_color(note) if note >= 0 else Color(0.8, 0.8, 0.8)
		var flash := _flash[i]
		var pop := 1.0 + 0.45 * _flip[column]
		if flash > 0.0:
			draw_circle(at, pin_radius * (1.6 + 1.4 * flash), Color(color, 0.22 * flash))
		draw_circle(at, pin_radius * pop, color.lerp(Color.WHITE, flash * 0.6))
		draw_arc(at, pin_radius * pop, 0.0, TAU, 24, Color(0.15, 0.12, 0.1, 0.6), 1.5, true)
		if _scale != null and _scale.pending_for(column) >= 0:
			var waiting := note_color(_scale.pending_for(column))
			var ring := pin_radius + 4.0 + 2.0 * shimmer
			draw_arc(at, ring, 0.0, TAU, 24, Color(waiting, 0.5 + 0.4 * shimmer), 2.0, true)
		if column == scrolling_at:
			draw_arc(at, pin_radius + 9.0, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.5, true)
	if show_note_names and _scale != null:
		var bottom := area.end.y + pin_radius + 22.0
		var gap := area.size.x / maxf(1.0, pins_per_row - 1) * 0.5
		for column in _column_count:
			var note := _scale.note_for(column)
			var x := area.position.x + gap * column
			draw_string(
				font,
				Vector2(x - 20.0, bottom),
				note_name(note),
				HORIZONTAL_ALIGNMENT_CENTER,
				40.0,
				12,
				Color(note_color(note), 0.8)
			)
