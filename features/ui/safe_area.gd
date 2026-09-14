class_name SafeArea
extends RefCounted
## The part of the screen nothing on a phone covers, in canvas units.
##
## An iPhone's Dynamic Island, rounded corners and home indicator all sit
## inside the window, so a label placed at the top-left of the canvas lands
## under the island. The OS reports the uncovered region in window pixels; the
## game lays out in canvas units, which differ from pixels whenever the stretch
## mode scales the canvas (on phones it does, by about 2.4). This converts one
## to the other.
##
## On a desktop the reported area is the usable part of the whole monitor, in
## screen coordinates, and says nothing about the window — so outside the
## [code]mobile[/code] feature tag the safe area is simply the whole canvas.


## The safe region of [param viewport]'s canvas, in canvas units.
static func canvas_rect(viewport: Viewport) -> Rect2:
	var canvas := viewport.get_visible_rect()
	if not OS.has_feature("mobile"):
		return canvas
	var window := Vector2(DisplayServer.window_get_size())
	return to_canvas(Rect2(DisplayServer.get_display_safe_area()), window, canvas.size)


## Map a safe area given in window pixels onto a canvas of [param canvas_size]
## that fills a window of [param window_size]. Kept pure so the arithmetic is
## tested without a phone.
##
## The result is clipped to the canvas: a platform that reports a safe area
## larger than the window, or none at all, must not push content off screen.
static func to_canvas(safe_pixels: Rect2, window_size: Vector2, canvas_size: Vector2) -> Rect2:
	var whole := Rect2(Vector2.ZERO, canvas_size)
	if window_size.x <= 0.0 or window_size.y <= 0.0 or not safe_pixels.has_area():
		return whole
	var scale := canvas_size / window_size
	var mapped := Rect2(safe_pixels.position * scale, safe_pixels.size * scale)
	var clipped := whole.intersection(mapped)
	return clipped if clipped.has_area() else whole


## How far each edge of [param safe] sits in from the edges of a canvas of
## [param canvas_size], as left, top, right, bottom.
static func insets(safe: Rect2, canvas_size: Vector2) -> Vector4:
	return Vector4(
		safe.position.x,
		safe.position.y,
		canvas_size.x - safe.end.x,
		canvas_size.y - safe.end.y,
	)


## Shrink a full-rect [param control] to the safe area, so everything laid out
## inside it clears the island and the home indicator.
static func fit_control(control: Control) -> void:
	var safe := canvas_rect(control.get_viewport())
	var edges := insets(safe, control.get_viewport().get_visible_rect().size)
	control.offset_left = edges.x
	control.offset_top = edges.y
	control.offset_right = -edges.z
	control.offset_bottom = -edges.w


## Shift everything on [param layer] down and right by the safe area's
## top-left, for overlays that place labels at fixed canvas positions.
static func offset_layer(layer: CanvasLayer, viewport: Viewport) -> void:
	layer.offset = canvas_rect(viewport).position


## Width a label starting [param margin] in from the safe area's left edge can
## use before it runs off the right.
static func line_width(viewport: Viewport, margin: float) -> float:
	return maxf(canvas_rect(viewport).size.x - margin * 2.0, 0.0)
