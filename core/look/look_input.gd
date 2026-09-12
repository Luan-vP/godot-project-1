class_name LookInput
extends Node
## Look rotation, summed across whichever sources are configured.
##
## [MotionInput] picks exactly one source because device tilt has exactly one
## physical ground truth — the phone either is or is not held a certain way.
## Look has no single ground truth to defer to: a player can nudge the camera
## with a gamepad stick while also flicking the mouse in the same frame, and
## both should count. So this composes rather than switches — every configured
## source contributes every frame, instead of one replacing the rest.
##
## Nodes register here so a HUD or debug readout can find it without wiring,
## the same as [MotionInput]'s group.

## Emitted once per frame a non-zero rotation was produced. Radians: x = yaw,
## y = pitch.
signal looked(delta: Vector2)

## Nodes register here so consumers can find the input without wiring.
const GROUP_NAME := "look_input"

var _sources: Array[LookSource] = []


func _ready() -> void:
	add_to_group(GROUP_NAME)
	if _sources.is_empty():
		add_source(MouseLookSource.new())
		add_source(GamepadLookSource.new())


## Forwards mouse motion to any source that wants it — [MouseLookSource], in
## the default mix. Unhandled so a UI click elsewhere does not also turn the
## camera.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	for source in _sources:
		if source.has_method("feed_event"):
			source.feed_event(event)


## Add a source to the mix. This is the seam the whole feature is built
## around — a fake in a test, a replay, an extra input method — the same spirit
## as [method MotionInput.set_source].
func add_source(source: LookSource) -> void:
	_sources.append(source)


## Drop every configured source, so a test starts from a known, empty mix
## instead of the desktop defaults installed in [method _ready].
func clear_sources() -> void:
	_sources.clear()


## Human-readable summary of what is contributing, for a debug readout.
func describe_sources() -> String:
	if _sources.is_empty():
		return "none"
	var names: PackedStringArray = []
	for source in _sources:
		names.append(source.describe())
	return ", ".join(names)


## Sum every source's contribution for this frame, in radians.
func poll(delta: float) -> Vector2:
	var total := Vector2.ZERO
	for source in _sources:
		total += source.poll(delta)
	if total != Vector2.ZERO:
		looked.emit(total)
	return total
