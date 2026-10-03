class_name SpoutPointer
extends Node
## A finger on the touchscreen, or a held mouse button, as a way to aim the
## spout: while it is down, the nozzle swings to point at it.
##
## This is what makes the level playable on a Steam Deck run outside Steam,
## where the controller arrives as a keyboard and mouse and the sticks may not
## reach the game at all: the touchscreen works the same either way, and the
## right trackpad (which moves the pointer) with R2 (a left click) does too.
##
## Touches arrive as emulated left-button mouse events (Godot's
## [code]emulate_mouse_from_touch[/code], on by default), so one path handles
## both. A press only counts if nothing else took it first — read in
## [method _unhandled_input], so a touch on one of the HUD's buttons presses
## the button and does not also aim.

## Emitted when a press starts or ends.
signal active_changed(active: bool)

var _active := false
var _point := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed and not _active:
			press(click.position)
			get_viewport().set_input_as_handled()
		elif not click.pressed and _active:
			release()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _active:
		_point = motion.position


## Start a press at [param at], in canvas coordinates.
func press(at: Vector2) -> void:
	_point = at
	_active = true
	active_changed.emit(true)


func move_to(at: Vector2) -> void:
	_point = at


func release() -> void:
	_active = false
	active_changed.emit(false)


func is_active() -> bool:
	return _active


## Where the press is, in canvas coordinates. The level has no camera, so
## this is also world space.
func point() -> Vector2:
	return _point
