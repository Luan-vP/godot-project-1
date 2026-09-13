extends GutTest
## Covers [ScoringIntensity]: the superlinear rule that makes floaters
## clustered on one edge score more than the same floaters scattered across
## several, built by hand like [ScoringSnapshot]'s own tests — no scene tree,
## no fluid simulation, no edge detector.


func test_an_empty_snapshot_has_zero_intensity() -> void:
	assert_eq(ScoringIntensity.compute(ScoringSnapshot.new()), 0.0)


func test_one_contact_scores_one() -> void:
	var snapshot := ScoringSnapshot.new([ScoringContact.new(1, 100, 0.5)])
	assert_eq(ScoringIntensity.compute(snapshot), 1.0)


func test_three_floaters_on_one_edge_score_more_than_scattered() -> void:
	var clustered := ScoringSnapshot.new(
		[
			ScoringContact.new(1, 100, 0.1),
			ScoringContact.new(1, 200, 0.4),
			ScoringContact.new(1, 300, 0.9),
		]
	)
	var scattered := ScoringSnapshot.new(
		[
			ScoringContact.new(1, 100, 0.1),
			ScoringContact.new(2, 200, 0.4),
			ScoringContact.new(3, 300, 0.9),
		]
	)
	assert_eq(ScoringIntensity.compute(clustered), 9.0, "3 squared")
	assert_eq(ScoringIntensity.compute(scattered), 3.0, "1 squared three times")
	assert_gt(
		ScoringIntensity.compute(clustered),
		ScoringIntensity.compute(scattered),
		"Same floaters, but stacking on one edge must be worth more"
	)


func test_two_and_one_split_scores_between_fully_clustered_and_fully_scattered() -> void:
	var split := ScoringSnapshot.new(
		[
			ScoringContact.new(1, 100, 0.1),
			ScoringContact.new(1, 200, 0.4),
			ScoringContact.new(2, 300, 0.9),
		]
	)
	assert_eq(ScoringIntensity.compute(split), 5.0, "2 squared plus 1 squared")


func test_a_floater_drifting_does_not_change_the_intensity() -> void:
	var before := ScoringSnapshot.new([ScoringContact.new(1, 100, 0.1)])
	var after := ScoringSnapshot.new([ScoringContact.new(1, 100, 0.99)])
	assert_eq(ScoringIntensity.compute(before), ScoringIntensity.compute(after))
