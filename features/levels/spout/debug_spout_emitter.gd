class_name DebugSpoutEmitter
extends SpoutEmitter
## The shell's stand-in emitter, until a version brings its own: Space plucks
## the pin the spout is pointing at, so the pins and the scale can be heard
## and checked with nothing coming out of the nozzle.

var _plucks := 0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_SPACE:
		var pin := aimed_pin()
		if pin >= 0 and pins.hit(pin, 0.8):
			_plucks += 1
		get_viewport().set_input_as_handled()


## The pin nearest where the spout's line of aim crosses the middle of the
## field.
func aimed_pin() -> int:
	if spout == null or pins == null or pins.pin_count() == 0:
		return -1
	var field_y := pins.to_global(pins.area.get_center()).y
	var origin := spout.muzzle_position()
	var dir := spout.direction()
	var along := (field_y - origin.y) / maxf(dir.y, 0.001)
	var target := origin + dir * along
	var best := -1
	var best_distance := INF
	for pin in pins.pin_count():
		var distance := pins.to_global(pins.pin_position(pin)).distance_to(target)
		if distance < best_distance:
			best = pin
			best_distance = distance
	return best


func describe() -> String:
	return "debug emitter · %d plucks" % _plucks


func controls_hint() -> String:
	return "Space plucks the pin you aim at"
