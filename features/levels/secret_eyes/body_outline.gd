class_name BodyOutline
extends RefCounted
## The edge a floating body collides with: either a circle or the true outline
## of a hand-painted cut-out, read from its transparency.
##
## A cut-out's outline is a coarse signed-distance grid (negative inside, in the
## texture's own pixels, measured from its centre, the way a centred
## [Sprite2D] draws it) plus a ring of points along its edge. Two outlines
## collide when either one's edge points fall inside the other (see
## [BodyCollisions]). Holes count as outside, so the sand dollar's star is
## open water.

## Grid cells along a cut-out's longest side. Fine enough to follow a
## painting's arms, coarse enough to build in a blink.
const GRID_CELLS := 56
## Empty cells kept round the grid, so the edge is never on its border.
const PAD := 2
## Edge points kept per outline, at most.
const MAX_POINTS := 72
## Edge points round a circle.
const CIRCLE_POINTS := 24
## What [method distance] returns well clear of the outline.
const FAR := 1.0e9

static var _cache: Dictionary = {}

## Above zero, the outline is this circle and the grid is unused.
var circle_radius: float = 0.0
## Edge points, in local pixels.
var points := PackedVector2Array()
## The furthest any part of the outline is from its centre, in local pixels.
var bound: float = 0.0

var _sdf := PackedFloat32Array()
var _width: int = 0
var _height: int = 0
## Grid cells per local pixel.
var _cells_per_pixel: float = 1.0
var _half_size := Vector2.ZERO


## A circle of [param radius] round the origin.
static func circle(radius: float) -> BodyOutline:
	var outline := BodyOutline.new()
	outline.circle_radius = radius
	outline.bound = radius
	for i in CIRCLE_POINTS:
		outline.points.append(Vector2.from_angle(TAU * i / CIRCLE_POINTS) * radius)
	return outline


## The outline of [param texture]'s opaque pixels, built once per texture.
static func of_texture(texture: Texture2D) -> BodyOutline:
	var key := texture.get_rid()
	if not _cache.has(key):
		_cache[key] = from_image(texture.get_image())
	return _cache[key]


## The outline of [param image]'s opaque pixels (alpha over a half).
static func from_image(image: Image) -> BodyOutline:
	var outline := BodyOutline.new()
	var size := Vector2(image.get_size())
	var scale := float(GRID_CELLS) / maxf(size.x, size.y)
	var small := image.duplicate() as Image
	if small.is_compressed():
		small.decompress()
	small.convert(Image.FORMAT_RGBA8)
	var gw := maxi(1, roundi(size.x * scale))
	var gh := maxi(1, roundi(size.y * scale))
	small.resize(gw, gh, Image.INTERPOLATE_BILINEAR)
	outline._width = gw + PAD * 2
	outline._height = gh + PAD * 2
	outline._cells_per_pixel = scale
	outline._half_size = size * 0.5

	var inside := PackedByteArray()
	inside.resize(outline._width * outline._height)
	for y in gh:
		for x in gw:
			if small.get_pixel(x, y).a > 0.5:
				inside[(y + PAD) * outline._width + x + PAD] = 1

	var to_inside := _chamfer(inside, outline._width, outline._height, 1)
	var to_outside := _chamfer(inside, outline._width, outline._height, 0)
	outline._sdf.resize(inside.size())
	for i in inside.size():
		var cells := -(to_outside[i] - 0.5) if inside[i] == 1 else to_inside[i] - 0.5
		outline._sdf[i] = cells / scale

	var edge := PackedVector2Array()
	for y in outline._height:
		for x in outline._width:
			if inside[y * outline._width + x] == 1 and _touches_outside(inside, x, y, outline):
				edge.append(outline._cell_to_local(x, y))
	var stride := maxi(1, ceili(float(edge.size()) / MAX_POINTS))
	for i in range(0, edge.size(), stride):
		outline.points.append(edge[i])
		outline.bound = maxf(outline.bound, edge[i].length())
	return outline


## Signed distance from [param at] (local pixels) to the outline: negative
## inside, [constant FAR] well outside the grid.
func distance(at: Vector2) -> float:
	if circle_radius > 0.0:
		return at.length() - circle_radius
	var cell := _local_to_cell(at)
	if cell.x < 0.0 or cell.y < 0.0 or cell.x > _width - 1 or cell.y > _height - 1:
		return FAR
	return _sample(cell)


## The outward direction of the outline nearest [param at] (local pixels).
func normal(at: Vector2) -> Vector2:
	if circle_radius > 0.0:
		return at.normalized() if at.length_squared() > 0.0001 else Vector2.RIGHT
	var cell := _local_to_cell(at)
	var gradient := Vector2(
		_sample(cell + Vector2(1, 0)) - _sample(cell - Vector2(1, 0)),
		_sample(cell + Vector2(0, 1)) - _sample(cell - Vector2(0, 1))
	)
	return gradient.normalized() if gradient.length_squared() > 1.0e-8 else at.normalized()


func _sample(cell: Vector2) -> float:
	var x := clampf(cell.x, 0.0, _width - 1.001)
	var y := clampf(cell.y, 0.0, _height - 1.001)
	var x0 := int(x)
	var y0 := int(y)
	var fx := x - x0
	var fy := y - y0
	var i := y0 * _width + x0
	var top := lerpf(_sdf[i], _sdf[i + 1], fx)
	var bottom := lerpf(_sdf[i + _width], _sdf[i + _width + 1], fx)
	return lerpf(top, bottom, fy)


func _local_to_cell(at: Vector2) -> Vector2:
	return (at + _half_size) * _cells_per_pixel + Vector2(PAD - 0.5, PAD - 0.5)


func _cell_to_local(x: int, y: int) -> Vector2:
	return (Vector2(x, y) - Vector2(PAD - 0.5, PAD - 0.5)) / _cells_per_pixel - _half_size


static func _touches_outside(inside: PackedByteArray, x: int, y: int, o: BodyOutline) -> bool:
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx := x + step.x
		var ny := y + step.y
		if nx < 0 or ny < 0 or nx >= o._width or ny >= o._height:
			return true
		if inside[ny * o._width + nx] == 0:
			return true
	return false


## Distance, in cells, from every cell to the nearest cell whose
## [param inside] value is [param target], by a two-pass chamfer.
static func _chamfer(inside: PackedByteArray, w: int, h: int, target: int) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	dist.resize(w * h)
	for i in dist.size():
		dist[i] = 0.0 if inside[i] == target else 1.0e6
	var diag := sqrt(2.0)
	for y in h:
		for x in w:
			var i := y * w + x
			var d := dist[i]
			if x > 0:
				d = minf(d, dist[i - 1] + 1.0)
			if y > 0:
				d = minf(d, dist[i - w] + 1.0)
				if x > 0:
					d = minf(d, dist[i - w - 1] + diag)
				if x < w - 1:
					d = minf(d, dist[i - w + 1] + diag)
			dist[i] = d
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var d := dist[i]
			if x < w - 1:
				d = minf(d, dist[i + 1] + 1.0)
			if y < h - 1:
				d = minf(d, dist[i + w] + 1.0)
				if x < w - 1:
					d = minf(d, dist[i + w + 1] + diag)
				if x > 0:
					d = minf(d, dist[i + w - 1] + diag)
			dist[i] = d
	return dist
