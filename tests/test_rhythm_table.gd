extends GutTest
## Covers [RhythmTable]: the grid is derived from whatever rhythms are in the
## table, pulses land where they should, and tapping only boosts the roll for
## rhythms that are not already on screen.


func _table(pulse_counts: Array[int]) -> RhythmTable:
	var rhythms: Array[Rhythm] = []
	for pulses in pulse_counts:
		rhythms.append(Rhythm.create(pulses, 1.0, Color.WHITE))
	return RhythmTable.new(rhythms)


func test_grid_is_the_lcm_of_every_rhythm_and_the_bar() -> void:
	assert_eq(RhythmTable.default_table().grid_steps(4), 12, "3, 4, 6 in 4/4")
	assert_eq(_table([3, 4, 5, 6]).grid_steps(4), 60, "Adding 5")
	assert_eq(_table([3, 4, 5, 6, 7]).grid_steps(4), 420, "Adding 7")
	assert_eq(_table([3, 4, 6]).grid_steps(3), 12, "3/4 bar still 12")
	assert_eq(_table([3]).grid_steps(4), 12, "A lone 3 in 4/4 still needs the beats")


func test_pulses_land_evenly_on_the_grid() -> void:
	assert_eq(RhythmTable.pulse_steps(3, 12), [0, 4, 8] as Array[int], "3 on 12")
	assert_eq(RhythmTable.pulse_steps(4, 12), [0, 3, 6, 9] as Array[int], "4 on 12")
	assert_eq(RhythmTable.pulse_steps(5, 60), [0, 12, 24, 36, 48] as Array[int], "5 on 60")


func test_default_table_is_three_four_and_six() -> void:
	var table := RhythmTable.default_table()
	assert_eq(table.pulse_counts(), [3, 4, 6] as Array[int], "Pulse counts")
	assert_eq(table.min_pulses(), 3, "Fewest pulses")
	assert_eq(table.get_rhythm(6).pulses, 6, "Finds 6")
	assert_null(table.get_rhythm(5), "No 5 yet")


func test_bias_boosts_only_rhythms_not_on_screen() -> void:
	var table := RhythmTable.default_table()
	var on_screen: Array[int] = [3, 4]
	var weights := table.spawn_weights(on_screen, {3: 1.0, 6: 1.0}, 4.0)
	assert_almost_eq(weights[0], 1.0, 0.0001, "3 is on screen: no boost")
	assert_almost_eq(weights[1], 1.0, 0.0001, "4 was not tapped")
	assert_almost_eq(weights[2], 2.5, 0.0001, "6 missing and tapped: 0.5 x (1 + 4)")


func test_roll_follows_the_weights() -> void:
	var table := RhythmTable.default_table()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var on_screen: Array[int] = [3, 4]
	var counts := {3: 0, 4: 0, 6: 0}
	for i in 2000:
		counts[table.roll(rng, on_screen, {6: 1.0}, 4.0)] += 1
	# Weights 1 : 1 : 2.5, so 6 should come up about half the time.
	assert_between(counts[6], 900, 1200, "Tapped, missing 6 favoured")
	assert_between(counts[3], 300, 600, "3 at its base weight")


func test_empty_table_rolls_nothing() -> void:
	assert_eq(RhythmTable.new().roll(RandomNumberGenerator.new()), 0, "Nothing to roll")
