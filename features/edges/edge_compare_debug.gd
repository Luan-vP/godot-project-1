extends Node2D
## Manual test bed for [code]#25[/code]: the same panoramas run through each
## edge detector, overlaid flat, with the numbers from [EdgeStats] beside them.
##
## Tab cycles the panorama, 1/2/3 pick the detector, A saves all nine
## panorama x detector screenshots to [code]user://[/code] (the PR images).
## Every detector runs with its defaults and is never retuned per panorama —
## stability across panoramas is one of the criteria being judged.
##
## The panoramas are generated, like [code]canny_edge_debug.gd[/code]'s, but
## built to be hostile to Canny: each pairs one or two real outlines with a
## large area of surface texture (bricks, foliage, gravel) that a level-2
## player should never be asked to lie a floater along.

const WIDTH := 1024
const HEIGHT := 512

const DETECTORS: Array[String] = ["Canny", "Contour", "Canny + line fit"]
const PANORAMAS: Array[String] = ["rooftops", "horizon", "brick wall"]

const LONG_RUN_POINTS := 40

var _panorama_index := 0
var _detector_index := 0
var _textures: Array[ImageTexture] = []
var _results := {}
var _sprite: Sprite2D
var _readout: Label
var _saving := false


func _ready() -> void:
	for panorama_name in PANORAMAS:
		_textures.append(ImageTexture.create_from_image(_build_panorama(panorama_name)))
	_sprite = Sprite2D.new()
	_sprite.name = "Panorama"
	_sprite.centered = false
	add_child(_sprite)
	_build_readout()
	_show(0, 0)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or _saving:
		return
	var key := event as InputEventKey
	if key == null:
		return
	match key.keycode:
		KEY_TAB:
			_show((_panorama_index + 1) % PANORAMAS.size(), _detector_index)
		KEY_1:
			_show(_panorama_index, 0)
		KEY_2:
			_show(_panorama_index, 1)
		KEY_3:
			_show(_panorama_index, 2)
		KEY_A:
			_save_all()


func _show(panorama: int, detector: int) -> void:
	_panorama_index = panorama
	_detector_index = detector
	_sprite.texture = _textures[panorama]
	queue_redraw()
	_update_readout()


func _edges_for(panorama: int, detector: int) -> Array[PanoramaEdge]:
	var key := Vector2i(panorama, detector)
	if not _results.has(key):
		var source: EdgeSource
		match detector:
			0:
				source = CannyEdgeSource.new()
			1:
				source = ContourEdgeSource.new()
			_:
				source = LineFitEdgeSource.new()
		source.set("panorama_texture", _textures[panorama])
		_results[key] = source.get_edges()
	return _results[key]


func _draw() -> void:
	if _textures.is_empty():
		return
	var edges := _edges_for(_panorama_index, _detector_index)
	for edge in edges:
		var pixels := PackedVector2Array()
		for point in edge.points:
			var uv := EquirectProjection.uv_for_direction(point.direction)
			pixels.append(Vector2(uv.x * WIDTH, uv.y * HEIGHT))
		# A run crossing the seam would draw a line across the whole image.
		var segment := PackedVector2Array()
		var color := Color.from_hsv(fposmod(edge.id * 0.137, 1.0), 0.9, 1.0, 0.95)
		for pixel in pixels:
			if not segment.is_empty() and absf(pixel.x - segment[segment.size() - 1].x) > WIDTH / 2:
				_draw_segment(segment, color)
				segment = PackedVector2Array()
			segment.append(pixel)
		_draw_segment(segment, color)


func _draw_segment(segment: PackedVector2Array, color: Color) -> void:
	if segment.size() >= 2:
		draw_polyline(segment, color, 2.0, true)
	elif segment.size() == 1:
		draw_circle(segment[0], 1.5, color)


func _build_readout() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Readout"
	_readout = Label.new()
	_readout.position = Vector2(16.0, 12.0)
	_readout.add_theme_color_override("font_color", Color.WHITE)
	_readout.add_theme_color_override("font_shadow_color", Color.BLACK)
	_readout.add_theme_constant_override("shadow_offset_x", 1)
	_readout.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_readout)
	add_child(layer)


func _update_readout() -> void:
	var edges := _edges_for(_panorama_index, _detector_index)
	_readout.text = (
		"%s  |  %s   (Tab panorama, 1/2/3 detector, A save all)\n"
		% [PANORAMAS[_panorama_index], DETECTORS[_detector_index]]
		+ (
			"runs %d  median %d pts  p90 %d pts  in long runs %d%%  view coverage %d%%"
			% [
				EdgeStats.run_count(edges),
				EdgeStats.length_quantile(edges, 0.5),
				EdgeStats.length_quantile(edges, 0.9),
				roundi(EdgeStats.long_run_share(edges, LONG_RUN_POINTS) * 100.0),
				roundi(EdgeStats.coverage(edges) * 100.0),
			]
		)
	)


## Every panorama x detector, each to [code]user://edges_<panorama>_<detector>.png[/code].
func _save_all() -> void:
	_saving = true
	for p in PANORAMAS.size():
		for d in DETECTORS.size():
			_show(p, d)
			await RenderingServer.frame_post_draw
			var path := (
				"user://edges_%s_%d.png" % [PANORAMAS[p].replace(" ", "_"), d + 1]
			)
			get_viewport().get_texture().get_image().save_png(path)
			print("saved ", ProjectSettings.globalize_path(path))
	_saving = false


static func _build_panorama(panorama_name: String) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 25
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
	match panorama_name:
		"rooftops":
			_paint_rooftops(image, rng)
		"horizon":
			_paint_horizon(image, rng)
		_:
			_paint_brick_wall(image, rng)
	return image


static func _sky(image: Image, horizon_row: int, top: Color, bottom: Color) -> void:
	for y in horizon_row:
		image.fill_rect(Rect2i(0, y, WIDTH, 1), top.lerp(bottom, float(y) / float(horizon_row)))


## Scatters [param count] small speckles inside [param area], each a random
## shade around [param base] — foliage, gravel, compression noise.
static func _speckle(
	image: Image, rng: RandomNumberGenerator, area: Rect2i, base: Color, spread: float, count: int
) -> void:
	for i in count:
		var size := rng.randi_range(2, 5)
		var shade := rng.randf_range(-spread, spread)
		var color := Color(
			clampf(base.r + shade, 0.0, 1.0),
			clampf(base.g + shade, 0.0, 1.0),
			clampf(base.b + shade, 0.0, 1.0)
		)
		var rect := Rect2i(
			area.position.x + rng.randi_range(0, area.size.x),
			area.position.y + rng.randi_range(0, area.size.y),
			size,
			size
		)
		image.fill_rect(rect.intersection(Rect2i(0, 0, WIDTH, HEIGHT)), color)


## Running-bond brick courses over [param area]: mortar lines with a random
## shade per brick.
static func _bricks(image: Image, rng: RandomNumberGenerator, area: Rect2i, base: Color) -> void:
	var brick_w := 14
	var brick_h := 7
	var mortar := base.darkened(0.35)
	image.fill_rect(area, mortar)
	for row in area.size.y / brick_h:
		var shift := (row % 2) * brick_w / 2
		for col in area.size.x / brick_w + 1:
			var shade := rng.randf_range(-0.05, 0.05)
			var brick := Rect2i(
				area.position.x + col * brick_w - shift + 1,
				area.position.y + row * brick_h + 1,
				brick_w - 2,
				brick_h - 2
			)
			image.fill_rect(
				brick.intersection(area),
				Color(base.r + shade, base.g + shade * 0.5, base.b + shade * 0.5)
			)


static func _paint_rooftops(image: Image, rng: RandomNumberGenerator) -> void:
	var horizon := 330
	_sky(image, horizon, Color(0.55, 0.68, 0.85), Color(0.85, 0.88, 0.92))
	image.fill_rect(Rect2i(0, horizon, WIDTH, HEIGHT - horizon), Color(0.25, 0.23, 0.2))
	_bricks(image, rng, Rect2i(80, 190, 200, 140), Color(0.45, 0.22, 0.17))
	_bricks(image, rng, Rect2i(300, 130, 120, 200), Color(0.4, 0.25, 0.2))
	image.fill_rect(Rect2i(560, 210, 240, 120), Color(0.18, 0.18, 0.22))
	# Sloped roof: a triangle built from shrinking rows.
	for i in 60:
		image.fill_rect(Rect2i(560 + i * 2, 210 - 60 + i, 240 - i * 4, 1), Color(0.3, 0.12, 0.1))
	_speckle(image, rng, Rect2i(0, 330, WIDTH, 182), Color(0.25, 0.3, 0.18), 0.18, 2600)


static func _paint_horizon(image: Image, rng: RandomNumberGenerator) -> void:
	var horizon := 260
	_sky(image, horizon, Color(0.45, 0.6, 0.8), Color(0.9, 0.85, 0.75))
	image.fill_rect(Rect2i(0, horizon, WIDTH, 90), Color(0.2, 0.35, 0.45))
	_speckle(image, rng, Rect2i(0, horizon, WIDTH, 90), Color(0.2, 0.35, 0.45), 0.05, 500)
	image.fill_rect(Rect2i(0, 350, WIDTH, 162), Color(0.5, 0.46, 0.4))
	_speckle(image, rng, Rect2i(0, 350, WIDTH, 162), Color(0.5, 0.46, 0.4), 0.22, 3200)
	# A pier and a far headland crossing the wrap seam.
	image.fill_rect(Rect2i(420, 300, 300, 18), Color(0.15, 0.12, 0.1))
	image.fill_rect(Rect2i(900, 215, 124, 45), Color(0.22, 0.27, 0.22))
	image.fill_rect(Rect2i(0, 225, 70, 35), Color(0.22, 0.27, 0.22))


static func _paint_brick_wall(image: Image, rng: RandomNumberGenerator) -> void:
	var horizon := 400
	_sky(image, horizon, Color(0.7, 0.72, 0.75), Color(0.8, 0.8, 0.8))
	image.fill_rect(Rect2i(0, horizon, WIDTH, HEIGHT - horizon), Color(0.3, 0.3, 0.3))
	_bricks(image, rng, Rect2i(150, 60, 560, 340), Color(0.5, 0.28, 0.2))
	for window in [Rect2i(200, 110, 70, 100), Rect2i(330, 110, 70, 100), Rect2i(460, 110, 70, 100)]:
		image.fill_rect(window, Color(0.1, 0.12, 0.16))
	image.fill_rect(Rect2i(590, 250, 70, 150), Color(0.2, 0.14, 0.1))
	_speckle(image, rng, Rect2i(720, 120, 250, 280), Color(0.2, 0.3, 0.15), 0.2, 1500)
