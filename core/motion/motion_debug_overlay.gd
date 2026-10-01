class_name MotionDebugOverlay
extends CanvasLayer
## Live tilt values, on top of whatever level is running.
##
## [code]motion_demo[/code] answers "does this device report anything" in
## isolation. This answers the question that only comes up in a real level:
## the tank is barely moving — is the sensor flat, is the tilt tiny, or is the
## level ignoring it? Without it the three look identical on the device, where
## there is no console to print to.
##
## Finds the level's [MotionInput] through [constant MotionInput.GROUP_NAME],
## so a level gets the readout by adding one of these and nothing else. Levels
## build their own [MotionInput] rather than sharing one, which is why this
## looks the node up instead of taking it as an export.
##
## F3, or the gamepad's Y button, hides and shows it.

## Key that toggles the readout on a desktop.
const TOGGLE_KEY := KEY_F3

## Gamepad button that toggles it on a device with no keyboard — the Deck.
const TOGGLE_BUTTON := JOY_BUTTON_Y

const INK := Color(0.88, 0.90, 0.94, 0.95)
const BACKDROP := Color(0.05, 0.06, 0.08, 0.55)

## Shown when the tilt is below this, to name what a still tank means.
const RESTING_TILT := 0.02

var _motion: MotionInput
var _label: Label
var _panel: ColorRect
var _jogs: int = 0


func _ready() -> void:
	layer = 100
	_panel = ColorRect.new()
	_panel.name = "Backdrop"
	_panel.color = BACKDROP
	_panel.position = Vector2(12.0, 10.0)
	_panel.size = Vector2(320.0, 132.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_label = Label.new()
	_label.name = "Readout"
	_label.position = Vector2(20.0, 14.0)
	_label.add_theme_color_override("font_color", INK)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process(_delta: float) -> void:
	if _motion == null:
		_motion = _find_motion()
		if _motion != null:
			_motion.jogged.connect(func(_direction: Vector2) -> void: _jogs += 1)
	_label.text = "\n".join(_lines())


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var button := event as InputEventJoypadButton
	var toggled := (
		(key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY)
		or (button != null and button.pressed and button.button_index == TOGGLE_BUTTON)
	)
	if toggled:
		visible = not visible
		get_viewport().set_input_as_handled()


## The readout, worded so that each line rules something out: no source, a
## source reporting nothing, a live source held level, or tilt that is moving
## while the level stays still.
func _lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if _motion == null:
		lines.append("motion: no MotionInput in this scene")
		return lines

	var gravity := _motion.gravity
	var tilt := _motion.tilt
	lines.append("source: %s" % _motion.get_source_description())
	lines.append(
		(
			"gravity: %+5.2f %+5.2f %+5.2f   |g| %4.2f"
			% [gravity.x, gravity.y, gravity.z, gravity.length()]
		)
	)
	lines.append("tilt: %+.2f %+.2f   (%.0f%% of full)" % [tilt.x, tilt.y, tilt.length() * 100.0])
	lines.append("calibrated: %s   jogs: %d" % ["yes" if _motion.is_calibrated() else "no", _jogs])
	lines.append(_verdict(gravity, tilt))
	return lines


func _verdict(gravity: Vector3, tilt: Vector2) -> String:
	if gravity == Vector3.ZERO:
		return "reading nothing — source is silent"
	if not _motion.is_calibrated():
		return "waiting for a first reading to call level"
	if tilt.length() < RESTING_TILT:
		return "held level — tilt further, or recentre to re-level"
	return "tilting — anything still now is downstream of here"


## The level's own input first — a sibling, or one further up the branch this
## overlay sits on — and only then whatever else is in the group. Levels build
## one [MotionInput] each, so in a scene holding more than one (a test, or a
## level embedding another) the nearest is the one this overlay is reporting on.
func _find_motion() -> MotionInput:
	var branch := get_parent()
	while branch != null:
		for child in branch.get_children():
			var sibling := child as MotionInput
			if sibling != null:
				return sibling
		branch = branch.get_parent()
	for node in get_tree().get_nodes_in_group(MotionInput.GROUP_NAME):
		var motion := node as MotionInput
		if motion != null:
			return motion
	return null
