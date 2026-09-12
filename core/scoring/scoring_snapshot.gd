class_name ScoringSnapshot
extends RefCounted
## Everything the music system needs to know about the current scoring state,
## and nothing about how it was computed.
##
## This is the entire contract between the scorer ([code]#26[/code]) and the
## music system ([code]#33[/code], [code]#34[/code]): the scorer builds one of
## these and publishes it through [signal EventBus.scoring_updated], and the
## music system reacts to it. Neither side holds a reference to the other, and
## neither needs to — everything a consumer needs is here, plain data, so a
## test can build one by hand with no scene tree, no fluid simulation, and no
## edge detector running.
##
## [b]Publish cadence[/b]: every scoring tick, not throttled to "meaningful
## change only". A floater's position along its edge drifts every frame, and
## that drift is musically meaningful (pitch, filter sweep, whatever a
## consumer maps it to) — throttling publication to structural change would
## turn continuous drift into a staircase. The discreteness that actually
## matters, telling a new note from a sustained one, does not come from the
## publish rate at all: it comes from [method ScoringContact.key]. A consumer
## keeps the previous snapshot and diffs keys against this one (see
## [method new_contacts] and [method ended_keys]) instead of treating every
## publish as a retrigger. That is what keeps a continuous feed from becoming
## a continuous smear.
##
## Positions are normalised along the edge, not screen or world coordinates.
## Where a floater sits on a line is musically meaningful; where that line
## happens to sit on the player's screen is not.

var contacts: Array[ScoringContact]


func _init(p_contacts: Array[ScoringContact] = []) -> void:
	contacts = p_contacts


## Contacts currently on [param edge_id], in no particular order.
func contacts_for_edge(edge_id: int) -> Array[ScoringContact]:
	var result: Array[ScoringContact] = []
	for contact in contacts:
		if contact.edge_id == edge_id:
			result.append(contact)
	return result


## How many floaters currently share [param edge_id].
func count_for_edge(edge_id: int) -> int:
	return contacts_for_edge(edge_id).size()


## Every edge with at least one contact, each listed once.
func active_edges() -> Array[int]:
	var seen: Dictionary = {}
	for contact in contacts:
		seen[contact.edge_id] = true
	var result: Array[int] = []
	result.assign(seen.keys())
	return result


## [method ScoringContact.key] for every contact here, for cheap comparison
## against another snapshot.
func keys() -> Array[String]:
	var result: Array[String] = []
	for contact in contacts:
		result.append(contact.key())
	return result


## Contacts in this snapshot whose key was not present in [param previous] —
## the ones a consumer should trigger a new note for, rather than sustain one.
## [param previous] may be [code]null[/code], in which case every contact
## here counts as new.
func new_contacts(previous: ScoringSnapshot) -> Array[ScoringContact]:
	var previous_keys: Array[String] = previous.keys() if previous != null else []
	var result: Array[ScoringContact] = []
	for contact in contacts:
		if not previous_keys.has(contact.key()):
			result.append(contact)
	return result


## Keys that were in [param previous] but are absent here — the contacts that
## ended between the two snapshots, so a consumer knows which notes to
## release.
func ended_keys(previous: ScoringSnapshot) -> Array[String]:
	if previous == null:
		return []
	var current_keys: Array[String] = keys()
	var result: Array[String] = []
	for key in previous.keys():
		if not current_keys.has(key):
			result.append(key)
	return result
