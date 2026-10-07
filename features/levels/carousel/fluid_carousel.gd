class_name FluidCarousel
extends Node2D
## The three fluid levels in turn — the eye band, spout A and the waterboatmen —
## over one tank and one band.
##
## The fluid and the music are a single persistent layer ([SharedLayers]) that
## outlives every level: built when the carousel starts, kept through each
## transition and torn down only when the carousel leaves the tree. The levels
## are foreground layers that slide over it, carousel fashion: the outgoing one
## off to the left while the next comes in from the right. The fluid does not
## move.
##
## Both levels are frozen while they slide. A live level offset sideways would
## see its eyes clamped against the tank walls in global coordinates, and
## there is nothing to play with mid-transition anyway.
##
## Levels are [Node2D]s, but their HUDs live in [CanvasLayer]s, which ignore
## the parent's transform; [method _place] moves those by hand.
##
## It advances on a timer for now. [method advance] and [method retreat] are
## public so that keys can be bound to them later.

## Emitted once a level has finished arriving, with its index in [member
## level_paths].
signal level_changed(index: int)

## The levels, in order, looping.
const LEVELS: Array[String] = [
	"res://features/levels/secret_eyes/eye_band_demo.tscn",
	"res://features/levels/spout/a_fluid/level_three_a.tscn",
	"res://features/levels/boids/boids_level.tscn",
]

## Metadata key under which a [CanvasLayer]'s own horizontal offset is kept,
## captured the first time [method _place] sees it.
const BASE_OFFSET_META := &"carousel_base_offset_x"

## Seconds a level stays after it has arrived. Zero or less never advances.
@export var dwell_seconds := 20.0
## Seconds a transition takes.
@export var slide_seconds := 1.4

## The scenes cycled through. [constant LEVELS] unless a test, or a variant
## such as fluid_carousel_birds.gd, swaps it before the carousel enters the tree.
var level_paths: Array[String] = LEVELS.duplicate()

var _shared: SharedLayers
var _timer: Timer
var _current: Node2D
var _index := 0
var _sliding := false


func _ready() -> void:
	_shared = SharedLayers.new()
	_shared.name = "SharedLayers"
	add_child(_shared)

	_timer = Timer.new()
	_timer.name = "DwellTimer"
	_timer.one_shot = true
	_timer.timeout.connect(advance)
	add_child(_timer)

	_current = _instance_level(0)
	_shared.stage.add_child(_current)
	_place(_current, 0.0)
	_restart_timer()


## Slide to the next level. Ignored while a transition is running.
func advance() -> void:
	_go(1)


## Slide back to the previous level; the slide runs the other way. Ignored
## while a transition is running.
func retreat() -> void:
	_go(-1)


func current_index() -> int:
	return _index


func current_level() -> Node2D:
	return _current


func is_sliding() -> bool:
	return _sliding


func shared_layers() -> SharedLayers:
	return _shared


## Put [param level] [param x] pixels from where it sits at rest: the node
## itself, and every [CanvasLayer] beneath it, whose offset is taken from the
## layer's own at first sight so that a safe-area inset survives.
func _place(level: Node2D, x: float) -> void:
	level.position.x = x
	for node in level.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		if not layer.has_meta(BASE_OFFSET_META):
			layer.set_meta(BASE_OFFSET_META, layer.offset.x)
		layer.offset = Vector2(layer.get_meta(BASE_OFFSET_META) + x, layer.offset.y)


func _go(step: int) -> void:
	if _sliding or level_paths.size() < 2:
		return
	_sliding = true
	_timer.stop()
	var target := posmod(_index + step, level_paths.size())
	var width := get_viewport_rect().size.x
	# Forwards the next level waits on the right; backwards, on the left.
	var side := float(signi(step))

	var incoming := _instance_level(target)
	# Frozen before it joins the tree, so it does not run a frame live.
	incoming.process_mode = Node.PROCESS_MODE_DISABLED
	_shared.stage.add_child(incoming)
	_place(incoming, side * width)

	var outgoing := _current
	outgoing.process_mode = Node.PROCESS_MODE_DISABLED
	_shared.reset_currents()

	if slide_seconds <= 0.0:
		_arrive(outgoing, incoming, target)
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(progress: float) -> void:
			_place(outgoing, -side * width * progress)
			_place(incoming, side * width * (1.0 - progress)),
		0.0,
		1.0,
		slide_seconds
	)
	tween.finished.connect(_arrive.bind(outgoing, incoming, target))


func _arrive(outgoing: Node2D, incoming: Node2D, target: int) -> void:
	_place(incoming, 0.0)
	outgoing.queue_free()
	incoming.process_mode = Node.PROCESS_MODE_INHERIT
	_current = incoming
	_index = target
	_sliding = false
	level_changed.emit(_index)
	_restart_timer()


func _restart_timer() -> void:
	if dwell_seconds > 0.0:
		_timer.start(dwell_seconds)


func _instance_level(index: int) -> Node2D:
	return (load(level_paths[index]) as PackedScene).instantiate() as Node2D
