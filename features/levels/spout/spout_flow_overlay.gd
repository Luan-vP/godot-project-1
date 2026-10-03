class_name SpoutFlowOverlay
extends Node2D
## Rings round the spout showing how a touch's distance sets the pour: one
## band per [SpoutFlow] step, labelled with its droplets a bar, the band under
## the finger lit, a line from the nozzle to the finger, and a readout by the
## finger. It fades in while a touch (or RT) is pouring and out when it stops,
## so it is there to read exactly when it matters and gone otherwise.
##
## A pad player sees it too, faintly — the ring their trigger depth has
## reached — so the two ways of pouring read as one scale.

## Seconds to fade in, and out.
const FADE_IN := 0.12
const FADE_OUT := 0.5
## Extra angle either side of the spout's swing the rings are drawn over.
const MARGIN := deg_to_rad(18.0)
const INK := Color(0.95, 0.92, 0.86)
const LIT := Color(1.0, 0.86, 0.55)

## Centre of the rings: the spout's pivot, in this node's parent's space.
var pivot := Vector2.ZERO
## Half the angle the spout swings through.
var max_aim := deg_to_rad(60.0)
## Radii the bands run between: see [method SpoutFlow.step_for_distance].
var inner := 120.0
var reach := 500.0

var _step := -1
var _touch := Vector2.ZERO
var _touching := false
var _alpha := 0.0
## 1 just after a droplet leaves, fading — the lit ring breathes with the beat.
var _pulse := 0.0


## What to show this frame: the [param step] pouring (-1 for none), and
## whether it comes from a touch at [param touch_point].
func show_flow(step: int, touching: bool, touch_point: Vector2 = Vector2.ZERO) -> void:
	_step = step
	_touching = touching
	_touch = touch_point


## A droplet just left: flash the lit ring.
func pulse() -> void:
	_pulse = 1.0


func visibility() -> float:
	return _alpha


func _process(delta: float) -> void:
	var target := 0.0
	if _step >= 0:
		target = 1.0 if _touching else 0.35
	var rate := 1.0 / (FADE_IN if target > _alpha else FADE_OUT)
	_alpha = move_toward(_alpha, target, rate * delta)
	_pulse = maxf(0.0, _pulse - delta * 4.0)
	if _alpha > 0.0:
		queue_redraw()


func _draw() -> void:
	if _alpha <= 0.001:
		return
	var font := ThemeDB.fallback_font
	# draw_arc measures from +x, clockwise on screen; straight down is PI/2.
	var start := PI / 2.0 - max_aim - MARGIN
	var end := PI / 2.0 + max_aim + MARGIN
	var count := SpoutFlow.STEPS.size()
	for step in count:
		var radius := SpoutFlow.band_outer(step, inner, reach)
		var lit := step == _step
		var color := LIT if lit else INK
		var alpha := (0.75 + 0.25 * _pulse if lit else 0.16) * _alpha
		var width := 3.0 + 3.0 * _pulse if lit else 1.2
		if lit:
			var mid := radius - (reach - inner) / count * 0.5
			var band := (reach - inner) / count
			draw_arc(pivot, mid, start, end, 64, Color(LIT, 0.12 * _alpha), band, true)
		draw_arc(pivot, radius, start, end, 64, Color(color, alpha), width, true)
		# The label sits just outside the swing on the right, on its ring.
		var label_at := pivot + Vector2.from_angle(start) * (radius - 6.0)
		draw_string(
			font,
			label_at + Vector2(4.0, 4.0),
			str(SpoutFlow.per_bar(step)),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			15 if lit else 11,
			Color(color, (0.95 if lit else 0.4) * _alpha)
		)
	if _touching:
		draw_dashed_line(pivot, _touch, Color(LIT, 0.45 * _alpha), 2.0, 8.0, true)
		draw_circle(_touch, 22.0 + 6.0 * _pulse, Color(LIT, 0.18 * _alpha))
		draw_arc(_touch, 22.0 + 6.0 * _pulse, 0.0, TAU, 32, Color(LIT, 0.8 * _alpha), 2.0, true)
		draw_string(
			font,
			_touch + Vector2(30.0, -10.0),
			"%d / bar" % SpoutFlow.per_bar(_step),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Color(LIT, _alpha)
		)
