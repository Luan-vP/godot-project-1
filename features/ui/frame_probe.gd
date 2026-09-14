class_name FrameProbe
extends Node
## Walks the demo menu through demos unattended and reports on each: frame
## rate, whether its fluid tank is really solving, and a screenshot.
##
## A phone gives no console to watch and no hands to stir, and the one thing
## most worth knowing on a new device is whether the compute solve runs at all
## — a tank whose shaders failed looks the same as a calm one. So for every
## tank this pushes a synthetic touch drag through [Input], the same path a
## finger takes, and compares the peak speed in the tank's CPU mirror before
## and after: a solve that is not running reads zero both times.
##
## Started by [DemoMenu] from the command line:
## [codeblock lang=text]
## --probe            every demo in the menu
## --probe=eyes,vitreous
## [/codeblock]
## Results are printed and appended to [code]user://probe/probe.log[/code],
## with a PNG per demo beside it. On an iPhone that folder is the app's
## Documents directory; see "Building for iPhone" in the README.

## Emitted once every demo has been visited and the menu is back.
signal finished(report: Array[Dictionary])

const OUTPUT_DIR := "user://probe"

## Tanks sit still for a moment while they build their device resources, and
## the first frames pay for pipeline compilation. Neither is the frame rate.
const WARMUP_SECONDS := 3.0
const MEASURE_SECONDS := 6.0
const DRAG_SECONDS := 1.2
const SETTLE_SECONDS := 0.5

var demos: Array[Dictionary] = []

var _menu: DemoMenu
var _report: Array[Dictionary] = []


func _init(menu: DemoMenu = null, which: Array[Dictionary] = []) -> void:
	_menu = menu
	demos = which


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_log(
		(
			"probe: %s, %s, %s on %s, canvas %s, window %s"
			% [
				OS.get_model_name(),
				RenderingServer.get_video_adapter_name(),
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_current_rendering_driver_name(),
				get_viewport().get_visible_rect().size,
				DisplayServer.window_get_size(),
			]
		)
	)
	_run.call_deferred()


## Average and worst frame rate over a run of frame times, in seconds.
## Worst is the single slowest frame, which is what a player feels as a hitch.
static func summarize(frame_times: PackedFloat32Array) -> Dictionary:
	var total := 0.0
	var slowest := 0.0
	for step in frame_times:
		total += step
		slowest = maxf(slowest, step)
	if frame_times.is_empty() or total <= 0.0:
		return {"frames": 0, "average_fps": 0.0, "worst_fps": 0.0}
	return {
		"frames": frame_times.size(),
		"average_fps": frame_times.size() / total,
		"worst_fps": 1.0 / slowest,
	}


## Fastest current anywhere in a tank's CPU mirror, in cells/second.
static func peak_speed(field: FluidField) -> float:
	var size := field.get_size()
	var peak := 0.0
	for y in size.y:
		for x in size.x:
			peak = maxf(peak, field.get_cell_velocity(x, y).length())
	return peak


func _run() -> void:
	await _capture_menu()
	for demo in demos:
		_menu.open_demo(demo["path"])
		var result := await _probe(demo)
		_report.append(result)
		_menu.close_demo()
		await get_tree().process_frame
	_log("probe: done")
	finished.emit(_report)


func _capture_menu() -> void:
	await _wait(1.0)
	_screenshot("menu")


func _probe(demo: Dictionary) -> Dictionary:
	var slug := String(demo["name"]).to_snake_case()
	await _wait(WARMUP_SECONDS)

	var tank := _find_tank()
	var still := peak_speed(tank.get_field()) if tank != null else 0.0
	if tank != null:
		await _drag_across_screen()
		await _wait(SETTLE_SECONDS)
	var stirred := peak_speed(tank.get_field()) if tank != null else 0.0

	var times := PackedFloat32Array()
	var until := Time.get_ticks_msec() + int(MEASURE_SECONDS * 1000.0)
	while Time.get_ticks_msec() < until:
		times.append(await _frame())
	_screenshot(slug)

	var result := summarize(times)
	result["name"] = demo["name"]
	result["tank"] = tank != null
	result["compute"] = FluidGPU.is_available()
	result["peak_before"] = still
	result["peak_after"] = stirred
	_log(
		(
			(
				"probe: %-12s %5.1f fps avg, %5.1f worst over %d frames"
				+ " | tank %s, compute %s, peak %.1f -> %.1f cells/s"
			)
			% [
				demo["name"],
				result["average_fps"],
				result["worst_fps"],
				result["frames"],
				result["tank"],
				result["compute"],
				still,
				stirred,
			]
		)
	)
	return result


## The running demo's tank. Only its own: a demo just closed is still in the
## tree until the end of the frame, and its tank must not be measured instead.
func _find_tank() -> FluidSimulation:
	var demo := _menu.get_demo()
	if demo == null:
		return null
	for node in get_tree().get_nodes_in_group(FluidSimulation.GROUP_NAME):
		if node is FluidSimulation and demo.is_ancestor_of(node):
			return node
	return null


## A finger drawing a loop through the middle of the screen, delivered as real
## touch events so the demos' own mouse-emulated stirring is what gets tested.
func _drag_across_screen() -> void:
	var window := Vector2(DisplayServer.window_get_size())
	var centre := window * 0.5
	var radius := window.x * 0.25
	var start := centre + Vector2(radius, 0.0)
	_touch(start, true)
	var previous := start
	var elapsed := 0.0
	while elapsed < DRAG_SECONDS:
		elapsed += await _frame()
		var angle := TAU * elapsed / DRAG_SECONDS
		var here := centre + Vector2(cos(angle), sin(angle)) * radius
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = here
		drag.relative = here - previous
		drag.velocity = drag.relative * Engine.get_frames_per_second()
		Input.parse_input_event(drag)
		previous = here
	_touch(previous, false)


func _touch(where: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = where
	touch.pressed = pressed
	Input.parse_input_event(touch)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frame() -> float:
	var before := Time.get_ticks_usec()
	await get_tree().process_frame
	return (Time.get_ticks_usec() - before) / 1_000_000.0


func _screenshot(slug: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, slug]
	image.save_png(path)
	_log("probe: saved %s" % ProjectSettings.globalize_path(path))


func _log(line: String) -> void:
	print(line)
	var path := "%s/probe.log" % OUTPUT_DIR
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
