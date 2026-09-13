class_name ScoringIntensity
extends RefCounted
## Turns a [ScoringSnapshot] into a single number the music system reacts to:
## how well the player is doing right now, in a shape where clustering is
## worth more than scatter.
##
## This is the audible half of #26's superlinear scoring rule, restated in
## terms [ArrangementDirector] can consume: several floaters sharing one edge
## must be more rewarding than the same floaters spread across several edges,
## because that is the play the game wants. Squaring each edge's count before
## summing is what makes that true — three floaters on one edge contribute 9,
## the same three split 2-and-1 contribute only 5 (4 + 1) — without this class
## needing to know anything about how #26 itself weighs a contact.
##
## Pure and stateless: the same snapshot always produces the same number, so
## [ArrangementDirector] can be driven with a bare float in tests without
## building a snapshot at all.


## How rewarding [param snapshot] is right now. 0 with no contacts; grows
## faster than linearly as floaters stack onto the same edge rather than
## scattering across several.
static func compute(snapshot: ScoringSnapshot) -> float:
	var total := 0.0
	for edge_id in snapshot.active_edges():
		var count := snapshot.count_for_edge(edge_id)
		total += float(count * count)
	return total
