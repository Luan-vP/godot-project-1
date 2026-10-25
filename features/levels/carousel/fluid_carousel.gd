class_name FluidCarousel
extends Node2D
## The three fluid levels in turn — the eye band, the spout and the waterboatmen —
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
## A swipe along the bottom of the screen changes level: a finger (or a
## mouse drag) that starts in the bottom [constant SWIPE_BAND] of the screen
## and travels far enough sideways ([method swipe_step]). Swiping left brings
## the next level in from the right, as if pushing the current one away;
## swiping right goes back. The swipe is only watched, never consumed, so the
## level under it still sees the touch. [method advance] and [method retreat]
## are public, so keys can be bound to them too.
##
## It never advances on its own unless [member dwell_seconds] is set.
##
## A slot can hold variants ([constant VARIANTS]): the flock is the
## waterboatmen or the birds. Every time the carousel arrives at that slot
## it picks one of the group, each as likely, so swiping round again may
## bring the other.
##
## [member level_paths] is exported, so a variant is just a scene that sets it:
## a carousel of one for each level played on its own
## (features/levels/carousel/solo/), which never advances and always plays
## exactly its level.

## Emitted once a level has finished arriving, with its index in [member
## level_paths].
signal level_changed(index: int)

## The levels, in order, looping.
const LEVELS: Array[String] = [
	"res://features/levels/secret_eyes/eye_band_demo.tscn",
	"res://features/levels/spout/bubbles/level_three.tscn",
	"res://features/levels/boids/boids_level.tscn",
]

## Levels that share a slot: arriving at a slot holding any of them,
## one of the group is played, picked at random.
const VARIANTS: Array[Array] = [
	[
		"res://features/levels/boids/boids_level.tscn",
		"res://features/levels/boids/birds_level.tscn",
	],
]

## Metadata key under which a [CanvasLayer]'s own horizontal offset is kept,
## captured the first time [method _place] sees it.
const BASE_OFFSET_META := &"carousel_base_offset_x"

## Share of the screen's height, up from the bottom edge, that a swipe has to
## start in.
const SWIPE_BAND := 0.2
## Least sideways travel, as a share of the screen's width, that makes a swipe.
const SWIPE_MIN_TRAVEL := 0.12
## No swipe is being watched.
const NO_SWIPE := Vector2.INF

## Seconds a level stays after it has arrived before advancing on its own.
## Zero or less, the default, never advances: the player swipes.
@export var dwell_seconds := 0.0
## Seconds a transition takes.
@export var slide_seconds := 1.4

## The scenes cycled through. [constant LEVELS] unless a scene or a test sets
## it before the carousel enters the tree.
@export var level_paths: Array[String] = LEVELS.duplicate()

## Picks between a slot's variants. Seed it for a repeatable pick.
var rng := RandomNumberGenerator.new()

var _shared: SharedLayers
var _timer: Timer
var _current: Node2D
var _index := 0
var _sliding := false
## Where the swipe being watched started, or [constant NO_SWIPE].
var _swipe_from := NO_SWIPE


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
	_note_level()
	_restart_timer()


## Watched here rather than in an unhandled handler, so a level that takes
## the touch for itself cannot hide the swipe from the carousel.
func _input(event: InputEvent) -> void:
	var press := _press_of(event)
	if press.is_empty():
		return
	if press["pressed"]:
		_swipe_from = press["position"]
	elif _swipe_from != NO_SWIPE:
		var step := swipe_step(_swipe_from, press["position"], get_viewport_rect().size)
		_swipe_from = NO_SWIPE
		if step != 0:
			_go(step)


## Which way a press at [param from] let go at [param to] on a [param
## screen]-sized canvas swipes: 1 for the next level (a swipe to the left), -1
## for the previous one, 0 when it is not a swipe along the bottom at all.
static func swipe_step(from: Vector2, to: Vector2, screen: Vector2) -> int:
	if from.y < screen.y * (1.0 - SWIPE_BAND):
		return 0
	var travel := to - from
	if absf(travel.x) < screen.x * SWIPE_MIN_TRAVEL or absf(travel.x) < absf(travel.y):
		return 0
	return 1 if travel.x < 0.0 else -1


## The first finger, or the left mouse button, going down or coming up, as
## [code]{pressed, position}[/code]; empty for anything else. Mouse events
## Godot makes up from a touch are skipped, so a touch is not counted twice.
static func _press_of(event: InputEvent) -> Dictionary:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.index != 0:
			return {}
		return {"pressed": touch.pressed, "position": touch.position}
	var click := event as InputEventMouseButton
	if (
		click != null
		and click.button_index == MOUSE_BUTTON_LEFT
		and click.device != InputEvent.DEVICE_ID_EMULATION
	):
		return {"pressed": click.pressed, "position": click.position}
	return {}


func _exit_tree() -> void:
	AudioManager.get_level_meter().set_note("level", "")


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
	_note_level()
	level_changed.emit(_index)
	_restart_timer()


## Tell the level meter which level is playing, so an over says where it was.
func _note_level() -> void:
	AudioManager.get_level_meter().set_note("level", _current.name)


func _restart_timer() -> void:
	if dwell_seconds > 0.0 and level_paths.size() > 1:
		_timer.start(dwell_seconds)


func _instance_level(index: int) -> Node2D:
	return (load(path_for(index)) as PackedScene).instantiate() as Node2D


## The scene to play for slot [param index]: its own level, or, when that is
## one of an A/B pair ([constant VARIANTS]), either of the pair, picked
## afresh each call. A carousel of one always plays its own level.
func path_for(index: int) -> String:
	var path := level_paths[index]
	if level_paths.size() < 2:
		return path
	for group in VARIANTS:
		if group.has(path):
			return group[rng.randi_range(0, group.size() - 1)]
	return path
