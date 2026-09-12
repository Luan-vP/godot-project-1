extends GutTest
## Covers the pure sampling functions behind a floater population: size
## distribution and shape-family odds, both checkable without a scene tree.

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 7


func test_sampled_radius_stays_within_range() -> void:
	for i in 50:
		var radius := FloaterField.sampled_radius(_rng, Vector2(2.0, 10.0), 1.8)
		assert_between(radius, 2.0, 10.0, "Within the configured range")


func test_a_high_skew_biases_towards_the_small_end() -> void:
	var low_skew_total := 0.0
	var high_skew_total := 0.0
	for i in 200:
		low_skew_total += FloaterField.sampled_radius(_rng, Vector2(0.0, 1.0), 1.0)
	for i in 200:
		high_skew_total += FloaterField.sampled_radius(_rng, Vector2(0.0, 1.0), 3.0)
	assert_lt(high_skew_total, low_skew_total, "Higher skew samples smaller on average")


func test_pick_family_only_returns_weighted_options() -> void:
	var counts := {0: 0, 1: 0, 2: 0}
	for i in 100:
		var family := FloaterField.pick_family(_rng, Vector3(1.0, 1.0, 1.0))
		counts[family] += 1
	assert_gt(counts[0], 0, "Dot chosen at least once")
	assert_gt(counts[1], 0, "Strand chosen at least once")
	assert_gt(counts[2], 0, "Cobweb chosen at least once")


func test_pick_family_ignores_a_zeroed_option() -> void:
	for i in 30:
		var family := FloaterField.pick_family(_rng, Vector3(1.0, 0.0, 1.0))
		assert_ne(family, 1, "Never picks a zero-weight family")


func test_pick_family_falls_back_to_dot_when_all_weights_are_zero() -> void:
	var family := FloaterField.pick_family(_rng, Vector3.ZERO)
	assert_eq(family, 0, "Fallback")


func test_pick_depth_is_minus_one_without_bands() -> void:
	var bands: Array[FloaterDepth] = []
	assert_eq(FloaterField.pick_depth(_rng, bands), -1, "No bands draws sharp, directly")


func test_pick_depth_ignores_a_zero_share_band() -> void:
	var bands: Array[FloaterDepth] = [
		FloaterDepth.make(1.0, 0.0, 1.0, 1.0, 1.0),
		FloaterDepth.make(0.0, 8.0, 1.0, 1.0, 1.0),
		FloaterDepth.make(1.0, 16.0, 1.0, 1.0, 1.0),
	]
	for i in 50:
		assert_ne(FloaterField.pick_depth(_rng, bands), 1, "Never picks a zero-share band")


func test_pick_depth_falls_back_to_the_first_band_when_all_shares_are_zero() -> void:
	var bands: Array[FloaterDepth] = [
		FloaterDepth.make(0.0, 0.0, 1.0, 1.0, 1.0), FloaterDepth.make(0.0, 8.0, 1.0, 1.0, 1.0)
	]
	assert_eq(FloaterField.pick_depth(_rng, bands), 0, "Fallback")


func test_a_family_range_overrides_the_shared_one() -> void:
	var field: FloaterField = autofree(FloaterField.new())
	field.radius_range = Vector2(2.0, 8.0)
	field.dot_radius_range = Vector2(0.5, 1.0)
	assert_eq(field.radius_range_for(0), Vector2(0.5, 1.0), "Dots use their own range")
	assert_eq(field.radius_range_for(1), Vector2(2.0, 8.0), "Strands fall back")
	assert_eq(field.radius_range_for(2), Vector2(2.0, 8.0), "Cobwebs fall back")


func test_motion_defaults_match_a_bare_floater() -> void:
	# The field copies these onto every floater, so defaults that drifted from
	# Floater's own would silently change every existing tank.
	var field: FloaterField = autofree(FloaterField.new())
	var floater: Floater = autofree(Floater.new())
	assert_eq(field.drag, floater.drag, "Drag")
	assert_eq(field.buoyancy, floater.buoyancy, "Buoyancy")
	assert_eq(field.max_speed, floater.max_speed, "Max speed")


func test_without_bands_floaters_are_direct_children_and_unrotated() -> void:
	var field := _populate(func(f: FloaterField): f.count = 20)
	var floaters := field.find_children("*", "Floater", false, false)
	assert_eq(floaters.size(), 20, "Every floater is a direct child")
	assert_eq(field.find_children("*", "SubViewport", false, false).size(), 0, "No layers")
	for floater in floaters:
		assert_eq(floater.rotation, 0.0, "Rotation is opt-in")


func test_bands_put_every_floater_in_a_layer() -> void:
	var field := _populate(
		func(f: FloaterField):
			f.count = 60
			f.depths = FloaterDepth.vitreous_bands()
	)
	assert_eq(field.find_children("*", "SubViewport", false, false).size(), 3, "One layer per band")
	assert_eq(field.find_children("*", "Floater", false, false).size(), 0, "None drawn directly")
	var total := 0
	for i in 3:
		var in_layer := field.get_layer(i).find_children("*", "Floater", false, false)
		total += in_layer.size()
		for floater in in_layer:
			assert_eq(floater.color, Color.WHITE, "A layer records coverage; the composite tints")
	assert_eq(total, 60, "The whole population is placed")


func test_nearer_bands_magnify_their_floaters() -> void:
	var field := _populate(
		func(f: FloaterField):
			f.count = 40
			f.shape_weights = Vector3(1.0, 0.0, 0.0)
			f.radius_range = Vector2(4.0, 4.0)
			f.depths = [
				FloaterDepth.make(1.0, 0.0, 1.0, 1.0, 1.0),
				FloaterDepth.make(1.0, 8.0, 1.0, 2.0, 1.0)
			]
	)
	for floater in field.get_layer(0).find_children("*", "Floater", false, false):
		assert_almost_eq(floater.radius, 4.0, 0.001, "Far band keeps its size")
	for floater in field.get_layer(1).find_children("*", "Floater", false, false):
		assert_almost_eq(floater.radius, 8.0, 0.001, "Near band is magnified")


func test_line_width_is_constant_in_pixels_whatever_the_length() -> void:
	var field := _populate(
		func(f: FloaterField):
			f.count = 30
			f.shape_weights = Vector3(0.0, 1.0, 0.0)
			f.radius_range = Vector2(5.0, 40.0)
			f.line_width_px = 1.5
			f.random_rotation = true
	)
	var rotated := 0
	for floater in field.find_children("*", "Floater", false, false):
		var drawn_width: float = floater.shape.strand_width * floater.radius
		assert_almost_eq(drawn_width, 1.5, 0.001, "Width in pixels")
		if floater.rotation != 0.0:
			rotated += 1
	assert_gt(rotated, 0, "Random rotation spins strands")


func test_turning_defocus_off_shows_bands_sharp() -> void:
	var field := _populate(
		func(f: FloaterField):
			f.count = 10
			f.depths = FloaterDepth.vitreous_bands()
	)
	var composites := field.find_children("*", "Sprite2D", false, false)
	var near: ShaderMaterial = composites[2].material
	assert_almost_eq(near.get_shader_parameter("radius_px"), 14.0, 0.001, "Near band blurred")
	field.defocus_enabled = false
	assert_eq(near.get_shader_parameter("radius_px"), 0.0, "Sharp with defocus off")
	assert_eq(near.get_shader_parameter("gain"), 1.0, "No coverage boost when sharp")


## A field in the tree over a real tank, configured by [param setup] before it
## enters so its _ready sees the settings.
func _populate(setup: Callable) -> FloaterField:
	var tank := FluidSimulation.new()
	tank.config = FluidConfig.new()
	tank.config.world_size = Vector2(400.0, 300.0)
	tank.config.simulation_resolution = 32
	add_child_autofree(tank)
	var field := FloaterField.new()
	field.simulation_path = tank.get_path()
	setup.call(field)
	add_child_autofree(field)
	return field
