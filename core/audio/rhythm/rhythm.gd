class_name Rhythm
extends Resource
## One polyrhythm a group can play: [member pulses] even pulses across a bar
## that every group shares, all starting on the same downbeat. A 3 and a 4
## together are 3-against-4.
##
## Data rather than code, so a new rhythm is a new entry in a [RhythmTable],
## never a new branch somewhere that special-cases 3 or 4.

## How many evenly spaced pulses land in one bar.
@export_range(1, 16) var pulses: int = 4

## Relative weight when a new group rolls its rhythm — see
## [method RhythmTable.roll].
@export_range(0.0, 10.0, 0.01) var spawn_weight: float = 1.0

## How a group playing this rhythm is drawn.
@export var color: Color = Color.WHITE


static func create(p_pulses: int, p_spawn_weight: float, p_color: Color) -> Rhythm:
	var rhythm := Rhythm.new()
	rhythm.pulses = p_pulses
	rhythm.spawn_weight = p_spawn_weight
	rhythm.color = p_color
	return rhythm
