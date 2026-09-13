class_name ScoringContact
extends RefCounted
## One floater's contact with one edge, as reported in a [ScoringSnapshot].
##
## Both IDs are opaque as far as this class is concerned — it only needs them
## to be stable across frames. [member edge_id] is the edge detector's problem
## ([code]#23[/code]): edges may be regenerated, and if their identifiers
## shift underneath a sustained contact, a held note would retrigger for no
## visible reason. [member floater_id] can be as simple as the floater's own
## [method Object.get_instance_id], since the same [Floater] node stays alive
## across frames even while it drifts and wraps.

## Stable identifier of the edge this contact is on.
var edge_id: int

## Stable identifier of the floater in contact.
var floater_id: int

## Where the floater sits along the edge, normalised 0..1. Not a screen or
## world coordinate — see [ScoringSnapshot] for why.
var position: float


func _init(p_edge_id: int, p_floater_id: int, p_position: float) -> void:
	edge_id = p_edge_id
	floater_id = p_floater_id
	position = p_position


## Identity a consumer can key note state off. The same floater staying on
## the same edge produces the same key from one snapshot to the next; a
## floater leaving and a different one landing on that edge does not, even
## though [member edge_id] is unchanged.
func key() -> String:
	return "%d:%d" % [edge_id, floater_id]
