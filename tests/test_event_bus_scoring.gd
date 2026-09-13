extends GutTest
## Covers the [EventBus] side of the scoring contract: the scorer (#26) and
## the music system (#33, #34) only ever meet through
## [signal EventBus.scoring_updated], so this checks that the signal exists,
## carries a [ScoringSnapshot], and reaches a listener with no scorer or
## music system involved at all.


func test_scoring_updated_reaches_a_listener_with_the_snapshot() -> void:
	watch_signals(EventBus)
	var snapshot := ScoringSnapshot.new([ScoringContact.new(1, 100, 0.5)])
	EventBus.scoring_updated.emit(snapshot)
	assert_signal_emitted_with_parameters(EventBus, "scoring_updated", [snapshot])
