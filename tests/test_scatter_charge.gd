extends GutTest
## Covers [ScatterCharge]: a full scatter takes one rhythm held unambiguously
## for [member ScatterCharge.fill_beats], fires once, and then cannot fire again
## until the cooldown is over.

var _charge: ScatterCharge


func before_each() -> void:
	_charge = ScatterCharge.new()
	_charge.fill_beats = 16.0
	_charge.drain_beats = 8.0
	_charge.cooldown_beats = 32.0


## Advance in quarter-beat steps; returns how many times it fired.
func _hold(beats: float, winner: int, unambiguous: bool = true) -> int:
	var fired := 0
	for i in int(beats * 4.0):
		if _charge.advance(0.25, winner, unambiguous):
			fired += 1
	return fired


func test_holding_one_rhythm_fills_the_charge_and_fires_once() -> void:
	assert_eq(_hold(15.0, 4), 0, "Not yet full")
	assert_almost_eq(_charge.charge, 15.0 / 16.0, 0.001, "Nearly full")
	assert_eq(_hold(1.0, 4), 1, "Fires when full")
	assert_eq(_charge.winner, 4, "The held rhythm survives")
	assert_true(_charge.is_cooling_down(), "Cooling down")


func test_ambiguous_playing_drains_the_charge() -> void:
	_hold(8.0, 3)
	_hold(2.0, 3, false)
	assert_almost_eq(_charge.charge, 0.25, 0.001, "Half full, less a quarter")
	_hold(8.0, 0, false)
	assert_eq(_charge.charge, 0.0, "Empty, never negative")


func test_switching_rhythm_starts_again_from_empty() -> void:
	_hold(12.0, 3)
	_hold(1.0, 4)
	assert_almost_eq(_charge.charge, 1.0 / 16.0, 0.001, "Only the beat since switching")
	assert_eq(_charge.winner, 4, "Building for the new rhythm")


func test_the_cooldown_keeps_scatters_from_chaining() -> void:
	assert_eq(_hold(16.0, 4), 1, "First scatter")
	assert_eq(_hold(31.0, 4), 0, "Locked while cooling down")
	assert_eq(_charge.charge, 0.0, "Charge stays empty")
	assert_eq(_hold(1.0 + 16.0, 4), 1, "Cooldown over, then a full charge again")


func test_no_time_passing_changes_nothing() -> void:
	_hold(4.0, 4)
	var before := _charge.charge
	assert_false(_charge.advance(0.0, 4, true), "No fire")
	assert_eq(_charge.charge, before, "No change")
