class_name SpoutEmitter
extends Node2D
## What comes out of the [Spout]. The level shell ([SpoutLevel]) has one slot
## for an emitter and hands it the spout and the pins in [method bind]; each
## version of the level brings its own — fluid for A, balls for B — so the two
## never edit the same file.
##
## An emitter reads [method Spout.muzzle_position] and [method Spout.direction]
## each frame, and reports pins it hits with [method PinField.hit].

var spout: Spout
var pins: PinField
## The level, for anything else an emitter needs (its [Haptics], say).
var level: Node


## Called once the level has built the spout and the pins, before the first
## frame.
func bind(level_node: Node, the_spout: Spout, the_pins: PinField) -> void:
	level = level_node
	spout = the_spout
	pins = the_pins


## Whether this emitter leaves L2/R2 free for key moves. Version B fires on
## RT, so it says no and the level keeps key moves on L1/R1.
func leaves_triggers_free() -> bool:
	return true


## Whether this emitter paints a dark backdrop over the paper, so the HUD and
## the pins' labels should be light.
func dark_backdrop() -> bool:
	return false


## One line for the HUD: what this emitter is doing right now.
func describe() -> String:
	return ""


## The controls this emitter adds, for the HUD's hint line.
func controls_hint() -> String:
	return ""
