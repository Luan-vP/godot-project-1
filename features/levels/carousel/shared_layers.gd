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
## The tank is the game's one tank, the [code]Tank[/code] autoload, held for
## as long as these layers are in the tree: the water the splash swirled the
## logo away in, and the water the levels go on stirring when the carousel is
## closed and opened again. Only a tank started here is seeded with paint.
##
## A [FluidCarousel] owns one of these and keeps it through every transition,
## so the tank and the song carry on while levels slide over them. The band's
## clock (the [AudioManager] loops and tempo) runs without a break, and the
## band's own [method Band._exit_tree] stops it when the carousel leaves the
## tree. A level played on its own is a carousel of one: see
## [code]features/levels/carousel/solo/[/code].
##
## A level finds its host with [method host_of] in [method Node._ready].
##
## When the song starts, and whichever level moves the band's key, a
## [KeyPrint] here prints the key's name into the tank.
##
## The key and scale buttons ([KeyScaleButtons]) live here too, so they are
## in the top-right corner in every level and stay put through a slide. So
## does the shake that moves the band on to its next song ([SongShake]).

const SEED_BLOBS := 5
## Pigment density dropped in at the start, as a one-shot rather than a rate.
const SEED_DENSITY := 1.6
const SEED_RADIUS := 150.0
## The dyes, from [ArtPalette].
const SEED_PALETTE: Array[Color] = ArtPalette.DYES

var fluid: FluidSimulation
var band: Band
## Where the levels are instanced, drawn above the tank.
var stage: Node2D
## Prints the key's name into the tank on every new song and key move; a
## level can print other names with it too.
var key_print: KeyPrint
## The key and scale buttons, top right.
var key_scale_buttons: KeyScaleButtons
## A shake of the device moves on to the next song.
var song_shake: SongShake


func _ready() -> void:
	var fresh := not Tank.is_started()
	# The levels' own motion and look; the splash's still water and black paper
	# ease over into them.
	fluid = Tank.acquire(self)
	reset_currents()

	band = Band.new()
	band.name = "Band"
	add_child(band)
	# The song starting, and every key move from any level, prints the key's
	# name into the water. Before the band starts, so it hears the song begin.
	key_print = KeyPrint.new()
	key_print.name = "KeyPrint"
	key_print.band = band
	key_print.fluid = fluid
	add_child(key_print)
	band.start()

	key_scale_buttons = KeyScaleButtons.new()
	key_scale_buttons.name = "KeyScaleButtons"
	key_scale_buttons.band = band
	add_child(key_scale_buttons)

	song_shake = SongShake.new()
	song_shake.name = "SongShake"
	song_shake.band = band
	add_child(song_shake)

	# A tank that starts as flat colour looks like a bug. Seed it, once, when
	# it starts here: after the splash it already holds the logo, and every
	# level after the first inherits whatever the others have stirred up.
	if fresh:
		_seed()

	# Last, so levels sit in the tree beneath this node, after the band.
	stage = Node2D.new()
	stage.name = "Stage"
	add_child(stage)
	key_print.stage = stage


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


func _seed() -> void:
	var extent := fluid.config.world_size
	for i in SEED_BLOBS:
		var where := Vector2(randf(), randf()) * extent
		fluid.add_paint(
			where, SEED_PALETTE[i % SEED_PALETTE.size()], SEED_DENSITY, SEED_RADIUS, 1.0
		)


## Level out the tank's current. Each level leans it its own way (the spout's
## downward lean, the eye tank's tilt), and the next one should not inherit it.
func reset_currents() -> void:
	fluid.set_current_bias(Vector2.ZERO)
