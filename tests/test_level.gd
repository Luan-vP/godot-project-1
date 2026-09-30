extends GutTest
## Covers [Level]'s defaults and the two example presets — the only proof
## the resource actually abstracts a level rather than just moving the same
## numbers somewhere else.


func test_defaults_are_usable() -> void:
	var level := Level.new()
	assert_gt(level.floater_count, 0, "A level should show some floaters by default")
	assert_gt(level.floater_radius_range.y, level.floater_radius_range.x, "A real range")
	assert_gt(level.floater_size_skew, 0.0, "Skew must stay positive")
	assert_between(level.distortion_strength, 0.0, 0.1, "Within RefractionStyle's range")
	assert_almost_eq(level.look_sensitivity, 1.0, 0.0001, "Neutral by default")


func test_fluid_config_is_a_reference_not_inlined_fields() -> void:
	# The whole point of the split: a level points at a FluidConfig instead of
	# copying its numbers, so the medium can be retuned once and reused.
	var shared_medium := FluidConfig.new()
	var a := Level.new()
	var b := Level.new()
	a.fluid_config = shared_medium
	b.fluid_config = shared_medium
	shared_medium.vorticity = 33.0
	assert_eq(a.fluid_config.vorticity, 33.0, "Retuning the shared medium reaches level a")
	assert_eq(b.fluid_config.vorticity, 33.0, "...and level b, since both reference it")


func test_edge_source_is_a_reference_not_inlined_geometry() -> void:
	# The same split as fluid_config: a level points at an EdgeSource instead
	# of owning edge geometry itself, so a hand-authored overlay or a future
	# detector can be swapped in without Level changing.
	var shared_edges := ManualEdgeSource.new()
	shared_edges.edges_degrees = [PackedVector2Array([Vector2(0.0, 0.0), Vector2(10.0, 0.0)])]
	var a := Level.new()
	var b := Level.new()
	a.edge_source = shared_edges
	b.edge_source = shared_edges
	assert_eq(a.edge_source.get_edges().size(), 1)
	assert_eq(b.edge_source, a.edge_source, "Both levels reference the same source")


func test_edge_source_defaults_to_null() -> void:
	# A level with no edges to score is valid — it simply has none configured.
	var level := Level.new()
	assert_null(level.edge_source)


func test_overcast_sky_and_dim_interior_read_differently() -> void:
	var overcast := Level.overcast_sky()
	var interior := Level.dim_interior()

	assert_true(overcast.panorama_texture is Texture2D, "Overcast has a background")
	assert_true(interior.panorama_texture is Texture2D, "Interior has a background")
	assert_ne(overcast.fluid_config, interior.fluid_config, "Each preset owns its own medium")

	assert_gt(overcast.floater_count, interior.floater_count * 5, "Unmissable vs barely there")
	assert_gt(overcast.distortion_strength, interior.distortion_strength * 5, "Visibly more bend")

	var overcast_top := (overcast.panorama_texture as ImageTexture).get_image().get_pixel(0, 0)
	var interior_top := (interior.panorama_texture as ImageTexture).get_image().get_pixel(0, 0)
	assert_gt(
		overcast_top.r + overcast_top.g + overcast_top.b,
		interior_top.r + interior_top.g + interior_top.b,
		"Overcast sky reads brighter than the interior"
	)


func test_pure_exploration_has_no_score_goal_or_edges() -> void:
	# Issue #22: level 1 is pure exploration — no scoring is configured, and
	# none of Level's own fields describe a timer or an end condition.
	var level := Level.pure_exploration()
	assert_null(level.edge_source, "Nothing to score floaters against")


func test_pure_exploration_favors_legibility_over_overcast_skys_drama() -> void:
	var exploration := Level.pure_exploration()
	var overcast := Level.overcast_sky()
	var interior := Level.dim_interior()

	assert_true(exploration.panorama_texture is Texture2D, "Has a background")
	assert_gt(exploration.floater_count, interior.floater_count, "More than barely there")
	assert_gt(
		overcast.floater_count, exploration.floater_count, "Fewer than overcast's crowded field"
	)
	assert_gt(
		overcast.distortion_strength,
		exploration.distortion_strength,
		"Less bend than overcast, so the background does not fight a floater for attention"
	)
	assert_gt(
		exploration.floater_radius_range.x,
		0.0,
		"Floaters are large enough to track, not tiny specks"
	)
