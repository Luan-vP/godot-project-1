class_name ScatterCharge
extends RefCounted
## Decides when a full scatter fires. It should be rare, so it takes two
## things:
##
## [b]Charge.[/b] The charge fills only while the player keeps playing one
## rhythm unambiguously (see [member TapReader.Reading.unambiguous]), and
## drains otherwise. Changing to a different winner starts it again from
## empty, so the player has to hold one rhythm for [member fill_beats] in a
## row. The scatter fires when the charge is full.
##
## [b]Cooldown.[/b] After a scatter the charge stays locked at empty for
## [member cooldown_beats], so scatters cannot chain.
##
## Everything is counted in beats, not seconds or taps, so it scales with
## tempo and works the same whether the player taps 3 or 6 times a bar.

## Beats of unbroken, unambiguous playing to fill the charge from empty.
var fill_beats: float = 16.0

## Beats for a full charge to drain away once the playing stops reading clearly.
var drain_beats: float = 8.0

## Beats after a scatter before the charge can start filling again.
var cooldown_beats: float = 32.0

## 0..1.
var charge: float = 0.0

## Beats of cooldown left; 0 once it is over.
var cooldown: float = 0.0

## The rhythm the charge is building for, 0 for none yet.
var winner: int = 0


## Move the charge on by [param beats] of music, given the current reading.
## Returns true on the update the scatter fires; [member winner] is then the
## rhythm that survives it.
func advance(beats: float, reading_winner: int, unambiguous: bool) -> bool:
	if beats <= 0.0:
		return false
	if cooldown > 0.0:
		cooldown = maxf(cooldown - beats, 0.0)
		charge = 0.0
		return false
	if not unambiguous or reading_winner == 0:
		charge = maxf(charge - beats / drain_beats, 0.0)
		return false
	if reading_winner != winner:
		winner = reading_winner
		charge = 0.0
	charge = minf(charge + beats / fill_beats, 1.0)
	if charge < 1.0:
		return false
	charge = 0.0
	cooldown = cooldown_beats
	return true


func is_cooling_down() -> bool:
	return cooldown > 0.0


## Forget everything, as if the level had just started.
func reset() -> void:
	charge = 0.0
	cooldown = 0.0
	winner = 0
