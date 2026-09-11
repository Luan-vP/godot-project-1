class_name FloaterField
extends Node2D
## Populates a [FluidSimulation] with a configurable dusting of [Floater]s.
##
## A level picks how much debris its tank has and how it is sized by setting
## the exports below — the count and the size distribution are the whole
## interface, not a fixed roster of scenes.

## How many floaters to keep in the tank.
@export_range(0, 400) var count: int = 60

## Radius range floaters are drawn from, in pixels.
@export var radius_range: Vector2 = Vector2(2.0, 8.0)

## Skews the radius distribution towards the small end of [member
## radius_range] when above 1 — real floaters are mostly small specks with a
## few large clumps, not a flat spread. 1 is uniform.
@export_range(0.1, 4.0) var size_skew: float = 1.8

## Relative odds of dot, strand and cobweb, in that order. Need not sum to
## anything in particular — they are normalised against each other.
@export var shape_weights: Vector3 = Vector3(3.0, 2.0, 1.0)

@export var color: Color = Color(0.13, 0.14, 0.17, 0.5)

## Tank to populate. Left empty, the first tank in the scene is used.
@export var simulation_path: NodePath

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var simulation := _resolve_simulation()
	if simulation == null:
		return
	var rect := simulation.get_world_rect()
	for i in count:
		add_child(_make_floater(rect))


func _resolve_simulation() -> FluidSimulation:
	if not simulation_path.is_empty():
		return get_node_or_null(simulation_path) as FluidSimulation
	return get_tree().get_first_node_in_group(FluidSimulation.GROUP_NAME) as FluidSimulation


func _make_floater(rect: Rect2) -> Floater:
	var floater := Floater.new()
	floater.radius = sampled_radius(_rng, radius_range, size_skew)
	floater.shape = _make_shape(_rng, shape_weights)
	floater.color = color
	floater.global_position = rect.position + Vector2(_rng.randf(), _rng.randf()) * rect.size
	return floater


## A radius drawn from [param radius_range], skewed towards the low end by
## [param skew] (1 is uniform, higher pushes the distribution smaller). Kept
## pure and static so the distribution can be checked without a scene tree.
static func sampled_radius(
	rng: RandomNumberGenerator, radius_range: Vector2, skew: float
) -> float:
	return lerpf(radius_range.x, radius_range.y, pow(rng.randf(), skew))


## Picks a shape family index (0 dot, 1 strand, 2 cobweb) from [param weights],
## which need not be normalised. Static and pure for the same reason as
## [method sampled_radius].
static func pick_family(rng: RandomNumberGenerator, weights: Vector3) -> int:
	var total := weights.x + weights.y + weights.z
	if total <= 0.0:
		return 0
	var roll := rng.randf() * total
	if roll < weights.x:
		return 0
	if roll < weights.x + weights.y:
		return 1
	return 2


static func _make_shape(rng: RandomNumberGenerator, weights: Vector3) -> FloaterShape:
	match pick_family(rng, weights):
		0:
			return FloaterShape.make_dot()
		1:
			return FloaterShape.make_strand(rng)
		_:
			return FloaterShape.make_cobweb(rng)
