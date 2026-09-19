extends Node2D
## Manual test bed for [CannyEdgeSource]: draws a synthetic panorama flat and
## overlays every traced run it finds, so a threshold can be tuned by eye.
##
## The issue this implements calls a debug overlay "worth more than any unit
## test" for this class, and #25 (comparing detectors) cannot happen without
## one — a unit test can check a tangent is perpendicular to its direction,
## but only a human looking at the overlay can judge whether the detector
## actually traced the picture's real edges.
##
## The panorama is generated, not shipped as an image, the same reason
## [code]refraction_demo.gd[/code] paints a checkerboard in code: a few
## rectangles against a sky/ground split give Canny unambiguous edges to
## find, including one deliberately straddling the horizontal wrap seam, so
## the seam handling in [method CannyEdgeSource._gaussian_blur] and friends
## has something to prove itself against.

const PANORAMA_WIDTH := 1024
const PANORAMA_HEIGHT := 512

const BLUR_STEP := 0.1
const THRESHOLD_STEP := 0.01
const RUN_LENGTH_STEP := 1

const EDGE_COLOR := Color(1.0, 0.3, 0.3, 0.9)
const POINT_RADIUS := 1.6

var _texture: ImageTexture
var _source: CannyEdgeSource
var _readout: Label

var _blur_sigma := 1.4
var _low_threshold := 0.08
var _high_threshold := 0.2
var _min_run_length := 4


func _ready() -> void:
	_texture = _build_demo_panorama()

	var sprite := Sprite2D.new()
	sprite.name = "Panorama"
	sprite.texture = _texture
	sprite.centered = false
	add_child(sprite)

	_build_readout()
	_redetect()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key == null:
		return
	match key.keycode:
		KEY_EQUAL, KEY_KP_ADD:
			_high_threshold = clampf(_high_threshold + THRESHOLD_STEP, 0.0, 1.0)
			_redetect()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_high_threshold = clampf(_high_threshold - THRESHOLD_STEP, 0.0, 1.0)
			_redetect()
		KEY_BRACKETRIGHT:
			_low_threshold = clampf(_low_threshold + THRESHOLD_STEP, 0.0, 1.0)
			_redetect()
		KEY_BRACKETLEFT:
			_low_threshold = clampf(_low_threshold - THRESHOLD_STEP, 0.0, 1.0)
			_redetect()
		KEY_UP:
			_blur_sigma = maxf(0.0, _blur_sigma + BLUR_STEP)
			_redetect()
		KEY_DOWN:
			_blur_sigma = maxf(0.0, _blur_sigma - BLUR_STEP)
			_redetect()
		KEY_RIGHT:
			_min_run_length += RUN_LENGTH_STEP
			_redetect()
		KEY_LEFT:
			_min_run_length = maxi(1, _min_run_length - RUN_LENGTH_STEP)
			_redetect()


## A fresh [CannyEdgeSource] per tune, not a mutation of the running one —
## the contract [EdgeSource]'s docstring asks every implementation to keep,
## since a consumer may already hold onto a previous result by edge id.
func _redetect() -> void:
	_source = CannyEdgeSource.new()
	_source.panorama_texture = _texture
	_source.blur_sigma = _blur_sigma
	_source.low_threshold = _low_threshold
	_source.high_threshold = _high_threshold
	_source.min_run_length = _min_run_length
	queue_redraw()
	_update_readout()


func _draw() -> void:
	if _source == null:
		return
	for edge in _source.get_edges():
		var pixels := PackedVector2Array()
		for point in edge.points:
			var uv := EquirectProjection.uv_for_direction(point.direction)
			pixels.append(Vector2(uv.x * PANORAMA_WIDTH, uv.y * PANORAMA_HEIGHT))
		if pixels.size() >= 2:
			draw_polyline(pixels, EDGE_COLOR, 2.0, true)
		elif pixels.size() == 1:
			draw_circle(pixels[0], POINT_RADIUS, EDGE_COLOR)


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Readout"
	_readout = Label.new()
	_readout.position = Vector2(16.0, 12.0)
	_readout.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_readout.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_readout.add_theme_constant_override("shadow_offset_x", 1)
	_readout.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_readout)
	add_child(layer)


func _update_readout() -> void:
	var edge_count := _source.get_edges().size()
	_readout.text = (
		"blur %.1f (up/down)  low %.2f (]/[)  high %.2f (+/-)  min run %d (left/right)  edges %d"
		% [_blur_sigma, _low_threshold, _high_threshold, _min_run_length, edge_count]
	)


## A gradient sky over flat ground, with a handful of dark rectangles for
## Canny to find — one of them straddling the seam at [code]x=0[/code] on
## purpose, so the wrap handling has something real to prove itself on.
static func _build_demo_panorama() -> ImageTexture:
	var image := Image.create(PANORAMA_WIDTH, PANORAMA_HEIGHT, false, Image.FORMAT_RGB8)
	var sky_top := Color(0.5, 0.64, 0.83)
	var sky_bottom := Color(0.83, 0.87, 0.92)
	var ground := Color(0.22, 0.2, 0.18)
	var horizon_row := int(PANORAMA_HEIGHT * 0.55)

	for y in PANORAMA_HEIGHT:
		var row_color := (
			sky_top.lerp(sky_bottom, float(y) / float(horizon_row)) if y < horizon_row else ground
		)
		for x in PANORAMA_WIDTH:
			image.set_pixel(x, y, row_color)

	var block := Color(0.08, 0.08, 0.09)
	_fill_rect(image, 120, horizon_row - 160, 90, 160, block)
	_fill_rect(image, 260, horizon_row - 220, 60, 220, block)
	_fill_rect(image, 620, horizon_row - 120, 140, 120, block)
	_fill_rect(image, PANORAMA_WIDTH - 40, horizon_row - 100, 80, 100, block)

	return ImageTexture.create_from_image(image)


## Fills a [param width]x[param height] rectangle at [param x]/[param y],
## wrapping horizontally so a rectangle can straddle the seam.
static func _fill_rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	var image_height := image.get_height()
	var image_width := image.get_width()
	for row in height:
		var py := y + row
		if py < 0 or py >= image_height:
			continue
		for col in width:
			image.set_pixel(posmod(x + col, image_width), py, color)
