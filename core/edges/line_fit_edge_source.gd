class_name LineFitEdgeSource
extends CannyEdgeSource
## Canny plus a line-fitting pass: keeps only the long, clean, continuous runs
## Canny traced and straightens them. The winner of the detector comparison in
## [code]#25[/code] — see the package README for the losing approaches.
##
## Canny finds [i]every[/i] intensity discontinuity, and a photograph is full of
## them; level 2 wants a few long lines a floater can lie along. The fix is
## not a better detector but a discard step after it, so this class only
## overrides [method _refine_runs] and reuses the whole Canny pipeline:
##
## [codeblock]
## run ─ drop if shorter than min_length_fraction of the image width
##     ─ Douglas-Peucker simplify to simplify_tolerance pixels
##     ─ drop if still too bendy (texture, not an outline)
##     ─ resample the straightened polyline at one point per pixel
## [/codeblock]
##
## Simplifying also fixes the tangents: a traced pixel staircase has a tangent
## that flickers between 0/45/90 degrees, a fitted segment has one steady one.
##
## Runs are unwrapped across the horizontal seam before fitting (an
## equirectangular image's left and right edges are the same meridian), then
## wrapped back.

## A run shorter than this fraction of the working width is discarded. The
## single most valuable knob: gravel and foliage fragment into short runs, a
## roofline does not. Thresholds expressed as a fraction of the image survive
## a change of [member CannyEdgeSource.working_width].
@export_range(0.0, 0.5, 0.005) var min_length_fraction: float = 0.04

## Douglas-Peucker tolerance in working pixels: how far a run may stray from a
## straight segment before the fit bends to follow it.
@export_range(0.25, 8.0, 0.25) var simplify_tolerance: float = 1.5

## A fitted run with more vertices than this per 100 working pixels of length
## is wiggling rather than outlining, and is discarded.
@export_range(1.0, 100.0, 1.0) var max_vertices_per_100px: float = 30.0


func _refine_runs(runs: Array, width: int, height: int) -> Array:
	var min_length := min_length_fraction * float(width)
	var kept: Array = []
	for run in runs:
		var fitted := fit_run(
			run as Array[Vector2i],
			width,
			height,
			min_length,
			simplify_tolerance,
			max_vertices_per_100px
		)
		if not fitted.is_empty():
			kept.append(fitted)
	return kept


## [param run] straightened and resampled at one point per pixel, or an empty
## array when it is too short or too bendy to be worth keeping.
static func fit_run(
	run: Array[Vector2i],
	width: int,
	height: int,
	min_length: float,
	tolerance: float,
	max_vertices_density: float
) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	var path := _unwrap(run, width)
	var length := _path_length(path)
	if length < min_length or length <= 0.0:
		return none

	var vertices := simplify(path, tolerance)
	if float(vertices.size()) / length * 100.0 > max_vertices_density:
		return none
	return _resample(vertices, width, height)


## Douglas-Peucker: the subset of [param path] that keeps every dropped point
## within [param tolerance] of the polyline through the survivors. Iterative,
## since a long run would otherwise recurse thousands deep.
static func simplify(path: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	var count := path.size()
	if count <= 2:
		return path
	var keep := PackedByteArray()
	keep.resize(count)
	keep[0] = 1
	keep[count - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, count - 1)]
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		var farthest := -1
		var farthest_distance := tolerance
		for i in range(span.x + 1, span.y):
			var distance := _distance_to_segment(path[i], path[span.x], path[span.y])
			if distance > farthest_distance:
				farthest_distance = distance
				farthest = i
		if farthest >= 0:
			keep[farthest] = 1
			stack.append(Vector2i(span.x, farthest))
			stack.append(Vector2i(farthest, span.y))
	var result := PackedVector2Array()
	for i in count:
		if keep[i] == 1:
			result.append(path[i])
	return result


static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
	return point.distance_to(closest)


## Pixel coordinates with x made continuous across the seam: each point is
## moved by whole image widths to sit within half a width of the previous one.
static func _unwrap(run: Array[Vector2i], width: int) -> PackedVector2Array:
	var path := PackedVector2Array()
	var offset := 0
	for i in run.size():
		var pixel := run[i]
		if i > 0:
			var previous_x := run[i - 1].x
			if pixel.x - previous_x > width / 2:
				offset -= width
			elif previous_x - pixel.x > width / 2:
				offset += width
		path.append(Vector2(float(pixel.x + offset), float(pixel.y)))
	return path


static func _path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


## One point per pixel along [param vertices], wrapped back into the image,
## consecutive duplicates dropped.
static func _resample(vertices: PackedVector2Array, width: int, height: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in range(1, vertices.size()):
		var from := vertices[i - 1]
		var to := vertices[i]
		var steps := maxi(1, ceili(from.distance_to(to)))
		for step in steps:
			_append_pixel(result, from.lerp(to, float(step) / float(steps)), width, height)
	_append_pixel(result, vertices[vertices.size() - 1], width, height)
	return result


static func _append_pixel(result: Array[Vector2i], point: Vector2, width: int, height: int) -> void:
	var pixel := Vector2i(posmod(roundi(point.x), width), clampi(roundi(point.y), 0, height - 1))
	if result.is_empty() or result[result.size() - 1] != pixel:
		result.append(pixel)
