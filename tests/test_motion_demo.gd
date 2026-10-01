extends GutTest
## Covers the motion demo scene: it is the bring-up tool for a device nobody
## here can test against, so the least it can do is be known to run.

var _demo: Control


func before_each() -> void:
	_demo = load("res://core/motion/motion_demo.tscn").instantiate()
	add_child_autofree(_demo)


func test_the_readout_names_the_live_source() -> void:
	_demo._process(1.0 / 60.0)
	var readout := _demo.get_node("Readout") as Label
	assert_string_contains(readout.text, "source:", "The live source is the first thing to know")
	assert_string_contains(readout.text, "gravity:", "Raw axes are what settles a new device")


func test_it_owns_a_motion_input_of_its_own() -> void:
	assert_not_null(_demo.get_node_or_null("MotionInput"), "The demo drives its own input")
