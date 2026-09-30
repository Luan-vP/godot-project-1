class_name ContactPitch
extends RefCounted
## Pure mapping from a contact's position along its edge ([code]#30[/code]) to
## a pitch in hertz.
##
## Continuous, not quantised to a scale — see
## [code]features/scoring_sound/README.md[/code] for the decision and why.
## Linear in semitones, not in hertz: pitch is heard logarithmically, so a
## mapping that is linear in hertz crowds all the audible change into the
## bottom of the position range and leaves the top sounding static.


## Hertz a contact at [param position] (0..1, clamped) sounds at, [param
## span_semitones] above [param root_hz] at position 1.
static func hz_for_position(position: float, root_hz: float, span_semitones: float) -> float:
	var clamped := clampf(position, 0.0, 1.0)
	return root_hz * pow(2.0, (clamped * span_semitones) / 12.0)
