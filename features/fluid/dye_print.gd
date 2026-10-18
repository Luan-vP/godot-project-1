class_name DyePrint
extends RefCounted
## Pictures to print into a running tank with [method FluidSimulation.add_dye],
## so they move with the water from then on, the way the splash prints its
## logo: a shape tinted to pigment ([method tinted]), a constellation of dots
## joined by lines ([method constellation]), and a line of text rendered to a
## shape ([method render_text]).
##
## Everything here is in the tank's own terms: world positions relative to its
## top-left corner, [param world] its size in pixels and [param grid] its
## cells across. Pigment is premultiplied, as the field is.

## Margin round rendered text, in pixels, so no glyph touches the edge.
const TEXT_PAD := 8


## The grid cell [param world_position] falls in.
static func cell_of(world_position: Vector2, world: Vector2, grid: Vector2i) -> Vector2i:
	return Vector2i((world_position / cell_size(world, grid)).floor())


## One cell's size in world pixels. Cells need not be square.
static func cell_size(world: Vector2, grid: Vector2i) -> Vector2:
	return world / Vector2(grid.max(Vector2i.ONE))


## The cells a world-pixel [param rect] covers, at least one each way.
static func cells_for(rect: Rect2, world: Vector2, grid: Vector2i) -> Rect2i:
	var cell := cell_size(world, grid)
	var from := Vector2i((rect.position / cell).round())
	var span := Vector2i((rect.size / cell).round()).max(Vector2i.ONE)
	return Rect2i(from, span)


## [param mask]'s coverage, resized to [param span] cells, as pigment of
## [param color]: [param density] where the mask is opaque, none where it is
## clear.
static func tinted(mask: Image, span: Vector2i, color: Color, density: float) -> Image:
	var shape := mask.duplicate() as Image
	shape.convert(Image.FORMAT_RGBA8)
	shape.resize(maxi(span.x, 1), maxi(span.y, 1), Image.INTERPOLATE_LANCZOS)
	var dye := Image.create_empty(shape.get_width(), shape.get_height(), false, Image.FORMAT_RGBAF)
	for y in shape.get_height():
		for x in shape.get_width():
			var amount := shape.get_pixel(x, y).a * density
			dye.set_pixel(x, y, Color(color.r * amount, color.g * amount, color.b * amount, amount))
	return dye


## Stars at [param points] (world pixels), each a soft dot of its colour in
## [param colors], joined in order by fainter lines that blend from one
## star's colour to the next. [param density] is the pigment at a star's
## centre; [param dot] and [param line] are the dots' and the lines' radii in
## pixels. Returns the picture and the cell its top-left corner goes at, as
## [code]{"dye": Image, "cell": Vector2i}[/code], or an empty dictionary for
## no points.
static func constellation(
	points: Array[Vector2],
	colors: Array[Color],
	world: Vector2,
	grid: Vector2i,
	density: float = 1.2,
	dot: float = 8.0,
	line: float = 3.0
) -> Dictionary:
	if points.is_empty():
		return {}
	var reach := maxf(dot, line) * 2.5
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	bounds = bounds.grow(reach)
	var from := cell_of(bounds.position, world, grid)
	var to := cell_of(bounds.end, world, grid) + Vector2i.ONE
	var span := (to - from).max(Vector2i.ONE)
	var dye := Image.create_empty(span.x, span.y, false, Image.FORMAT_RGBAF)
	var cell := cell_size(world, grid)
	for i in range(1, points.size()):
		_add_segment(
			dye,
			from,
			cell,
			points[i - 1],
			points[i],
			colors[i - 1],
			colors[i],
			density * 0.45,
			line
		)
	for i in points.size():
		_add_segment(dye, from, cell, points[i], points[i], colors[i], colors[i], density, dot)
	return {"dye": dye, "cell": from}


## Render [param text] in [param font] at [param font_size], white on clear,
## through a throwaway [SubViewport] under [param host], and return its image.
## Takes a frame, so [code]await[/code] it. Null when nothing renders (no
## display) or [param host] leaves the tree meanwhile.
static func render_text(host: Node, text: String, font: Font, font_size: int) -> Image:
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size.ceil()) + Vector2i.ONE * TEXT_PAD * 2
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var label := Label.new()
	label.text = text
	label.position = Vector2.ONE * TEXT_PAD
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	viewport.add_child(label)
	host.add_child(viewport)
	await RenderingServer.frame_post_draw
	var image: Image = null
	if is_instance_valid(viewport):
		var texture := viewport.get_texture()
		image = texture.get_image() if texture != null else null
		viewport.queue_free()
	if not is_instance_valid(host) or not host.is_inside_tree():
		return null
	if image == null or image.is_empty():
		return null
	return image


## Lay a soft stroke from [param a] to [param b] (a dot when they meet) into
## [param dye], whose cell (0, 0) is grid cell [param origin]: [param density]
## on its spine, falling away over [param radius] pixels, its colour blending
## from [param color_a] to [param color_b].
static func _add_segment(
	dye: Image,
	origin: Vector2i,
	cell: Vector2,
	a: Vector2,
	b: Vector2,
	color_a: Color,
	color_b: Color,
	density: float,
	radius: float
) -> void:
	var reach := radius * 2.5
	var lo := Vector2i(((a.min(b) - Vector2.ONE * reach) / cell).floor()) - origin
	var hi := Vector2i(((a.max(b) + Vector2.ONE * reach) / cell).ceil()) - origin
	lo = lo.max(Vector2i.ZERO)
	hi = hi.min(dye.get_size())
	var along := b - a
	var length_squared := along.length_squared()
	for y in range(lo.y, hi.y):
		for x in range(lo.x, hi.x):
			var centre := (Vector2(origin + Vector2i(x, y)) + Vector2(0.5, 0.5)) * cell
			var t := 0.0
			if length_squared > 0.0:
				t = clampf((centre - a).dot(along) / length_squared, 0.0, 1.0)
			var distance := centre.distance_to(a + along * t)
			var amount := density * exp(-(distance * distance) / (radius * radius))
			if amount < 0.002:
				continue
			var color := color_a.lerp(color_b, t)
			var added := Color(color.r * amount, color.g * amount, color.b * amount, amount)
			dye.set_pixel(x, y, dye.get_pixel(x, y) + added)
