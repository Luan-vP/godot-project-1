class_name RenderScale
extends RefCounted
## How finely the expensive full-screen passes draw, against the screen.
##
## On a phone, [code]canvas_items[/code] stretch lays out on a canvas of about
## 1400x648 units but draws every pixel the screen has — 2796x1290 on an iPhone
## 14 Pro Max. Text and lines want that. The painterly fluid and the floaters'
## bokeh do not: they run long shaders per pixel and are soft to begin with.
## Those draw offscreen at a fraction of the screen's resolution and are
## stretched back up with linear filtering.

## Screen pixels per offscreen pixel along each axis, on a phone. 4 draws one
## pixel in sixteen.
const MOBILE_UPSCALE := 4


## The upscale in effect: [constant MOBILE_UPSCALE] on a phone, 1 elsewhere.
static func factor() -> int:
	return MOBILE_UPSCALE if OS.has_feature("mobile") else 1


## Size of an offscreen buffer for [param canvas_size] units of [param
## viewport]'s canvas, at the upscale in effect.
static func buffer_size_for(viewport: Viewport, canvas_size: Vector2) -> Vector2i:
	return buffer_size(canvas_size, viewport.get_final_transform().get_scale().x, factor())


## Size of an offscreen buffer covering [param canvas_size] units, where the
## screen has [param pixels_per_unit] pixels to a unit and the buffer one pixel
## to every [param upscale] of the screen's. Never smaller than a pixel. Kept
## pure so the arithmetic is tested without a phone.
static func buffer_size(canvas_size: Vector2, pixels_per_unit: float, upscale: int) -> Vector2i:
	var pixels := (canvas_size * pixels_per_unit / float(maxi(upscale, 1))).ceil()
	return Vector2i(maxi(int(pixels.x), 1), maxi(int(pixels.y), 1))
