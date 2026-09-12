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
