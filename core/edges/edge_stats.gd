class_name EdgeStats
extends RefCounted
## Numbers to read next to the overlay when comparing [EdgeSource]s for
## [code]#25[/code]. They back up the visual judgement, they do not replace it:
## a few long runs spread across the view is what level 2 wants, and these are
## the three ways a detector visibly fails that.

## Columns and rows of the grid [method coverage] counts over.
const COVERAGE_COLUMNS := 8
const COVERAGE_ROWS := 4


## Number of edges.
static func run_count(edges: Array[PanoramaEdge]) -> int:
	return edges.size()


## Points in the edge at the given quantile ([code]0.5[/code] is the median) of
## the sorted point counts. Point count stands in for length: detectors here
## emit roughly one point per working pixel. Zero with no edges.
static func length_quantile(edges: Array[PanoramaEdge], quantile: float) -> int:
	if edges.is_empty():
		return 0
	var lengths: Array[int] = []
	for edge in edges:
		lengths.append(edge.points.size())
	lengths.sort()
	return lengths[clampi(int(quantile * float(lengths.size())), 0, lengths.size() - 1)]


## Share of all edge points that belong to an edge of at least
## [param min_points] points: near 1.0 is "a few long runs", near 0.0 is "a
## dust of fragments". Zero with no edges.
static func long_run_share(edges: Array[PanoramaEdge], min_points: int) -> float:
	var total := 0
	var long := 0
	for edge in edges:
		total += edge.points.size()
		if edge.points.size() >= min_points:
			long += edge.points.size()
	return float(long) / float(total) if total > 0 else 0.0


## Fraction of the [constant COVERAGE_COLUMNS] x [constant COVERAGE_ROWS] grid
## over the panorama that holds at least one edge point. Low means the edges
## are crammed into one corner of the view, where a player cannot sweep
## floaters onto them.
static func coverage(edges: Array[PanoramaEdge]) -> float:
	var hit := {}
	for edge in edges:
		for point in edge.points:
			var uv := EquirectProjection.uv_for_direction(point.direction)
			var column := clampi(int(uv.x * COVERAGE_COLUMNS), 0, COVERAGE_COLUMNS - 1)
			var row := clampi(int(uv.y * COVERAGE_ROWS), 0, COVERAGE_ROWS - 1)
			hit[Vector2i(column, row)] = true
	return float(hit.size()) / float(COVERAGE_COLUMNS * COVERAGE_ROWS)
