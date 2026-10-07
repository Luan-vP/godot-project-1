class_name ContourEdgeSource
extends EdgeSource
## Edges as region boundaries: segment the panorama into bright and dark
## regions first, then trace the outlines of those regions.
##
## Where Canny asks "where does intensity change", this asks "where does one
## region end" — so surface texture inside a region (bricks in a wall) is
## never even considered, and what comes out is object outlines. The price is
## that it only sees boundaries the segmentation can see: a single global
## luminance split (Otsu's threshold) cannot separate two regions of similar
## brightness, however different their colour.
##
## Reuses [CannyEdgeSource]'s image loading, blur, run tracing and sphere
## embedding so the comparison is about segmentation alone.

## Equirectangular panorama to detect edges in.
@export var panorama_texture: Texture2D

## Detection runs against a copy downscaled to this width; see
## [member CannyEdgeSource.working_width].
@export_range(64, 4096, 1) var working_width: int = 512

## Blur applied before segmenting, in working pixels. Smooths texture so it
## does not speckle the regions.
@export_range(0.0, 5.0, 0.1) var blur_sigma: float = 2.0

## Boundary runs shorter than this many points are discarded.
@export_range(1, 256, 1) var min_run_length: int = 12

var _cached: bool = false
var _cached_edges: Array[PanoramaEdge] = []


func get_edges() -> Array[PanoramaEdge]:
	if not _cached:
		_cached_edges = _detect()
		_cached = true
	return _cached_edges


func _detect() -> Array[PanoramaEdge]:
	var image := CannyEdgeSource.load_working_image(panorama_texture, working_width)
	if image == null:
		return []
	var width := image.get_width()
	var height := image.get_height()
	var gray := CannyEdgeSource._grayscale(image)
	var blurred := CannyEdgeSource._gaussian_blur(gray, width, height, blur_sigma)
	var region := segment(blurred, otsu_threshold(blurred))
	var boundary := boundary_mask(region, width, height)
	var runs := CannyEdgeSource._trace_runs(boundary, width, height, min_run_length)
	return CannyEdgeSource.build_edges(runs, width, height)


## Otsu's threshold over [param values] ([code]0..1[/code]): the split that
## maximises the variance between the two classes it creates.
static func otsu_threshold(values: PackedFloat32Array) -> float:
	const BINS := 64
	var histogram := PackedFloat32Array()
	histogram.resize(BINS)
	for value in values:
		histogram[clampi(int(value * BINS), 0, BINS - 1)] += 1.0
	var total := float(values.size())
	var sum_all := 0.0
	for i in BINS:
		sum_all += float(i) * histogram[i]
	var weight_below := 0.0
	var sum_below := 0.0
	var best_variance := -1.0
	var best_bin := 0
	for i in BINS:
		weight_below += histogram[i]
		sum_below += float(i) * histogram[i]
		var weight_above := total - weight_below
		if weight_below <= 0.0:
			continue
		if weight_above <= 0.0:
			break
		var mean_below := sum_below / weight_below
		var mean_above := (sum_all - sum_below) / weight_above
		var variance := weight_below * weight_above * pow(mean_below - mean_above, 2.0)
		if variance > best_variance:
			best_variance = variance
			best_bin = i
	return float(best_bin + 1) / float(BINS)


## 1 where [param values] is at or above [param threshold], else 0.
static func segment(values: PackedFloat32Array, threshold: float) -> PackedByteArray:
	var region := PackedByteArray()
	region.resize(values.size())
	for i in values.size():
		region[i] = 1 if values[i] >= threshold else 0
	return region


## The pixels of [param region] that touch a pixel of the other class
## (4-neighbour, wrapping horizontally across the seam). Marks the bright side
## of each boundary only, so outlines are one pixel wide.
static func boundary_mask(region: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var boundary := PackedByteArray()
	boundary.resize(region.size())
	for y in height:
		for x in width:
			var index := y * width + x
			if region[index] == 0:
				continue
			var touches_other := (
				region[y * width + posmod(x - 1, width)] == 0
				or region[y * width + posmod(x + 1, width)] == 0
				or (y > 0 and region[(y - 1) * width + x] == 0)
				or (y < height - 1 and region[(y + 1) * width + x] == 0)
			)
			if touches_other:
				boundary[index] = 1
	return boundary
