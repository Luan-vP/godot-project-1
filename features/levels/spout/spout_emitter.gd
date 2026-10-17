class_name SpoutEmitter
extends Node2D
## What comes out of the [Spout]. The level shell ([SpoutLevel]) has one slot
## for an emitter and hands it the spout and the pins in [method bind]; each
## version of the level brings its own — fluid for A, balls for B — so the two
## never edit the same file.
##
## An emitter reads [method Spout.muzzle_position] and [method Spout.direction]
## each frame, and reports pins it hits with [method PinField.hit].
##
## [b]The stepped pour[/b] is shared: both versions pour (or fire) in steps
## of the bar ([SpoutFlow]), 8 drops a bar at the gentlest, up to 24, each one
## leaving on the bar's grid so the stream plays in time with the band. RT
## sets the step by depth; a touch (or held click) by how far from the spout
## it is, with [SpoutFlowOverlay] drawing the steps as rings round the nozzle.
## With neither held the spout is closed. A version opts in by calling
## [method start_flow] in its [method bind], then each physics frame takes
## [method tick_flow]'s drops due and launches that many.

var spout: Spout
var pins: PinField
## The level, for anything else an emitter needs (its [Haptics], say).
var level: Node
## The rings round the spout, once [method start_flow] has made them.
var overlay: SpoutFlowOverlay
## Whether to read the pad and keyboard; off for tests, which set the depth.
var reads_input := true

var _depth := 0.0
var _step := -1
## Where the music was last frame, in bars; NAN while closed or just changed.
var _last_bars := NAN


## Called once the level has built the spout and the pins, before the first
## frame.
func bind(level_node: Node, the_spout: Spout, the_pins: PinField) -> void:
	level = level_node
	spout = the_spout
	pins = the_pins


## Pour in steps of the bar, with the rings drawn round the spout. Call from
## [method bind], after [code]super[/code].
func start_flow() -> void:
	overlay = SpoutFlowOverlay.new()
	overlay.name = "FlowOverlay"
	overlay.z_index = 30
	overlay.pivot = spout.global_position
	overlay.max_aim = spout.max_aim
	overlay.inner = flow_inner()
	overlay.reach = flow_reach()
	add_child(overlay)


## One frame of the stepped pour: read the trigger and the touch, settle the
## step, show it on the rings, and return how many drops fall due on the
## bar's grid since the last frame (0 while closed).
func tick_flow() -> int:
	if reads_input:
		_depth = SpoutFlow.read_depth()
	var touching := _pointer_active()
	set_step(current_step())
	if overlay != null:
		overlay.show_flow(_step, touching, _pointer().point() if touching else Vector2.ZERO)
	if _step < 0:
		return 0
	var now := SpoutFlow.music_bars()
	var due := 0 if is_nan(_last_bars) else SpoutFlow.due(_last_bars, now, flow_per_bar())
	_last_bars = now
	if due > 0 and overlay != null:
		overlay.pulse()
	return due


## The step to pour at now: the higher of the trigger's and a touch's, or -1
## when neither is held.
func current_step() -> int:
	var step := SpoutFlow.step_for_depth(_depth)
	if _pointer_active():
		var distance := spout.global_position.distance_to(_pointer().point())
		step = maxi(step, SpoutFlow.step_for_distance(distance, flow_inner(), flow_reach()))
	return step


## Pour at [param step] from now on (-1 closes the spout). Opening, or moving
## to a new step, starts counting the grid from this moment, so the change
## never releases a burst.
func set_step(step: int) -> void:
	if step == _step:
		return
	_step = step
	_last_bars = NAN


func flow_step() -> int:
	return _step


## Drops a bar at the current step; 0 while closed.
func flow_per_bar() -> int:
	return SpoutFlow.per_bar(_step)


## How far up the steps the spout is, 0 at the gentlest, 1 at the fullest.
func flow_fraction() -> float:
	return float(maxi(_step, 0)) / (SpoutFlow.STEPS.size() - 1)


## Set the trigger depth by hand, for tests or another input.
func set_depth(depth: float) -> void:
	_depth = clampf(depth, 0.0, 1.0)


## Radius round the spout inside which a touch pours at the gentlest step:
## just past the nozzle's tip.
func flow_inner() -> float:
	return spout.barrel_length + 30.0


## Radius at which a touch pours at the fullest step: down at the bottom of
## the pins, so the whole drop from the spout is the dial.
func flow_reach() -> float:
	var bottom := pins.to_global(pins.area.end).y
	return maxf(bottom - spout.global_position.y, flow_inner() + 1.0)


## Whether this emitter leaves L2/R2 free for key moves. Both versions pour on
## RT, so they say no and the level keeps key moves on L1/R1.
func leaves_triggers_free() -> bool:
	return overlay == null


## One line for the HUD: what this emitter is doing right now.
func describe() -> String:
	return ""


## The controls this emitter adds, for the HUD's hint line.
func controls_hint() -> String:
	return ""


## The step for the HUD: "8 / bar", or "closed".
func describe_flow() -> String:
	return "closed" if _step < 0 else "%d / bar" % flow_per_bar()


func _pointer() -> SpoutPointer:
	return level.get("pointer") if level != null else null


func _pointer_active() -> bool:
	var pointer := _pointer()
	return pointer != null and pointer.is_active()
