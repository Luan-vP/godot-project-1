extends SceneTree
## Live motion readout in a terminal, for bring-up on a device.
##
##   godot --headless --path . -s core/motion/stream_tilt.gd
##
## Ctrl+C stops it. It runs the whole [MotionInput] pipeline, so what it prints
## is what a level would see: the source that was picked, raw gravity, and the
## tilt left after calibration, dead zone and smoothing.
##
## The number to watch first is [b]|g|[/b]. A resting device reads about 9.81
## in every orientation; a magnitude that changes as it turns means the units
## or the axes are wrong, however plausible the direction looks. That check
## caught a reverse-engineered HID decode reading 0.92 g upright and 0.49 g in
## a stand — see [code]core/motion/README.md[/code].

## How often a line is printed, in hertz.
const HZ := 10.0


func _init() -> void:
	var motion := MotionInput.new()
	get_root().add_child(motion)
	# A SceneTree script builds its nodes before the tree starts running them,
	# so the probe that picks a source has to be asked for by hand.
	if motion.get_source() == null:
		motion._ready()
	print("source: %s" % motion.get_source_description())
	print("full tilt at %.0f degrees from the pose it started in\n" % motion.tilt_span_degrees)
	print("  gravity (m/s^2)          |g|    tilt             %full")
	while true:
		for _frame in int(60.0 / HZ):
			motion._process(1.0 / 60.0)
			OS.delay_msec(16)
		var g := motion.gravity
		var tilt := motion.tilt
		printraw(
			(
				"\r  %+6.2f %+6.2f %+6.2f  %5.2f   %+.3f %+.3f    %3.0f%%   "
				% [g.x, g.y, g.z, g.length(), tilt.x, tilt.y, tilt.length() * 100.0]
			)
		)
