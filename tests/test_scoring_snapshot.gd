extends GutTest
## Covers [ScoringSnapshot] and [ScoringContact] built by hand — no scene
## tree, no fluid simulation, no edge detector. This is the data contract
## between the scorer (#26) and the music system (#33, #34), so it has to be
## usable without either of them running.


func test_contacts_for_edge_only_returns_that_edge() -> void:
	var snapshot := ScoringSnapshot.new([
		ScoringContact.new(1, 100, 0.25),
		ScoringContact.new(2, 200, 0.75),
		ScoringContact.new(1, 300, 0.5),
	])
	var on_edge_one := snapshot.contacts_for_edge(1)
	assert_eq(on_edge_one.size(), 2, "Only edge 1's contacts")
	for contact in on_edge_one:
		assert_eq(contact.edge_id, 1)


func test_count_for_edge_reflects_how_many_floaters_share_it() -> void:
	var snapshot := ScoringSnapshot.new([
		ScoringContact.new(1, 100, 0.1),
		ScoringContact.new(1, 200, 0.9),
	])
	assert_eq(snapshot.count_for_edge(1), 2)
	assert_eq(snapshot.count_for_edge(2), 0, "An edge with no contacts")


func test_active_edges_lists_each_edge_once() -> void:
	var snapshot := ScoringSnapshot.new([
		ScoringContact.new(1, 100, 0.1),
		ScoringContact.new(1, 200, 0.2),
		ScoringContact.new(2, 300, 0.3),
	])
	var edges := snapshot.active_edges()
	assert_eq(edges.size(), 2)
	assert_true(edges.has(1))
	assert_true(edges.has(2))


func test_same_floater_on_the_same_edge_keeps_the_same_key() -> void:
	var a := ScoringContact.new(1, 100, 0.2)
	var b := ScoringContact.new(1, 100, 0.6)
	assert_eq(a.key(), b.key(), "Same edge and floater, only position moved")


func test_a_different_floater_on_the_same_edge_has_a_different_key() -> void:
	var a := ScoringContact.new(1, 100, 0.2)
	var b := ScoringContact.new(1, 200, 0.2)
	assert_ne(a.key(), b.key())


func test_the_same_floater_on_a_different_edge_has_a_different_key() -> void:
	var a := ScoringContact.new(1, 100, 0.2)
	var b := ScoringContact.new(2, 100, 0.2)
	assert_ne(a.key(), b.key())


func test_new_contacts_against_null_previous_treats_everything_as_new() -> void:
	var snapshot := ScoringSnapshot.new([ScoringContact.new(1, 100, 0.5)])
	assert_eq(snapshot.new_contacts(null).size(), 1)


func test_a_continuing_contact_is_not_reported_as_new() -> void:
	var previous := ScoringSnapshot.new([ScoringContact.new(1, 100, 0.2)])
	# Same floater, same edge, drifted position — a sustained contact.
	var current := ScoringSnapshot.new([ScoringContact.new(1, 100, 0.4)])
	assert_eq(current.new_contacts(previous).size(), 0, "Drifting alone is not a new contact")


func test_a_different_floater_arriving_on_the_same_edge_is_new() -> void:
	var previous := ScoringSnapshot.new([ScoringContact.new(1, 100, 0.2)])
	var current := ScoringSnapshot.new([ScoringContact.new(1, 200, 0.2)])
	var new_ones := current.new_contacts(previous)
	assert_eq(new_ones.size(), 1)
	assert_eq(new_ones[0].floater_id, 200)


func test_ended_keys_reports_contacts_missing_from_the_current_snapshot() -> void:
	var previous := ScoringSnapshot.new([
		ScoringContact.new(1, 100, 0.2),
		ScoringContact.new(2, 200, 0.5),
	])
	var current := ScoringSnapshot.new([ScoringContact.new(1, 100, 0.3)])
	var ended := current.ended_keys(previous)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0], ScoringContact.new(2, 200, 0.5).key())


func test_ended_keys_against_null_previous_is_empty() -> void:
	var snapshot := ScoringSnapshot.new()
	assert_eq(snapshot.ended_keys(null).size(), 0)


func test_an_empty_snapshot_can_be_built_with_no_arguments() -> void:
	var snapshot := ScoringSnapshot.new()
	assert_eq(snapshot.contacts.size(), 0)
	assert_eq(snapshot.active_edges().size(), 0)
