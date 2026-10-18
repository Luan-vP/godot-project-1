extends GutTest
## Covers the carousel's variant slots: the spout (fluid, balls or sticky
## balls, a third each) and the flock (waterboatmen or birds, 50:50), picked
## on arrival, while the eye band and a carousel of one always play their own
## level.


func test_the_spout_has_three_variants_and_the_flock_two() -> void:
	assert_eq(FluidCarousel.VARIANTS.size(), 2, "Two variant slots")
	assert_eq(FluidCarousel.VARIANTS[0].size(), 3, "Spout A, B and C")
	assert_eq(FluidCarousel.VARIANTS[1].size(), 2, "Waterboatmen and birds")
	for group in FluidCarousel.VARIANTS:
		for path in group:
			assert_true(ResourceLoader.exists(path), path)
	assert_true(FluidCarousel.VARIANTS[0].has(FluidCarousel.LEVELS[1]), "The spout slot")
	assert_true(FluidCarousel.VARIANTS[1].has(FluidCarousel.LEVELS[2]), "The flock slot")
	for group in FluidCarousel.VARIANTS:
		assert_false(group.has(FluidCarousel.LEVELS[0]), "The eye band stands alone")


func test_arriving_at_a_slot_picks_each_variant_about_as_often() -> void:
	var carousel := FluidCarousel.new()
	carousel.rng.seed = 7
	autofree(carousel)
	var draws := 600
	for slot in [1, 2]:
		var group := FluidCarousel.VARIANTS[slot - 1]
		var counts := {}
		for i in draws:
			var path := carousel.path_for(slot)
			assert_true(group.has(path), "One of the group")
			counts[path] = counts.get(path, 0) + 1
		var share := float(draws) / group.size()
		for path in group:
			assert_between(
				counts.get(path, 0), int(share * 0.8), int(share * 1.2), "%s its share" % path
			)
	for i in 20:
		assert_eq(carousel.path_for(0), FluidCarousel.LEVELS[0], "The eye band every time")


func test_a_carousel_of_one_plays_exactly_its_level() -> void:
	var solo := FluidCarousel.new()
	autofree(solo)
	solo.level_paths = [FluidCarousel.VARIANTS[0][1]] as Array[String]
	for i in 20:
		assert_eq(solo.path_for(0), FluidCarousel.VARIANTS[0][1], "Spout B, never A")
