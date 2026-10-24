class_name PinField
extends Node2D
## The pins at the bottom of the spout level, each playing its note when
## something hits it. Two layouts ([member layout]):
##
## [b]Staggered[/b]: rows like a falling-balls board. Pitch rises left to
## right across the whole field, not row by row: pins are grouped into
## [i]columns[/i] by x, the staggered rows interleaving so that every column
## is a distinct x, and a [PegScale] gives each column one note. Pins in the
## same column share it.
##
## [b]Fretboard[/b]: a scale diagram on a guitar's [member strings] strings
## (all six by default, counting down from the high e), highest on top as in
## tab, from [member first_fret] for
## [member frets] frets. Every string and fret is a [i]site[/i] with its own
## fixed note, and a [FretboardScale] says which sites hold a pin: those in
## the scale. A change of key or scale moves pins rather than retuning them.
## The columns are the frets.
##
## Either way, pins are indexed left to right by x, ties broken top to
## bottom, so pin 0 is the leftmost. In the fretboard layout a site with no
## pin is still indexed; [method is_live] says whether a pin is there.
##
## What hits a pin is not this field's business. Version B's balls bounce off
## the [StaticBody2D] every pin carries; version A's droplets look pins up with
## [method pin_at]. Both report a hit through [method hit], which plays the
## note, flashes the pin and emits [signal pin_hit].
##
## A pin can also [method pop]: it bursts and is gone — not drawn, not
## collided with, not found by [method pin_at] — until [method restore]
## brings it back. Version C pops each pin it plays.
##
## Each pin is drawn as one of the hand-drawn [constant DUCKS], sitting on a
## disc of its note's colour.

## Emitted for every hit that sounds (not those inside a pin's cooldown).
signal pin_hit(pin: int, note: int, strength: float)

enum Layout { STAGGERED, FRETBOARD }

const NOTE_NAMES: Array[String] = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
## Seconds a hit's glow takes to fade, and a flip's pop.
const FLASH_SECONDS := 0.45
const FLIP_SECONDS := 0.3
const POP_SECONDS := 0.25
## The hand-drawn ducks the pins are drawn as, taken in turn along the field.
const DUCKS: Array[Texture2D] = [
	preload("res://features/levels/spout/ducks/duck_1.png"),
	preload("res://features/levels/spout/ducks/duck_2.png"),
	preload("res://features/levels/spout/ducks/duck_3.png"),
	preload("res://features/levels/spout/ducks/duck_4.png"),
	preload("res://features/levels/spout/ducks/duck_5.png"),
	preload("res://features/levels/spout/ducks/duck_6.png"),
	preload("res://features/levels/spout/ducks/duck_7.png"),
]

## The rectangle the field fills, in local coordinates.
@export var area: Rect2 = Rect2(0, 0, 1000, 300)
## Staggered rows, or a scale diagram on a guitar's strings. Set before the
## field enters the tree, or call [method build] after.
@export var layout: Layout = Layout.STAGGERED
@export var pin_radius: float = 9.0
## A duck's longest side, in pixels, before a flip's pop.
@export var duck_size: float = 32.0
## A pin hit again within this many seconds stays quiet, so a stream of fluid
## or a ball rattling on it does not machine-gun.
@export var retrigger_seconds: float = 0.06

@export_group("Staggered")
## Rows of pins, top to bottom. Even rows hold [member pins_per_row], odd rows
## one fewer, set in by half a gap.
@export var rows: int = 4
@export var pins_per_row: int = 7
## The lowest note the leftmost column may play, as MIDI: D4, so the field
## sits in the middle of the range rather than down in the bass.
@export var low_note: int = 62

@export_group("Fretboard")
## How many strings, counting down from the high e of standard tuning: all
## six by default.
@export_range(1, 6) var strings: int = 6
## The fret of the leftmost column, and how many frets: 9 to 20. An even
## number, so the middle of the field, under the spout's pivot, falls on a
## fret wire between two columns rather than on a column of pins: a straight
## drop splits either side and runs down to the low strings instead of
## stopping on the top pin.
@export var first_fret: int = 9
@export var frets: int = 12

@export_group("Physics")
## Physics layer the pins' bodies sit on.
@export_flags_2d_physics var pin_layer: int = 1 << 2
@export var bounce: float = 0.6
@export var friction: float = 0.1

@export_group("Sound")
@export var voices: int = 16
## Levels of the sine pluck and its octave sparkle: well up in the band's mix
## (its parts sit at 0.05-0.16), so every pin a player strikes reads over it.
@export var pluck_level: float = 0.2
@export var sparkle_level: float = 0.065
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
## Whether each pin is there at all: always, staggered; on a fretboard, only
## at sites in the scale.
var _present: Array[bool] = []
var _popped: Array[bool] = []
## Per pin, how far through its burst it is (1 just popped).
var _pop: Array[float] = []
var _pluck: Synth
var _sparkle: Synth


func _ready() -> void:
	if _positions.is_empty():
		build()
	_pluck = _make_synth(0.003, 0.9, pluck_level)
	_sparkle = _make_synth(0.002, 0.35, sparkle_level)


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
	for i in _pop.size():
		if _pop[i] > 0.0:
			_pop[i] = maxf(0.0, _pop[i] - delta / POP_SECONDS)
			animating = true
	if animating or (_scale != null and _scale.is_scrolling()):
		queue_redraw()


## Lay the pins out over [member area] and give each one a body. Called from
## [method _ready]; call again after changing the layout.
func build() -> void:
	for body in _bodies:
		body.queue_free()
	_bodies.clear()
	var laid_out := (
		layout_fretboard(area, strings, frets)
		if layout == Layout.FRETBOARD
		else layout_pins(area, rows, pins_per_row)
	)
	_positions = laid_out[0]
	_columns = laid_out[1]
	_column_count = 0
	for column in _columns:
		_column_count = maxi(_column_count, column + 1)
	_last_hit_usec.resize(_positions.size())
	_last_hit_usec.fill(-1_000_000_000)
	_flash.resize(_positions.size())
	_flash.fill(0.0)
	_flip.resize(_column_count)
	_flip.fill(0.0)
	_present.resize(_positions.size())
	_present.fill(true)
	_popped.resize(_positions.size())
	_popped.fill(false)
	_pop.resize(_positions.size())
	_pop.fill(0.0)
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
		_configure_scale()
	queue_redraw()


## A scale of the right kind for [member layout], for [method bind_scale]: a
## [FretboardScale] for the fretboard, a [PegScale] otherwise.
func new_scale() -> PegScale:
	return FretboardScale.new() if layout == Layout.FRETBOARD else PegScale.new()


## Follow [param peg_scale] for every pin's note, configuring it for this
## field's columns (or, on a fretboard, its strings and frets).
func bind_scale(peg_scale: PegScale) -> void:
	if _scale != null and _scale.pin_changed.is_connected(_on_pin_changed):
		_scale.pin_changed.disconnect(_on_pin_changed)
	_scale = peg_scale
	_configure_scale()
	_scale.pin_changed.connect(_on_pin_changed)
	queue_redraw()


func _configure_scale() -> void:
	var fretboard := _scale as FretboardScale
	if layout == Layout.FRETBOARD and fretboard != null:
		fretboard.configure_fretboard(strings, first_fret, frets)
	else:
		_scale.configure(_column_count, low_note)
	_sync_presence()


## Match every pin's presence, and its body, to the scale.
func _sync_presence() -> void:
	for pin in _positions.size():
		_present[pin] = layout != Layout.FRETBOARD or note_for(pin) >= 0
		_refresh_body(pin)


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


## Sites' positions and columns for a fretboard of [param string_count]
## strings and [param fret_count] frets over [param rect]:
## [code][positions, columns][/code], fret by fret left to right, the top
## string first in each — the order [FretboardScale] indexes them in.
static func layout_fretboard(rect: Rect2, string_count: int, fret_count: int) -> Array:
	var gap := rect.size.x / maxf(1.0, fret_count - 1)
	var string_gap := rect.size.y / maxf(1.0, string_count - 1)
	var positions: Array[Vector2] = []
	var columns: Array[int] = []
	for column in fret_count:
		for row in string_count:
			positions.append(rect.position + Vector2(gap * column, string_gap * row))
			columns.append(column)
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


## The note [param pin] plays: its column's on the staggered layout, its
## site's on a fretboard (-1 there for a site with no pin).
func note_for(pin: int) -> int:
	if _scale == null:
		return -1
	return _scale.note_for(pin if layout == Layout.FRETBOARD else _columns[pin])


## Whether [param pin] is there to be hit: present in the layout (on a
## fretboard, in the scale) and not popped.
func is_live(pin: int) -> bool:
	return pin >= 0 and pin < _present.size() and _present[pin] and not _popped[pin]


## Pins there to be hit right now, by index.
func live_pins() -> Array[int]:
	var live: Array[int] = []
	for pin in _positions.size():
		if is_live(pin):
			live.append(pin)
	return live


## The pin a circle of [param radius] at [param world_position] overlaps, the
## nearest if several, or -1.
func pin_at(world_position: Vector2, radius: float = 0.0) -> int:
	var local := to_local(world_position)
	var best := -1
	var best_distance := pin_radius + radius
	for i in _positions.size():
		if not is_live(i):
			continue
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
	if not is_live(pin) or _scale == null:
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


## Burst [param pin] and take it away until [method restore]: it stops
## drawing and stops colliding. Safe to call from a physics callback.
func pop(pin: int) -> void:
	if pin < 0 or pin >= _positions.size() or _popped[pin]:
		return
	_popped[pin] = true
	_pop[pin] = 1.0
	_refresh_body(pin)
	queue_redraw()


## Bring a popped [param pin] back.
func restore(pin: int) -> void:
	if pin < 0 or pin >= _positions.size() or not _popped[pin]:
		return
	_popped[pin] = false
	_pop[pin] = 0.0
	_refresh_body(pin)
	queue_redraw()


## Bring every popped pin back.
func restore_all() -> void:
	for pin in _positions.size():
		restore(pin)


func is_popped(pin: int) -> bool:
	return pin >= 0 and pin < _popped.size() and _popped[pin]


func popped_count() -> int:
	return _popped.count(true)


## Collide only while the pin is live. Deferred, so safe from a physics
## callback.
func _refresh_body(pin: int) -> void:
	if pin < _bodies.size():
		var shape := _bodies[pin].get_child(0) as CollisionShape2D
		shape.set_deferred("disabled", not is_live(pin))


static func note_name(note: int) -> String:
	return "%s%d" % [NOTE_NAMES[posmod(note, 12)], floori(note / 12.0) - 1]


## A pin's colour by pitch class ([method ArtPalette.pin]), so the same note
## reads the same anywhere on the field and a new scale visibly changes the
## colours as it scrolls in.
static func note_color(note: int, brightness: float = 1.0) -> Color:
	return ArtPalette.pin(note, brightness)


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


## [param index] is a column on the staggered layout, a site on a fretboard,
## where a note of -1 is a site losing its pin.
func _on_pin_changed(index: int, _old_note: int, new_note: int) -> void:
	var column := index
	if layout == Layout.FRETBOARD:
		if index >= _present.size():
			return
		column = _columns[index]
		_present[index] = new_note >= 0
		_refresh_body(index)
	if column < _flip.size():
		_flip[column] = 1.0
	queue_redraw()


func _draw() -> void:
	if _positions.is_empty():
		return
	var fretboard := layout == Layout.FRETBOARD
	if fretboard:
		_draw_neck()
	var scrolling_at := _scale.scroll_position() if _scale != null else -1
	var shimmer := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
	for i in _positions.size():
		var column := _columns[i]
		var at := _positions[i]
		var note := note_for(i)
		var color := note_color(note) if note >= 0 else ArtPalette.PIN_BLANK
		if not _present[i]:
			# A site the scroll is about to give a pin shimmers in its note.
			if fretboard and _scale != null and _scale.will_change(i):
				var coming := note_color(_scale.pending_for(i))
				var ring := pin_radius * (0.6 + 0.3 * shimmer)
				draw_arc(at, ring, 0.0, TAU, 24, Color(coming, 0.4 + 0.4 * shimmer), 2.0, true)
			continue
		if _popped[i]:
			_draw_popped(at, color, _pop[i])
			continue
		var flash := _flash[i]
		var pop := 1.0 + 0.45 * _flip[column]
		if flash > 0.0:
			draw_circle(at, pin_radius * (1.6 + 1.4 * flash), Color(color, 0.22 * flash))
		var lit := color.lerp(ArtPalette.LIGHT, flash * 0.6)
		draw_circle(at, pin_radius * 1.4 * pop, Color(lit, 0.85))
		_draw_duck(i, at, pop, flash)
		if fretboard:
			# Roots ringed, as a scale diagram marks them.
			if _scale != null and posmod(note - _scale.root(), 12) == 0:
				draw_arc(at, pin_radius + 3.5, 0.0, TAU, 24, Color(color, 0.85), 2.0, true)
			# A pin the scroll is about to take away flickers.
			if _scale != null and _scale.will_change(i):
				var fading := Color(ArtPalette.LIGHT, 0.3 + 0.4 * shimmer)
				draw_arc(at, pin_radius + 4.0 + 2.0 * shimmer, 0.0, TAU, 24, fading, 1.5, true)
		elif _scale != null and _scale.pending_for(column) >= 0:
			var waiting := note_color(_scale.pending_for(column))
			var ring := pin_radius + 4.0 + 2.0 * shimmer
			draw_arc(at, ring, 0.0, TAU, 24, Color(waiting, 0.5 + 0.4 * shimmer), 2.0, true)
		if column == scrolling_at:
			draw_arc(at, pin_radius + 9.0, 0.0, TAU, 24, Color(ArtPalette.LIGHT, 0.5), 1.5, true)
	if fretboard:
		_draw_fretboard_labels()
	elif show_note_names and _scale != null:
		_draw_note_names()


func _draw_note_names() -> void:
	var font := UiTheme.hud_font()
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
			note_color(note, 1.0).lightened(0.3)
		)


## Pin [param i]'s duck, centred on [param at], scaled up by [param pop] and
## lit by [param flash].
func _draw_duck(i: int, at: Vector2, pop: float, flash: float) -> void:
	var duck := DUCKS[i % DUCKS.size()]
	var size := duck.get_size()
	var fit := duck_size * pop / maxf(size.x, size.y)
	var lit := Color(ArtPalette.LIGHT * (1.0 + 0.6 * flash), 1.0)
	draw_set_transform(at, 0.0, Vector2(fit, fit))
	draw_texture(duck, -size * 0.5, lit)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## A popped pin: a ring bursting outward as it goes, then a faint dotted
## mark where it will come back.
func _draw_popped(at: Vector2, color: Color, burst: float) -> void:
	if burst > 0.0:
		var radius := pin_radius * (1.0 + 1.6 * (1.0 - burst))
		draw_arc(
			at, radius, 0.0, TAU, 24, Color(color.lerp(ArtPalette.LIGHT, 0.5), burst), 3.0, true
		)
	var ghost := Color(ArtPalette.LIGHT, 0.18)
	for k in 8:
		var angle := TAU * k / 8.0
		draw_arc(at, pin_radius, angle, angle + TAU / 16.0, 3, ghost, 1.5, true)


## The neck behind a fretboard: a line per string, heavier for the lower
## ones, a fret wire between every column, and the inlay dots below.
func _draw_neck() -> void:
	var gap := _fret_gap()
	var left := area.position.x - gap * 0.5
	var right := area.end.x + gap * 0.5
	var string_gap := area.size.y / maxf(1.0, strings - 1)
	for row in strings:
		var y := area.position.y + string_gap * row
		var width := 1.0 + 0.5 * row
		draw_line(Vector2(left, y), Vector2(right, y), Color(ArtPalette.LIGHT, 0.28), width, true)
	var top := area.position.y - pin_radius
	var bottom := area.end.y + pin_radius
	for wire in frets + 1:
		var x := left + gap * wire
		draw_line(Vector2(x, top), Vector2(x, bottom), Color(ArtPalette.LIGHT, 0.14), 2.0, true)
	# Inlays as on a real neck: one dot at 3, 5, 7 and 9 (and an octave on),
	# two at 12 and 24.
	var dot_y := bottom + 9.0
	for column in frets:
		var fret := first_fret + column
		var x := area.position.x + gap * column
		var dot := Color(ArtPalette.LIGHT, 0.5)
		if posmod(fret, 12) == 0 and fret > 0:
			draw_circle(Vector2(x - 6.0, dot_y), 3.5, dot)
			draw_circle(Vector2(x + 6.0, dot_y), 3.5, dot)
		elif posmod(fret, 12) in [3, 5, 7, 9]:
			draw_circle(Vector2(x, dot_y), 3.5, dot)


## Fret numbers under the columns and string names left of the strings.
func _draw_fretboard_labels() -> void:
	var font := UiTheme.hud_font()
	var gap := _fret_gap()
	var ink := Color(ArtPalette.LIGHT, 0.55)
	var bottom := area.end.y + pin_radius + 32.0
	for column in frets:
		var x := area.position.x + gap * column
		var label := str(first_fret + column)
		draw_string(
			font, Vector2(x - 20.0, bottom), label, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, ink
		)
	var string_gap := area.size.y / maxf(1.0, strings - 1)
	for row in strings:
		var y := area.position.y + string_gap * row
		var label := GuitarDiagrams.STRING_NAMES[row]
		var at := Vector2(area.position.x - gap * 0.5 - 22.0, y + 5.0)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_RIGHT, 14.0, 13, ink)


func _fret_gap() -> float:
	return area.size.x / maxf(1.0, frets - 1)
