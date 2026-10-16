extends CanvasLayer
## The one fluid tank the game plays in, and its painting. The splash prints
## the logo into it, and the carousel's levels play over the same water, so
## the swirled-away logo is the pigment the first level stirs.
##
## Nothing builds it ahead of time. The first thing to [method acquire] it
## starts it, sized to the screen at that moment, and from then on it lives
## until the game quits. Whoever holds it sets how it moves (a [FluidConfig])
## and how it looks (a [PainterlyStyle]); when a new holder takes it, the look
## eases over from the last one ([constant BLEND_SECONDS]) rather than
## jumping. A holder lets go by calling [method release] or simply by leaving
## the tree. With nobody holding it the tank is paused and hidden, its water
## kept for the next holder: back at the demo menu, or in a demo with no
## fluid.
##
## It draws on its own layer ([constant LAYER]) under the default canvas, so
## every scene, level and HUD is drawn over it and nothing has to order
## itself against it.

## Emitted the first time the tank is acquired, once it is in the tree.
signal started(fluid: FluidSimulation)

## Under the default canvas layer (0), where every scene draws.
const LAYER := -1
## Grid cells across the tank. The levels' resolution: fine enough for the
## logo's lines at the splash, and what every level has always paid for.
const RESOLUTION := 256
## Seconds the look takes to ease from one holder's style to the next.
const BLEND_SECONDS := 1.6
## [FluidConfig] fields that size and allocate the tank on the device. They
## are the tank's own, fixed when it starts; a holder's config sets the rest.
const BUILD_FIELDS: Array[String] = [
	"simulation_resolution",
	"readback_resolution",
	"pressure_iterations",
	"viscosity_iterations",
	"world_size",
	"wrap_edges",
	"pigment_enabled",
]

## The tank, or null before anything has acquired it.
var fluid: FluidSimulation
## Paints [member fluid].
var renderer: FluidRenderer

var _holders: Array[Node] = []
## Each holder's hook on its own [signal Node.tree_exiting], so it can be
## unhooked when it lets go by hand.
var _hooks := {}
## The look on screen, eased from [member _look_from] to [member _look_to].
var _look := PainterlyStyle.new()
var _look_from: PainterlyStyle
var _look_to: PainterlyStyle
var _blend := 1.0


func _init() -> void:
	layer = LAYER
	visible = false


func _process(delta: float) -> void:
	if _blend >= 1.0 or renderer == null:
		return
	_blend = minf(_blend + delta / BLEND_SECONDS, 1.0)
	PainterlyStyle.blend_into(_look, _look_from, _look_to, smoothstep(0.0, 1.0, _blend))
	renderer.style = _look


## Take the tank for [param holder], starting it if this is the first time,
## moving as [param motion] says and painted as [param look] (the levels'
## look if null). Held until [param holder] leaves the tree or calls
## [method release].
func acquire(
	holder: Node, motion: FluidConfig = null, look: PainterlyStyle = null
) -> FluidSimulation:
	var first := fluid == null
	if first:
		_start()
	set_motion(motion if motion != null else FluidConfig.new())
	set_look(look if look != null else PainterlyStyle.new(), 0.0 if first else BLEND_SECONDS)
	if not _holders.has(holder):
		_holders.append(holder)
		_hooks[holder] = release.bind(holder)
		holder.tree_exiting.connect(_hooks[holder])
	_wake()
	if first:
		started.emit(fluid)
	return fluid


## Let go of the tank for [param holder]. Once nobody holds it, it pauses and
## hides, keeping its water.
func release(holder: Node) -> void:
	_holders.erase(holder)
	var hook: Callable = _hooks.get(holder, Callable())
	_hooks.erase(holder)
	if is_instance_valid(holder) and hook.is_valid() and holder.tree_exiting.is_connected(hook):
		holder.tree_exiting.disconnect(hook)
	if _holders.is_empty() and fluid != null:
		_sleep()


## Whether the tank has been started, which happens once.
func is_started() -> bool:
	return fluid != null


## Whether anything holds the tank now.
func is_held() -> bool:
	return not _holders.is_empty()


## The tank, if [param root] or something under it holds it; otherwise null.
func held_within(root: Node) -> FluidSimulation:
	for holder in _holders:
		if is_instance_valid(holder) and (holder == root or root.is_ancestor_of(holder)):
			return fluid
	return null


## Move as [param motion] says: everything but the fields that size the tank
## ([constant BUILD_FIELDS]), which stay as they were when it started.
func set_motion(motion: FluidConfig) -> void:
	for property in motion.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		if BUILD_FIELDS.has(property["name"]):
			continue
		fluid.config.set(property["name"], motion.get(property["name"]))


## Paint as [param look], easing over from the look on screen for
## [param seconds].
func set_look(look: PainterlyStyle, seconds := BLEND_SECONDS) -> void:
	_look_to = look
	if seconds <= 0.0:
		_blend = 1.0
		PainterlyStyle.blend_into(_look, look, look, 1.0)
		renderer.style = _look
		return
	_look_from = _look.duplicate() as PainterlyStyle
	_blend = 0.0


func _start() -> void:
	var config := FluidConfig.new()
	config.world_size = get_viewport().get_visible_rect().size
	config.simulation_resolution = RESOLUTION
	fluid = FluidSimulation.new()
	fluid.name = "Fluid"
	fluid.config = config
	add_child(fluid)

	renderer = FluidRenderer.new()
	renderer.name = "FluidRenderer"
	renderer.style = _look
	add_child(renderer)
	renderer.simulation_path = renderer.get_path_to(fluid)


func _wake() -> void:
	visible = true
	fluid.simulating = true
	# In the group only while held, so a tank built by a test or a tool finds
	# its own bodies and they find it, not this one asleep.
	if not fluid.is_in_group(FluidSimulation.GROUP_NAME):
		fluid.add_to_group(FluidSimulation.GROUP_NAME)


func _sleep() -> void:
	visible = false
	fluid.simulating = false
	fluid.remove_from_group(FluidSimulation.GROUP_NAME)
