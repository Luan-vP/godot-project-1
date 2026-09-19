class_name CannyEdgeSource
extends EdgeSource
## Detects edges in a level's panorama automatically, instead of tracing them
## by hand like [ManualEdgeSource].
##
## Runs the textbook Canny pipeline — grayscale, Gaussian blur, Sobel
## gradients, non-maximum suppression, hysteresis threshold — entirely on the
## CPU with [Image], then links the surviving pixels into ordered polylines
## the same way [ManualEdgeSource] produces them, so [method get_edges]
## returns [b]traced, connected runs with a tangent[/b] rather than a binary
## mask; a scorer asking "does this floater lie along an edge" ([code]#26[/code])
## cannot answer that from a field of lit pixels.
##
## [b]CPU, not a compute shader.[/b] The parallel half of Canny (blur, Sobel,
## suppression) would fit a compute shader well, matching the fluid tank's
## `.glsl` passes — but hysteresis linking and the edge-tracing this class
## needs on top of it are inherently sequential: which pixel a weak edge
## connects to, and which direction a traced run continues in, both depend on
## a decision already made a few pixels back. That is a poor fit for a
## parallel pass, and splitting the pipeline across a GPU half and a CPU half
## would mean a synchronous GPU readback once per level load anyway — no
## better than staying on the CPU throughout, and without the `.glsl` import
## machinery (see the fluid README) or its lavapipe/shader-count CI
## dependency. It also keeps this class testable in headless GUT the way
## [ManualEdgeSource] is, building a small synthetic [Image] by hand rather
## than needing a real rendering device.
##
## [b]Runtime, not an import-time bake.[/b] [method get_edges] runs once,
## lazily, the first time a consumer asks — same contract as every
## [EdgeSource] (see the package README) — and caches the result for this
## object's lifetime rather than an import step baking it into the level
## asset. A baked edge set would load faster and ship deterministically, but
## every threshold in this class is explicitly "tunable per level" (see the
## issue this class implements): an import bake means a reimport per tweak,
## which is the same tradeoff the fluid README's viscosity tuning table was
## gathered without. [member working_width] keeps the runtime cost bounded
## regardless of the source texture's resolution — detection runs against a
## downscaled copy, not the full panorama — which is what keeps "once per
## level load" cheap enough to not need baking.
##
## [b]Equirectangular distortion[/b] is corrected the same way
## [ManualEdgeSource] does it — at the sphere embedding, once — but through
## [EquirectProjection] instead of [PanoramaLookCamera]'s yaw/pitch, since
## what this class's pixels have to agree with is [PanoramaSkyMaterial]'s own
## sampling convention. See that class's docstring for why the two
## conventions differ and why that is fine.

## Neighbour offsets used to walk a hysteresis mask when tracing runs,
## 8-connected.
const _NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
]

## Equirectangular panorama to detect edges in. Left [code]null[/code],
## [method get_edges] returns an empty array like the base [EdgeSource].
@export var panorama_texture: Texture2D

## Detection runs against a copy of [member panorama_texture] downscaled to
## this width (preserving aspect ratio), never upscaled. Bounds the cost of
## running once per level load to a fixed budget independent of how large the
## source texture actually is; the traced runs are converted back to
## panorama-space directions afterwards; see [EquirectProjection], so a
## coarser working resolution costs precision, not correctness.
@export_range(64, 4096, 1) var working_width: int = 512

## Standard deviation of the Gaussian blur applied before taking gradients,
## in working pixels. Higher smooths away fine texture (foliage, fabric weave)
## at the cost of blurring nearby edges together.
@export_range(0.0, 5.0, 0.1) var blur_sigma: float = 1.4

## Hysteresis low threshold, as a fraction of the strongest surviving gradient
## in this image after non-maximum suppression. A pixel below this is
## discarded outright.
@export_range(0.0, 1.0, 0.01) var low_threshold: float = 0.08

## Hysteresis high threshold, as a fraction of the strongest surviving
## gradient. A pixel at or above this seeds an edge; anything between
## [member low_threshold] and this only survives connected to a seed.
## Fractions of the image's own strongest edge, not an absolute gradient
## value, are what make these two comparable across a foggy landscape and a
## hard-lit interior without retuning the formula itself — only the two
## numbers, per the issue's "tunable per level" requirement.
@export_range(0.0, 1.0, 0.01) var high_threshold: float = 0.2

## Traced runs shorter than this many points are discarded as noise rather
## than returned as edges.
@export_range(1, 64, 1) var min_run_length: int = 4

var _cached: bool = false
var _cached_edges: Array[PanoramaEdge] = []


## Edges detected in [member panorama_texture]. Computed once, lazily, and
## cached for this object's lifetime — see the class docstring's "Runtime,
## not an import-time bake" — so a fresh detector pass means a fresh
## [CannyEdgeSource], the same promise [EdgeSource] makes for every
## implementation.
func get_edges() -> Array[PanoramaEdge]:
	if not _cached:
		_cached_edges = _detect()
		_cached = true
	return _cached_edges


func _detect() -> Array[PanoramaEdge]:
	if panorama_texture == null:
		return []
	var source_image := panorama_texture.get_image()
	if source_image == null:
		return []
	var image := source_image.duplicate() as Image
	if image.is_compressed():
		image.decompress()

	var target_width := mini(working_width, image.get_width())
	if target_width < image.get_width():
		var aspect := float(image.get_height()) / float(image.get_width())
		var target_height := maxi(1, roundi(target_width * aspect))
		image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)

	var width := image.get_width()
	var height := image.get_height()
	if width < 3 or height < 3:
		return []

	var gray := _grayscale(image)
	var blurred := _gaussian_blur(gray, width, height, blur_sigma)
	var sobel := _sobel(blurred, width, height)
	var magnitude: PackedFloat32Array = sobel[0]
	var angle: PackedFloat32Array = sobel[1]
	var suppressed := _non_max_suppression(magnitude, angle, width, height)
	var mask := _hysteresis(suppressed, width, height, low_threshold, high_threshold)
	var runs := _trace_runs(mask, width, height, min_run_length)

	var edges: Array[PanoramaEdge] = []
	for i in runs.size():
		edges.append(_build_edge(i, runs[i] as Array[Vector2i], width, height))
	return edges


## Luminance per pixel, [code]0..1[/code].
static func _grayscale(image: Image) -> PackedFloat32Array:
	var width := image.get_width()
	var height := image.get_height()
	var gray := PackedFloat32Array()
	gray.resize(width * height)
	for y in height:
		var row := y * width
		for x in width:
			var color := image.get_pixel(x, y)
			gray[row + x] = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
	return gray


## Normalised 1D Gaussian, [code]3*sigma[/code] radius each side.
static func _gaussian_kernel(sigma: float) -> PackedFloat32Array:
	var radius := maxi(1, ceili(sigma * 3.0))
	var kernel := PackedFloat32Array()
	kernel.resize(radius * 2 + 1)
	var sum := 0.0
	for i in kernel.size():
		var x := float(i - radius)
		var value := exp(-(x * x) / (2.0 * sigma * sigma))
		kernel[i] = value
		sum += value
	for i in kernel.size():
		kernel[i] /= sum
	return kernel


## Separable Gaussian blur. The horizontal pass wraps across the seam — an
## equirectangular image's left and right edges are the same meridian, not a
## boundary — while the vertical pass clamps, since the poles are not a
## wraparound.
static func _gaussian_blur(
	gray: PackedFloat32Array, width: int, height: int, sigma: float
) -> PackedFloat32Array:
	if sigma <= 0.0:
		return gray
	var kernel := _gaussian_kernel(sigma)
	var radius := (kernel.size() - 1) / 2

	var horizontal := PackedFloat32Array()
	horizontal.resize(gray.size())
	for y in height:
		var row := y * width
		for x in width:
			var value := 0.0
			for k in kernel.size():
				value += gray[row + posmod(x + k - radius, width)] * kernel[k]
			horizontal[row + x] = value

	var result := PackedFloat32Array()
	result.resize(gray.size())
	for y in height:
		for x in width:
			var value := 0.0
			for k in kernel.size():
				var sample_y := clampi(y + k - radius, 0, height - 1)
				value += horizontal[sample_y * width + x] * kernel[k]
			result[y * width + x] = value
	return result


## Sobel gradient magnitude and direction per pixel. Returns
## [code][magnitude, angle][/code], both [PackedFloat32Array] the same size
## as [param blurred]. Neighbour sampling wraps horizontally and clamps
## vertically, for the same reason as [method _gaussian_blur].
static func _sobel(blurred: PackedFloat32Array, width: int, height: int) -> Array:
	var magnitude := PackedFloat32Array()
	magnitude.resize(blurred.size())
	var angle := PackedFloat32Array()
	angle.resize(blurred.size())
	for y in height:
		var y0 := clampi(y - 1, 0, height - 1)
		var y2 := clampi(y + 1, 0, height - 1)
		for x in width:
			var x0 := posmod(x - 1, width)
			var x2 := posmod(x + 1, width)
			var tl := blurred[y0 * width + x0]
			var tc := blurred[y0 * width + x]
			var tr := blurred[y0 * width + x2]
			var ml := blurred[y * width + x0]
			var mr := blurred[y * width + x2]
			var bl := blurred[y2 * width + x0]
			var bc := blurred[y2 * width + x]
			var br := blurred[y2 * width + x2]
			var gx := (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl)
			var gy := (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr)
			var index := y * width + x
			magnitude[index] = sqrt(gx * gx + gy * gy)
			angle[index] = atan2(gy, gx)
	return [magnitude, angle]


## Thins [param magnitude] to (at most) one pixel across the gradient
## direction: a pixel survives only if it is at least as strong as its two
## neighbours along that direction, bucketed to the nearest of 4 compass
## directions 45 degrees apart.
static func _non_max_suppression(
	magnitude: PackedFloat32Array, angle: PackedFloat32Array, width: int, height: int
) -> PackedFloat32Array:
	var suppressed := PackedFloat32Array()
	suppressed.resize(magnitude.size())
	for y in height:
		for x in width:
			var index := y * width + x
			var strength := magnitude[index]
			if strength <= 0.0:
				continue
			var degrees := fmod(rad_to_deg(angle[index]) + 180.0, 180.0)
			var dx := 1
			var dy := 0
			if degrees < 22.5 or degrees >= 157.5:
				dx = 1
				dy = 0
			elif degrees < 67.5:
				dx = 1
				dy = 1
			elif degrees < 112.5:
				dx = 0
				dy = 1
			else:
				dx = -1
				dy = 1
			var before := magnitude[clampi(y - dy, 0, height - 1) * width + posmod(x - dx, width)]
			var after := magnitude[clampi(y + dy, 0, height - 1) * width + posmod(x + dx, width)]
			if strength >= before and strength >= after:
				suppressed[index] = strength
	return suppressed


## Binary edge mask via hysteresis: a pixel at or above
## [param high_fraction] of the image's own strongest survivor seeds an edge;
## anything at or above [param low_fraction] survives only if connected
## (8-neighbour, wrapping horizontally) to a seed, directly or through other
## weak pixels.
static func _hysteresis(
	suppressed: PackedFloat32Array,
	width: int,
	height: int,
	low_fraction: float,
	high_fraction: float
) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(suppressed.size())
	var strongest := 0.0
	for value in suppressed:
		strongest = maxf(strongest, value)
	if strongest <= 0.0:
		return mask

	var high := high_fraction * strongest
	var low := low_fraction * strongest
	var stack: Array[int] = []
	for i in suppressed.size():
		if suppressed[i] >= high:
			mask[i] = 1
			stack.append(i)

	while not stack.is_empty():
		var index: int = stack.pop_back()
		var x := index % width
		var y := index / width
		for oy in range(-1, 2):
			var ny := clampi(y + oy, 0, height - 1)
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var n_index := ny * width + posmod(x + ox, width)
				if mask[n_index] == 0 and suppressed[n_index] >= low:
					mask[n_index] = 1
					stack.append(n_index)
	return mask


## Unvisited, unmasked 8-neighbours of [param x]/[param y], wrapping
## horizontally.
static func _unvisited_neighbors(
	mask: PackedByteArray, visited: PackedByteArray, width: int, height: int, x: int, y: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in _NEIGHBOUR_OFFSETS:
		var ny := y + offset.y
		if ny < 0 or ny >= height:
			continue
		var nx := posmod(x + offset.x, width)
		var n_index := ny * width + nx
		if mask[n_index] == 1 and visited[n_index] == 0:
			result.append(Vector2i(nx, ny))
	return result


## Links [param mask] into ordered pixel runs, discarding any shorter than
## [param min_run_length] points. Two passes: the first walks outward from
## every endpoint (a pixel with at most one unvisited neighbour) so open
## strands are traced end-to-end rather than starting mid-line; the second
## sweeps up whatever is left — closed loops, and the remaining arms of a
## junction once its other arms have already claimed the junction pixel.
## At a junction reached mid-walk, one branch is followed and the others are
## left for a later, separate run rather than merged into one zigzagging
## polyline — the traced-runs contract only promises each point a local
## tangent, not that a run crosses every junction it touches.
static func _trace_runs(
	mask: PackedByteArray, width: int, height: int, min_run_length: int
) -> Array:
	var visited := PackedByteArray()
	visited.resize(mask.size())
	var runs: Array = []

	for pass_index in range(2):
		for y in height:
			for x in width:
				var index := y * width + x
				if mask[index] == 0 or visited[index] == 1:
					continue
				var neighbors := _unvisited_neighbors(mask, visited, width, height, x, y)
				if pass_index == 0 and neighbors.size() > 1:
					continue
				var run: Array[Vector2i] = [Vector2i(x, y)]
				visited[index] = 1
				var current := Vector2i(x, y)
				while neighbors.size() > 0:
					var next: Vector2i = neighbors[0]
					run.append(next)
					visited[next.y * width + next.x] = 1
					current = next
					neighbors = _unvisited_neighbors(
						mask, visited, width, height, current.x, current.y
					)
				if run.size() >= min_run_length:
					runs.append(run)
	return runs


## One traced pixel run turned into a [PanoramaEdge]: each point mapped to
## panorama-space through [EquirectProjection], then given a tangent the same
## way [ManualEdgeSource] does — see [PanoramaEdgeTangent].
static func _build_edge(id: int, run: Array[Vector2i], width: int, height: int) -> PanoramaEdge:
	var directions: Array[Vector3] = []
	for pixel in run:
		var uv := Vector2(
			(float(pixel.x) + 0.5) / float(width), (float(pixel.y) + 0.5) / float(height)
		)
		directions.append(EquirectProjection.direction_for_uv(uv))

	var points: Array[PanoramaEdgePoint] = []
	for i in directions.size():
		points.append(PanoramaEdgePoint.new(directions[i], PanoramaEdgeTangent.at(directions, i)))
	return PanoramaEdge.new(id, points)
