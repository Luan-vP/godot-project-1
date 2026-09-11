class_name FloaterShape
extends Resource
## Vector description of a floater's silhouette: filled dots and open strands,
## in local units where [code]1.0[/code] is the floater's own [member
## Floater.radius].
##
## A shape family (dot, strand, cobweb) is a difference in these numbers, not a
## different scene or node type — [Floater] draws whatever it is handed.

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
