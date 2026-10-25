extends GutTest
## Covers the carousel's variant slot: the flock (waterboatmen or birds,
## 50:50), picked on arrival, while the eye band, the spout and a carousel of
## one always play their own level.


func test_the_flock_has_two_variants_and_the_spout_one_level() -> void:
	assert_eq(FluidCarousel.VARIANTS.size(), 1, "One variant slot")
	assert_eq(FluidCarousel.VARIANTS[0].size(), 2, "Waterboatmen and birds")
	for group in FluidCarousel.VARIANTS:
		for path in group:
			assert_true(ResourceLoader.exists(path), path)
	assert_true(FluidCarousel.VARIANTS[0].has(FluidCarousel.LEVELS[2]), "The flock slot")
	for group in FluidCarousel.VARIANTS:
		assert_false(group.has(FluidCarousel.LEVELS[0]), "The eye band stands alone")
		assert_false(group.has(FluidCarousel.LEVELS[1]), "So does the spout")


func test_arriving_at_the_flock_picks_each_variant_about_as_often() -> void:
	var carousel := FluidCarousel.new()
	carousel.rng.seed = 7
	autofree(carousel)
	var draws := 600
	var group := FluidCarousel.VARIANTS[0]
	var counts := {}
	for i in draws:
		var path := carousel.path_for(2)
		assert_true(group.has(path), "One of the group")
		counts[path] = counts.get(path, 0) + 1
	var share := float(draws) / group.size()
	for path in group:
		assert_between(
			counts.get(path, 0), int(share * 0.8), int(share * 1.2), "%s its share" % path
		)
	for i in 20:
		assert_eq(carousel.path_for(0), FluidCarousel.LEVELS[0], "The eye band every time")
		assert_eq(carousel.path_for(1), FluidCarousel.LEVELS[1], "The spout every time")


func test_a_carousel_of_one_plays_exactly_its_level() -> void:
	var solo := FluidCarousel.new()
	autofree(solo)
	solo.level_paths = [FluidCarousel.VARIANTS[0][1]] as Array[String]
	for i in 20:
		assert_eq(solo.path_for(0), FluidCarousel.VARIANTS[0][1], "The birds, never the boatmen")
