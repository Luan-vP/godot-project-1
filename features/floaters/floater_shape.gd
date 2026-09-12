class_name FloaterShape
extends Resource
## Vector description of a floater's silhouette: filled dots and open strands,
## in local units where [code]1.0[/code] is the floater's own [member
## Floater.radius].
##
## A shape family (dot, strand, cobweb) is a difference in these numbers, not a
## different scene or node type — [Floater] draws whatever it is handed.

## Half-width of the fade between fully opaque and fully transparent at an
## edge, as a fraction of that edge's own radius or strand width — a dot and a
## hair-thin strand both get edges soft relative to themselves, rather than a
## single absolute softness washing out whichever is smaller.
const EDGE_SOFTNESS_FRACTION := 0.35

## Floor on the softness above, in local units, so a strand tapering to zero
## width at a strand's tip still fades out over a small but non-zero band
## instead of leaving a division by zero.
const MIN_SOFTNESS := 0.05

## How much wider than [code]1.0[/code] plus the softest dot's outer fade the
## rasterized image has to be so nothing gets clipped at the edge.
const RASTER_MARGIN := 1.5

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


## Bakes this shape into a square alpha mask sized for a floater of
## [param pixel_radius], with soft edges and tapered strand ends already
## resolved — see the class docstring on why a shader has no way to do this
## for an arbitrary vector shape: it has no notion of "distance to this dot or
## strand" to soften against, only the pixels this produces. Done once when a
## shape or radius is assigned, never per frame.
func rasterize(pixel_radius: float) -> Image:
	var extent := maxf(pixel_radius * RASTER_MARGIN, 4.0)
	var size := maxi(int(ceil(extent)) * 2, 8)
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var local := (Vector2(x, y) + Vector2(0.5, 0.5) - center) / pixel_radius
			var alpha := alpha_at(local)
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return image


## Coverage at [param point], in the shape's own local units — 1 at the core
## of a dot or the spine of a strand, fading to 0 outside it over a band set
## by [const EDGE_SOFTNESS_FRACTION]. Kept as its own pure function so the
## falloff can be checked pixel-by-pixel without rasterizing a whole image.
func alpha_at(point: Vector2) -> float:
	var alpha := 0.0
	for dot in dots:
		var dist := point.distance_to(Vector2(dot.x, dot.y))
		alpha = maxf(alpha, _edge_alpha(dist, dot.z))
	for strand in strands:
		alpha = maxf(alpha, _strand_alpha(point, strand))
	return clampf(alpha, 0.0, 1.0)


func _strand_alpha(point: Vector2, strand: PackedVector2Array) -> float:
	var alpha := 0.0
	var last := strand.size() - 1
	if last < 1:
		return alpha
	for i in last:
		var width_a := _tapered_width(float(i) / float(last))
		var width_b := _tapered_width(float(i + 1) / float(last))
		alpha = maxf(alpha, _segment_alpha(point, strand[i], strand[i + 1], width_a, width_b))
	return alpha


## Widest at the middle of the strand, fading towards both ends — a real
## strand of debris is never thick right up to its tip.
func _tapered_width(t: float) -> float:
	return strand_width * sin(PI * clampf(t, 0.0, 1.0))


func _segment_alpha(
	point: Vector2, a: Vector2, b: Vector2, width_a: float, width_b: float
) -> float:
	var along := b - a
	var length_squared := along.length_squared()
	var t := 0.0
	if length_squared > 1e-9:
		t = clampf((point - a).dot(along) / length_squared, 0.0, 1.0)
	var closest := a + along * t
	var width := lerpf(width_a, width_b, t)
	return _edge_alpha(point.distance_to(closest), width)


static func _edge_alpha(distance: float, radius: float) -> float:
	var softness := maxf(radius * EDGE_SOFTNESS_FRACTION, MIN_SOFTNESS)
	return 1.0 - smoothstep(radius - softness, radius + softness, distance)
