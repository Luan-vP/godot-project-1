extends GutTest
## Covers the game's one tank: started by its first user and never again,
## shared by everything that holds it, asleep (paused, hidden, out of the
## tank group) once nothing does, and keeping its build fields when a holder
## brings its own motion. The tank is the autoload, so it may already have
## been started by an earlier test; nothing here assumes it is fresh.


func test_every_holder_gets_the_same_tank() -> void:
	var a := _holder()
	var b := _holder()
	var first := Tank.acquire(a)
	assert_true(Tank.is_started(), "Started")
	assert_same(Tank.acquire(b), first, "One tank")
	assert_same(Tank.fluid, first, "The autoload's own")
	assert_true(Tank.is_ancestor_of(first), "Lives under the autoload, not the holder")


func test_it_sleeps_once_nobody_holds_it_and_keeps_its_water() -> void:
	var holder := _holder()
	var fluid := Tank.acquire(holder)
	fluid.set_current_bias(Vector2(3.0, 0.0))
	assert_true(Tank.is_held(), "Held")
	assert_true(Tank.visible and fluid.simulating, "Awake")
	assert_true(fluid.is_in_group(FluidSimulation.GROUP_NAME), "Findable by bodies")
	holder.queue_free()
	await get_tree().process_frame
	assert_false(Tank.is_held(), "Let go by leaving the tree")
	assert_false(Tank.visible, "Hidden")
	assert_false(fluid.simulating, "Paused")
	assert_false(fluid.is_in_group(FluidSimulation.GROUP_NAME), "Out of the group")
	var again := _holder()
	assert_same(Tank.acquire(again), fluid, "The same tank for the next holder")
	assert_eq(fluid.get_current_bias(), Vector2(3.0, 0.0), "Its state kept")
	assert_true(fluid.simulating, "Awake again")
	fluid.set_current_bias(Vector2.ZERO)


func test_release_by_hand_and_then_leaving_is_harmless() -> void:
	var holder := _holder()
	Tank.acquire(holder)
	Tank.release(holder)
	assert_false(Tank.is_held(), "Let go")
	holder.queue_free()
	await get_tree().process_frame
	assert_false(Tank.is_held(), "Still let go")


func test_a_holders_motion_leaves_the_tank_its_size() -> void:
	var holder := _holder()
	var fluid := Tank.acquire(holder)
	var size := fluid.config.world_size
	var motion := FluidConfig.new()
	motion.dye_dissipation = 1.0
	motion.vorticity = 3.0
	motion.world_size = Vector2(10.0, 10.0)
	motion.simulation_resolution = 64
	Tank.set_motion(motion)
	assert_eq(fluid.config.dye_dissipation, 1.0, "Motion taken")
	assert_eq(fluid.config.vorticity, 3.0, "Motion taken")
	assert_eq(fluid.config.world_size, size, "Size kept")
	assert_eq(fluid.config.simulation_resolution, Tank.RESOLUTION, "Grid kept")
	Tank.set_motion(FluidConfig.new())


func test_held_within_finds_the_tank_only_under_a_holder() -> void:
	var root := _holder()
	var holder := Node.new()
	root.add_child(holder)
	var elsewhere := _holder()
	Tank.acquire(holder)
	assert_same(Tank.held_within(root), Tank.fluid, "A holder underneath")
	assert_null(Tank.held_within(elsewhere), "Nothing holding it there")


func test_the_carousels_layers_hold_the_tank() -> void:
	var shared := SharedLayers.new()
	add_child_autofree(shared)
	assert_same(shared.fluid, Tank.fluid, "The game's tank")
	assert_same(Tank.held_within(shared), Tank.fluid, "Held by the layers")


func test_a_look_blends_every_colour_and_number() -> void:
	var from := PainterlyStyle.new()
	from.paper_color = Color.BLACK
	from.stroke_size = 2.0
	from.absorption = Vector3.ZERO
	var to := PainterlyStyle.new()
	to.paper_color = Color.WHITE
	to.stroke_size = 4.0
	to.absorption = Vector3.ONE
	var into := PainterlyStyle.new()
	PainterlyStyle.blend_into(into, from, to, 0.5)
	assert_eq(into.paper_color, Color(0.5, 0.5, 0.5), "Colour")
	assert_eq(into.stroke_size, 3.0, "Number")
	assert_eq(into.absorption, Vector3(0.5, 0.5, 0.5), "Vector")
	PainterlyStyle.blend_into(into, from, to, 1.0)
	assert_eq(into.paper_color, Color.WHITE, "All the way")


func test_a_new_holders_look_eases_in() -> void:
	var holder := _holder()
	var dark := PainterlyStyle.new()
	dark.paper_color = Color.BLACK
	Tank.acquire(holder, null, dark)
	Tank.set_look(dark, 0.0)
	assert_eq(Tank.renderer.style.paper_color, Color.BLACK, "At once")
	var light := PainterlyStyle.new()
	Tank.set_look(light)
	Tank._process(Tank.BLEND_SECONDS * 0.5)
	var paper := Tank.renderer.style.paper_color
	assert_true(paper != Color.BLACK and paper != light.paper_color, "Part way")
	Tank._process(Tank.BLEND_SECONDS)
	assert_eq(Tank.renderer.style.paper_color, light.paper_color, "Arrived")


func _holder() -> Node:
	var node := Node.new()
	add_child_autofree(node)
	return node
