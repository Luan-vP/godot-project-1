class_name ArcaneBackdrop
extends Control
## The menus' ground: a violet void, a lattice of faint points, a great sigil
## turning slowly off to one side, and a scan line sweeping down the screen.
##
## Everything is drawn, nothing loaded, and all of it in [UiTokens] colours.
## It only animates while it is visible, so a menu hidden behind a running
## demo costs nothing.

## Distance between lattice points.
const LATTICE := 32.0
## The sigil's radius, as a share of the screen's shorter side.
const SIGIL_SCALE := 0.44
## Where the sigil sits, as a share of the screen.
const SIGIL_CENTRE := Vector2(0.8, 0.56)
## Marks around the sigil's outer ring, and how many of them are long.
const TICKS := 72
const LONG_TICK_EVERY := 6
## Short dashes on the code ring, read off a fixed pattern so they are
## stable from frame to frame.
const CODE_MARKS := 48
const CODE_PATTERN := [3, 1, 2, 1, 1, 3, 2, 2, 1, 1, 3, 1, 2, 3, 1, 2]

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	_draw_void()
	_draw_lattice()
	_draw_sigil()
	_draw_scan()


func _draw_void() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var points := PackedVector2Array(
		[rect.position, Vector2(rect.end.x, 0.0), rect.end, Vector2(0.0, rect.end.y)]
	)
	var colours := PackedColorArray(
		[UiTokens.VOID, UiTokens.VOID, UiTokens.VOID_DEEP, UiTokens.VOID_DEEP]
	)
	draw_polygon(points, colours)


func _draw_lattice() -> void:
	var dot := UiTokens.LINE
	dot.a = 0.55
	var y := LATTICE * 0.5
	while y < size.y:
		var x := LATTICE * 0.5
		while x < size.x:
			draw_rect(Rect2(x, y, 1.0, 1.0), dot)
			x += LATTICE
		y += LATTICE


func _draw_sigil() -> void:
	var centre := size * SIGIL_CENTRE
	var radius := minf(size.x, size.y) * SIGIL_SCALE
	var turn := _time * UiTokens.SIGIL_RPM / 60.0 * TAU
	var faint := _with_alpha(UiTokens.SIGIL, 0.14)
	var fainter := _with_alpha(UiTokens.SIGIL, 0.08)
	var glint := _with_alpha(UiTokens.RUNE, 0.16)

	draw_arc(centre, radius, 0.0, TAU, 160, faint, 1.0, true)
	draw_arc(centre, radius * 0.94, 0.0, TAU, 160, fainter, 1.0, true)
	for i in TICKS:
		var angle := turn + TAU * i / TICKS
		var long := i % LONG_TICK_EVERY == 0
		var inner := radius * (0.9 if long else 0.94)
		var direction := Vector2.from_angle(angle)
		draw_line(centre + direction * inner, centre + direction * radius, faint, 1.0, true)

	# The code ring, turning the other way: dashes of varying length.
	var code_radius := radius * 0.78
	for i in CODE_MARKS:
		var length: int = CODE_PATTERN[i % CODE_PATTERN.size()]
		var start := -turn * 1.6 + TAU * i / CODE_MARKS
		var sweep := TAU / CODE_MARKS * 0.22 * length
		draw_arc(centre, code_radius, start, start + sweep, 6, glint, 2.0, true)

	# Two triangles make a hexagram, inside a ring, turning slowly.
	var star_radius := radius * 0.6
	for offset in [0.0, PI]:
		var points := PackedVector2Array()
		for k in 4:
			points.append(
				centre + Vector2.from_angle(turn * 0.5 + offset + TAU * k / 3.0) * star_radius
			)
		draw_polyline(points, faint, 1.0, true)
	draw_arc(centre, star_radius, 0.0, TAU, 120, fainter, 1.0, true)
	draw_arc(centre, radius * 0.3, 0.0, TAU, 80, faint, 1.0, true)

	# A bright node where each point of the star meets the ring.
	for k in 6:
		var at := centre + Vector2.from_angle(turn * 0.5 + TAU * k / 6.0) * star_radius
		_draw_diamond(at, 4.0, _with_alpha(UiTokens.RUNE, 0.3))


func _draw_scan() -> void:
	var phase := fmod(_time / UiTokens.SCAN_SECONDS, 1.0)
	var y := phase * size.y
	var band := 90.0
	var steps := 6
	for i in steps:
		var alpha := 0.035 * (1.0 - float(i) / steps)
		draw_rect(
			Rect2(0.0, y - band * (i + 1) / steps, size.x, band / steps),
			_with_alpha(UiTokens.RUNE, alpha)
		)
	draw_line(Vector2(0.0, y), Vector2(size.x, y), _with_alpha(UiTokens.RUNE, 0.12), 1.0)


func _draw_diamond(at: Vector2, half: float, colour: Color) -> void:
	var points := PackedVector2Array(
		[
			at + Vector2(0, -half),
			at + Vector2(half, 0),
			at + Vector2(0, half),
			at + Vector2(-half, 0)
		]
	)
	draw_colored_polygon(points, colour)


static func _with_alpha(colour: Color, alpha: float) -> Color:
	return Color(colour, alpha)
