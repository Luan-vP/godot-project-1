class_name SharedLayers
extends Node2D
## The layers a [FluidCarousel] keeps through every transition: the eye tank's
## fluid and the band.
##
## All three fluid levels paint the same tank and layer their own things over
## it, so in the carousel the tank is built once, here, and the levels are
## foreground layers that slide over it. The band is the music layer: its clock
## (the [AudioManager] loops and tempo) runs without a break across every
## level, and the band's own [method Band._exit_tree] stops it when the
## carousel leaves the tree, which is the only time it should stop.
##
## A level finds out whether it is hosted with [method find]. The levels are
## instanced under [member stage], so the walk up from any of them ends here.

const SEED_BLOBS := 5
## Pigment density dropped in at the start, as a one-shot rather than a rate.
const SEED_DENSITY := 1.6
const SEED_RADIUS := 150.0
## The eye tank's own palette.
const SEED_PALETTE: Array[Color] = [
	Color(0.36, 0.70, 0.68),
	Color(0.85, 0.45, 0.38),
	Color(0.53, 0.44, 0.76),
	Color(0.93, 0.74, 0.36),
	Color(0.30, 0.55, 0.80),
]

var fluid: FluidSimulation
var band: Band
## Where the levels are instanced, drawn above the tank.
var stage: Node2D

var _renderer: FluidRenderer


func _ready() -> void:
	var extent := get_viewport_rect().size

	var config := FluidConfig.new()
	config.world_size = extent
	fluid = FluidSimulation.new()
	fluid.name = "Fluid"
	fluid.config = config
	add_child(fluid)

	_renderer = FluidRenderer.new()
	_renderer.name = "FluidRenderer"
	_renderer.z_index = -100
	add_child(_renderer)

	band = Band.new()
	band.name = "Band"
	add_child(band)
	band.start()

	# A tank that starts as flat colour looks like a bug. Seed it, once: every
	# level after the first inherits whatever the others have stirred up.
	for i in SEED_BLOBS:
		var where := Vector2(randf(), randf()) * extent
		fluid.add_paint(
			where, SEED_PALETTE[i % SEED_PALETTE.size()], SEED_DENSITY, SEED_RADIUS, 1.0
		)

	# Last, so levels draw over the tank and sit in the tree beneath this node.
	stage = Node2D.new()
	stage.name = "Stage"
	add_child(stage)


## The [SharedLayers] hosting [param node], or null when it stands alone.
## An ancestor walk rather than a group lookup on purpose: a group would find a
## tank from a demo that is still waiting to be freed.
static func find(node: Node) -> SharedLayers:
	var up := node.get_parent()
	while up != null:
		if up is SharedLayers:
			return up
		up = up.get_parent()
	return null


## Level out the tank's current. Each level leans it its own way (the spout's
## downward lean, the eye tank's tilt), and the next one should not inherit it.
func reset_currents() -> void:
	fluid.set_current_bias(Vector2.ZERO)
