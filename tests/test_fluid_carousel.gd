extends GutTest
## Covers the fluid carousel: how a level finds the shared layers it is hosted
## by, how a slide moves a level and its HUD, and the order and lock-out of
## transitions. Stand-in levels take the place of the real three, so no level's
## own audio or physics has to run; the carousel's shared tank and band do
## start, as they do in the boids level's own tests.

const STAND_IN_NAMES: Array[String] = ["StandInA", "StandInB", "StandInC"]
const STAND_IN_DIR := "user://test_fluid_carousel_"

var _carousel: FluidCarousel


func before_all() -> void:
	for stand_in_name in STAND_IN_NAMES:
		var level := Node2D.new()
		level.name = stand_in_name
		var layer := CanvasLayer.new()
		layer.name = "Hud"
		layer.offset = Vector2(12.0, 5.0)
		level.add_child(layer)
		layer.owner = level
		var packed := PackedScene.new()
		packed.pack(level)
		ResourceSaver.save(packed, _stand_in_path(stand_in_name))
		level.free()


func after_all() -> void:
	for stand_in_name in STAND_IN_NAMES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_stand_in_path(stand_in_name)))


func before_each() -> void:
	_carousel = FluidCarousel.new()
	_carousel.dwell_seconds = 0.0
	_carousel.slide_seconds = 0.0
	var paths: Array[String] = []
	for stand_in_name in STAND_IN_NAMES:
		paths.append(_stand_in_path(stand_in_name))
	_carousel.level_paths = paths
	add_child_autofree(_carousel)


func after_each() -> void:
	AudioManager.set_tempo(120.0, 4)


func _stand_in_path(stand_in_name: String) -> String:
	return "%s%s.tscn" % [STAND_IN_DIR, stand_in_name]


func test_the_real_levels_are_the_three_fluid_ones_in_order() -> void:
	assert_eq(FluidCarousel.LEVELS.size(), 3, "Three levels")
	for path in FluidCarousel.LEVELS:
		assert_true(ResourceLoader.exists(path), path)
	assert_true(FluidCarousel.LEVELS[0].ends_with("eye_band_demo.tscn"), "Eye band first")
	assert_true(FluidCarousel.LEVELS[1].ends_with("level_three_a.tscn"), "Then spout A")
	assert_true(FluidCarousel.LEVELS[2].ends_with("boids_level.tscn"), "Then the boatmen")


func test_the_birds_carousel_swaps_the_waterboatmen_for_the_birds() -> void:
	var birds_carousel: FluidCarousel = (
		load("res://features/levels/carousel/fluid_carousel_birds.tscn").instantiate()
	)
	var paths := birds_carousel.level_paths
	birds_carousel.free()
	assert_eq(paths.size(), 3, "Three levels")
	for path in paths:
		assert_true(ResourceLoader.exists(path), path)
	assert_true(paths[0].ends_with("eye_band_demo.tscn"), "Eye band first")
	assert_true(paths[1].ends_with("level_three_a.tscn"), "Then spout A")
	assert_true(paths[2].ends_with("birds_level.tscn"), "Then the birds")
	assert_eq(FluidCarousel.LEVELS[2], "res://features/levels/boids/boids_level.tscn", "Original")
	var original: FluidCarousel = (
		load("res://features/levels/carousel/fluid_carousel.tscn").instantiate()
	)
	assert_eq(original.level_paths, FluidCarousel.LEVELS, "The original carousel is unchanged")
	original.free()


func test_find_returns_the_hosting_layers_from_any_depth() -> void:
	var shared := SharedLayers.new()
	var level := Node2D.new()
	var child := Node2D.new()
	shared.add_child(level)
	level.add_child(child)
	assert_eq(SharedLayers.find(level), shared, "A level directly under")
	assert_eq(SharedLayers.find(child), shared, "A node further down")
	shared.free()


func test_find_is_null_for_a_node_standing_alone() -> void:
	var lone := Node2D.new()
	var parent := Node2D.new()
	parent.add_child(lone)
	assert_null(SharedLayers.find(lone), "No SharedLayers above")
	assert_null(SharedLayers.find(parent), "Nor above the root of the branch")
	parent.free()


func test_the_first_level_is_hosted_at_rest() -> void:
	var level := _carousel.current_level()
	assert_eq(level.name, &"StandInA", "The first path")
	assert_eq(
		SharedLayers.find(level), _carousel.shared_layers(), "Hosted by the carousel's layers"
	)
	assert_eq(level.position.x, 0.0, "At rest")
	assert_eq(_carousel.current_index(), 0, "Index 0")


func test_the_shared_layers_hold_a_tank_and_a_band_under_the_levels() -> void:
	var shared := _carousel.shared_layers()
	assert_not_null(shared.fluid, "Fluid")
	assert_not_null(shared.band, "Band")
	assert_eq(shared.get_child(shared.get_child_count() - 1), shared.stage, "Stage added last")
	assert_eq(
		shared.fluid.config.world_size, get_viewport().get_visible_rect().size, "Viewport size"
	)


func test_place_offsets_canvas_layers_from_their_own_base() -> void:
	var level := Node2D.new()
	var layer := CanvasLayer.new()
	layer.offset = Vector2(16.0, 9.0)
	var nested := Node2D.new()
	var deep := CanvasLayer.new()
	deep.offset = Vector2(-4.0, 2.0)
	level.add_child(layer)
	level.add_child(nested)
	nested.add_child(deep)
	add_child_autofree(level)

	_carousel._place(level, 300.0)
	assert_eq(level.position.x, 300.0, "The node moves")
	assert_eq(layer.offset, Vector2(316.0, 9.0), "Layer offset is base plus x, y untouched")
	assert_eq(deep.offset, Vector2(296.0, 2.0), "Nested layers too")

	_carousel._place(level, -100.0)
	assert_eq(layer.offset.x, -84.0, "Always from the base, not cumulative")

	_carousel._place(level, 0.0)
	assert_eq(layer.offset, Vector2(16.0, 9.0), "Back at rest, back at the base")
	assert_eq(deep.offset, Vector2(-4.0, 2.0), "Nested too")


func test_advance_cycles_through_the_levels_and_loops() -> void:
	var seen: Array[int] = []
	_carousel.level_changed.connect(func(index: int) -> void: seen.append(index))
	for i in 3:
		_carousel.advance()
	assert_eq(seen, [1, 2, 0] as Array[int], "0 to 1 to 2 and round to 0")
	assert_eq(_carousel.current_index(), 0, "Back at the start")
	# By scene, not name: with every slide instant the first level has only been
	# queued for freeing, so its name is still taken and the new one is renamed.
	assert_eq(
		_carousel.current_level().scene_file_path, _carousel.level_paths[0], "The first level again"
	)


func test_retreat_goes_the_other_way() -> void:
	_carousel.retreat()
	assert_eq(_carousel.current_index(), 2, "Back from the first wraps to the last")
	_carousel.retreat()
	assert_eq(_carousel.current_index(), 1, "And on")


func test_the_outgoing_level_is_freed_and_the_incoming_one_is_live() -> void:
	var first := _carousel.current_level()
	_carousel.advance()
	await get_tree().process_frame
	assert_false(is_instance_valid(first), "The outgoing level is gone")
	var stage := _carousel.shared_layers().stage
	assert_eq(stage.get_child_count(), 1, "Only the incoming level remains")
	assert_eq(
		_carousel.current_level().process_mode, Node.PROCESS_MODE_INHERIT, "Running once arrived"
	)
	assert_eq(_carousel.current_level().position.x, 0.0, "At rest")


func test_the_shared_layers_survive_every_transition() -> void:
	var shared := _carousel.shared_layers()
	var fluid := shared.fluid
	var band := shared.band
	for i in 3:
		_carousel.advance()
	assert_eq(_carousel.shared_layers(), shared, "Same layers")
	assert_eq(shared.fluid, fluid, "Same tank")
	assert_eq(shared.band, band, "Same band")
	assert_true(is_instance_valid(fluid), "Tank still alive")


func test_both_levels_are_frozen_and_offset_while_they_slide() -> void:
	_carousel.slide_seconds = 5.0
	var outgoing := _carousel.current_level()
	_carousel.advance()
	assert_true(_carousel.is_sliding(), "Sliding")
	var stage := _carousel.shared_layers().stage
	assert_eq(stage.get_child_count(), 2, "Both levels in the tree")
	var incoming := stage.get_child(1) as Node2D
	assert_eq(outgoing.process_mode, Node.PROCESS_MODE_DISABLED, "Outgoing frozen")
	assert_eq(incoming.process_mode, Node.PROCESS_MODE_DISABLED, "Incoming frozen")
	var width := _carousel.get_viewport_rect().size.x
	assert_eq(incoming.position.x, width, "The next level waits on the right")
	assert_eq((incoming.get_node("Hud") as CanvasLayer).offset.x, 12.0 + width, "Its HUD with it")


func test_a_slide_ends_with_the_incoming_level_at_rest() -> void:
	_carousel.slide_seconds = 0.1
	watch_signals(_carousel)
	_carousel.advance()
	await wait_for_signal(_carousel.level_changed, 2.0)
	assert_signal_emitted_with_parameters(_carousel, "level_changed", [1])
	assert_false(_carousel.is_sliding(), "Done sliding")
	var level := _carousel.current_level()
	assert_eq(level.position.x, 0.0, "At rest")
	assert_eq((level.get_node("Hud") as CanvasLayer).offset.x, 12.0, "HUD back at its base")


func test_advance_during_a_slide_is_ignored() -> void:
	_carousel.slide_seconds = 5.0
	_carousel.advance()
	var stage := _carousel.shared_layers().stage
	assert_true(_carousel.is_sliding(), "Mid-slide")
	_carousel.advance()
	_carousel.retreat()
	assert_eq(stage.get_child_count(), 2, "No third level was started")
	assert_eq(_carousel.current_index(), 0, "Still heading from the first level")


func test_a_transition_levels_out_the_tanks_current() -> void:
	var fluid := _carousel.shared_layers().fluid
	fluid.set_current_bias(Vector2(0.0, 45.0))
	_carousel.advance()
	assert_eq(fluid.get_current_bias(), Vector2.ZERO, "No lean carried into the next level")


func test_the_dwell_timer_advances_on_its_own() -> void:
	var timed := FluidCarousel.new()
	timed.dwell_seconds = 0.1
	timed.slide_seconds = 0.0
	timed.level_paths = _carousel.level_paths
	add_child_autofree(timed)
	await wait_for_signal(timed.level_changed, 2.0)
	assert_eq(timed.current_index(), 1, "Moved on after the dwell")
