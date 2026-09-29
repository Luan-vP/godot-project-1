class_name DeckDesktopLayout
extends RefCounted
## What the Steam Deck's controls send in Desktop Mode, under Steam Input's
## default desktop layout. When the game is run outside Steam (from the file
## manager, or over SSH with [code]scripts/deck.sh run[/code]), Steam keeps the
## controller in that layout and the game never sees a gamepad: every button
## arrives as a key or a mouse click. Launched through Steam, it gets a
## gamepad instead and none of this applies.
##
## Bind an action to these alongside its gamepad button, so the same physical
## button works either way. See docs/steam-deck-controls.md for the whole
## layout and where it comes from.
##
## Only controls that more than one source agrees on are constants here;
## [constant VIEW] is the exception, flagged below.

## A sends Return.
const A := KEY_ENTER
## B sends Escape.
const B := KEY_ESCAPE
## Y sends Space. (X opens the on-screen keyboard, and sends no key.)
const Y := KEY_SPACE

const DPAD_UP := KEY_UP
const DPAD_DOWN := KEY_DOWN
const DPAD_LEFT := KEY_LEFT
const DPAD_RIGHT := KEY_RIGHT

## The triggers are the mouse buttons; the right trackpad moves the pointer.
const R2 := MOUSE_BUTTON_LEFT
const L2 := MOUSE_BUTTON_RIGHT

## View (Select) sends Tab — from a single source, not yet checked on a Deck.
const VIEW := KEY_TAB

## Key sent -> the Deck control that sends it.
const KEY_CONTROLS := {
	A: "A",
	B: "B",
	Y: "Y",
	DPAD_UP: "D-pad up",
	DPAD_DOWN: "D-pad down",
	DPAD_LEFT: "D-pad left",
	DPAD_RIGHT: "D-pad right",
	VIEW: "View",
}

## Mouse button sent -> the Deck control that sends it.
const MOUSE_CONTROLS := {R2: "R2", L2: "L2"}


## The Deck control that sends [param event] in Desktop Mode, e.g. "B", or an
## empty string for anything the layout does not produce.
static func control_for(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return KEY_CONTROLS.get(code, "")
	var click := event as InputEventMouseButton
	if click != null:
		return MOUSE_CONTROLS.get(click.button_index, "")
	return ""
