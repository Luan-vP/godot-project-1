class_name DrumPads
extends RefCounted
## Where the rhythm level's three drums sit: a ring in a corner each, the
## kick bottom left, the snare bottom right and the hi-hat top right. A tap
## inside a ring plays that drum.
##
## Pure layout, no nodes, so it is tested without a screen: positions are in
## canvas units for a canvas of the given size, inset by the safe area (the
## phone's island and rounded corners), and the hi-hat drops below the corner
## menu's button ([GameMenu]).
##
## Each drum is marked the same way everywhere it is drawn, on its ring and on
## the dial: the kick a square, the snare a dash, the hi-hat a dot.

enum Pad { KICK, SNARE, HAT }

## Every pad, in the order they are drawn and read.
const ALL: Array[int] = [Pad.KICK, Pad.SNARE, Pad.HAT]

## A ring's radius, as a share of the screen's shorter side.
const REACH := 0.13
## Space between a ring and the edge of the safe area.
const MARGIN := 20.0
## Room left above the hi-hat for the corner menu's button and its margin.
const MENU_CLEARANCE := 76.0
## A tap this far outside a ring, as a share of its radius, still counts: a
## thumb is not a stylus.
const SLOP := 1.15


static func radius(screen: Vector2) -> float:
	return minf(screen.x, screen.y) * REACH


## The centre of [param pad]'s ring on a canvas of [param screen], inset by
## [param insets] (left, top, right, bottom, as [method SafeArea.insets]
## gives them).
static func centre(pad: int, screen: Vector2, insets: Vector4 = Vector4.ZERO) -> Vector2:
	var reach := radius(screen)
	var left := insets.x + MARGIN + reach
	var right := screen.x - insets.z - MARGIN - reach
	var bottom := screen.y - insets.w - MARGIN - reach
	var top := insets.y + MENU_CLEARANCE + reach
	match pad:
		Pad.KICK:
			return Vector2(left, bottom)
		Pad.SNARE:
			return Vector2(right, bottom)
		_:
			return Vector2(right, top)


## The pad whose ring holds [param point], or -1 for none.
static func pad_at(point: Vector2, screen: Vector2, insets: Vector4 = Vector4.ZERO) -> int:
	var reach := radius(screen) * SLOP
	for pad in ALL:
		if point.distance_to(centre(pad, screen, insets)) <= reach:
			return pad
	return -1


static func name_of(pad: int) -> String:
	match pad:
		Pad.KICK:
			return "kick"
		Pad.SNARE:
			return "snare"
		_:
			return "hi-hat"


## The colour [param pad] is drawn in, on its ring and on the dial.
static func color_of(pad: int) -> Color:
	match pad:
		Pad.KICK:
			return UiTokens.EMBER
		Pad.SNARE:
			return UiTokens.RUNE
		_:
			return UiTokens.SIGIL


## Draw [param pad]'s mark, [param size] across, centred on [param at] and
## turned to point along [param along] (a dash lies along it): the kick a
## square, the snare a dash, the hi-hat a dot.
static func draw_mark(
	canvas: CanvasItem, pad: int, at: Vector2, along: Vector2, size: float, color: Color
) -> void:
	match pad:
		Pad.KICK:
			var half := size * 0.5
			var side := along.orthogonal()
			var corners := PackedVector2Array(
				[
					at + (along + side) * half,
					at + (along - side) * half,
					at - (along + side) * half,
					at - (along - side) * half,
				]
			)
			canvas.draw_colored_polygon(corners, color)
		Pad.SNARE:
			var half := along * size * 0.75
			canvas.draw_line(at - half, at + half, color, size * 0.35, true)
		_:
			canvas.draw_circle(at, size * 0.45, color)
