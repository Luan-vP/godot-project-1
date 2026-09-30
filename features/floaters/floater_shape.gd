class_name FloaterShape
extends Resource
## Vector description of a floater's silhouette: filled dots and open strands,
## in local units where [code]1.0[/code] is the floater's own [member
## Floater.radius].
##
## A shape family (dot, strand, cobweb) is a difference in these numbers, not a
## different scene or node type — [Floater] draws whatever it is handed.

## How much a strand's thickness wanders along its length, as a fraction of its
## width. A real collagen fibre is never an even rod.
const UNEVENNESS := 0.3

## Taper and unevenness change a strand's width point to point; this keeps its
## average at [member strand_width], so a population tuned on even strands
## keeps the same weight. The taper, sin(PI * t), averages 2 / PI.
const TAPER_MEAN_SCALE := PI / 2.0

## Filled circles: [code]x[/code], [code]y[/code], radius.
@export var dots: Array[Vector3] = []

## Open polylines.
@export var strands: Array[PackedVector2Array] = []

## Strand thickness, in the same local units as the points.
@export var strand_width: float = 0.16


## A single dense speck — the most common real floater.
static func make_dot() -> FloaterShape:
	var shape := FloaterShape.new()
	shape.dots.append(Vector3(0.0, 0.0, 1.0))
	return shape


## A long thread with a gentle wander along its length, rather than a straight
## rod, since a real strand is never perfectly taut.
static func make_strand(
	rng: RandomNumberGenerator, segments: int = 6, wander: float = 0.3
) -> FloaterShape:
	var shape := FloaterShape.new()
	var points := PackedVector2Array()
	var step := 2.0 / float(maxi(segments, 1))
	var pos := Vector2(-1.0, 0.0)
	for i in segments + 1:
		points.append(pos)
		pos += Vector2(step, rng.randf_range(-wander, wander) * step)
	shape.strands.append(points)
	shape.strand_width = 0.14
	return shape


## A knot of short strands radiating from a shared centre, the way real debris
## clumps of collagen fibres branch.
static func make_cobweb(rng: RandomNumberGenerator, arms: int = 5) -> FloaterShape:
	var shape := FloaterShape.new()
	shape.dots.append(Vector3(0.0, 0.0, 0.3))
	for i in arms:
		var angle := (TAU / float(arms)) * float(i) + rng.randf_range(-0.4, 0.4)
		var arm_length := rng.randf_range(0.5, 1.0)
		var elbow := Vector2.from_angle(angle) * arm_length * 0.55
		var tip := Vector2.from_angle(angle + rng.randf_range(-0.5, 0.5)) * arm_length
		shape.strands.append(PackedVector2Array([Vector2.ZERO, elbow, tip]))
	shape.strand_width = 0.1
	return shape


## Full width at each point of [param points], for a strand whose average
## width is [param width]: zero at both tips, fullest near the middle, and
## wandering a little along the way. The wander is seeded from the strand's own
## points, so a floater keeps the same silhouette every time it is redrawn.
##
## A two-point strand has no middle to be fullest at — tapering both of its
## points to zero would erase it — so it keeps an even [param width].
static func strand_widths(points: PackedVector2Array, width: float) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	widths.resize(points.size())
	if points.size() < 2:
		return widths
	if points.size() == 2:
		widths.fill(width)
		return widths
	var lengths := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i].distance_to(points[i - 1]))
	var total := maxf(lengths[lengths.size() - 1], 1e-6)
	var seed := points[0].x * 12.9898 + points[0].y * 78.233
	for i in points.size():
		var t := lengths[i] / total
		var wander := 1.0 + UNEVENNESS * sin(t * 3.7 * PI + seed)
		widths[i] = width * TAPER_MEAN_SCALE * sin(PI * t) * wander
	# Exactly zero, not sin(PI)'s float residue: the drawing collapses a
	# zero-width tip to one vertex, and a near-zero one would be a sliver.
	widths[0] = 0.0
	widths[widths.size() - 1] = 0.0
	return widths
