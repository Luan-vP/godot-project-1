class_name SharedLayers
extends Node2D
## The background every level plays over: the eye tank's fluid, and the band.
##
## This is the canonical shape of a level. A level is a foreground layer: its
## own bodies, input and HUD, instanced under [member stage]. It never builds a
## tank, a backdrop or a music clock of its own. It takes [member fluid] to
## stir and paint, and [member band] to play with: wanting parts, moving the
## key, following its steps, and adding notes of its own over the top.
##
## A [FluidCarousel] owns one of these and keeps it through every transition,
## so the tank and the song carry on while levels slide over them. The band's
## clock (the [AudioManager] loops and tempo) runs without a break, and the
## band's own [method Band._exit_tree] stops it when the carousel leaves the
## tree. A level played on its own is a carousel of one: see
## [code]features/levels/carousel/solo/[/code].
##
## A level finds its host with [method host_of] in [method Node._ready].

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


## The [SharedLayers] hosting [param node], which every level needs. Reports
## an error and returns null when there is none: a level scene opened on its
## own instead of through a carousel.
static func host_of(node: Node) -> SharedLayers:
	var host := find(node)
	if host == null:
		push_error(
			(
				(
					"%s needs a SharedLayers host: play it in a FluidCarousel "
					+ "(features/levels/carousel/solo/ has one per level)"
				)
				% node.name
			)
		)
	return host


## The [SharedLayers] above [param node], or null. An ancestor walk rather than
## a group lookup on purpose: a group would find a tank from a demo that is
## still waiting to be freed.
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
