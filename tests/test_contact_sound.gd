extends GutTest
## Covers [ContactSound]: new-versus-continuing contact identity, the voice
## cap policy, and pitch reaching a sustained voice through a fader rather
## than straight from the raw position. Driven entirely by hand through
## [method ContactSound.apply_snapshot] and [method ContactSound.advance] —
## no signal, no waiting on engine frames, no audio device.


func _contact_sound(cap: int = 4) -> ContactSound:
	var contact_sound := ContactSound.new()
	contact_sound.voice_cap = cap
	contact_sound.root_hz = 220.0
	contact_sound.span_semitones = 12.0
	add_child_autofree(contact_sound)
	return contact_sound


func _snapshot(contacts: Array[ScoringContact]) -> ScoringSnapshot:
	return ScoringSnapshot.new(contacts)


func test_a_new_contact_starts_a_held_voice() -> void:
	var contact_sound := _contact_sound()
	var contact := ScoringContact.new(1, 100, 0.0)
	contact_sound.apply_snapshot(_snapshot([contact]))
	var voice := contact_sound.voice_for_key(contact.key())
	assert_not_null(voice, "A new contact gets a voice")
	assert_true(voice.is_held(), "Voice is held while the contact is active")


func test_a_new_contact_starts_on_pitch_immediately() -> void:
	var contact_sound := _contact_sound()
	var contact := ScoringContact.new(1, 100, 1.0)
	contact_sound.apply_snapshot(_snapshot([contact]))
	var voice := contact_sound.voice_for_key(contact.key())
	assert_almost_eq(voice.frequency, 440.0, 0.01, "Starts at the mapped pitch, not fading in")


func test_the_same_key_across_snapshots_does_not_retrigger() -> void:
	var contact_sound := _contact_sound()
	var contact := ScoringContact.new(1, 100, 0.2)
	contact_sound.apply_snapshot(_snapshot([contact]))
	var voice := contact_sound.voice_for_key(contact.key())
	voice.advance(0.5)
	var envelope_before := voice.envelope
	contact_sound.apply_snapshot(_snapshot([ScoringContact.new(1, 100, 0.6)]))
	assert_eq(contact_sound.voice_for_key(contact.key()), voice, "Same voice, not a new one")
	assert_eq(voice.envelope, envelope_before, "No retrigger: envelope untouched")


func test_a_contact_missing_from_the_next_snapshot_releases_its_voice() -> void:
	var contact_sound := _contact_sound()
	var contact := ScoringContact.new(1, 100, 0.5)
	contact_sound.apply_snapshot(_snapshot([contact]))
	var voice := contact_sound.voice_for_key(contact.key())
	var empty: Array[ScoringContact] = []
	contact_sound.apply_snapshot(_snapshot(empty))
	assert_false(voice.is_held(), "Released, not held")
	assert_null(contact_sound.voice_for_key(contact.key()), "No longer tracked")


func test_a_different_floater_on_the_same_edge_is_a_different_key() -> void:
	var contact_sound := _contact_sound()
	var first := ScoringContact.new(1, 100, 0.5)
	contact_sound.apply_snapshot(_snapshot([first]))
	var first_voice := contact_sound.voice_for_key(first.key())
	var second := ScoringContact.new(1, 200, 0.9)
	contact_sound.apply_snapshot(_snapshot([first, second]))
	assert_eq(contact_sound.sounding_count(), 2, "Both floaters sound")
	assert_eq(contact_sound.voice_for_key(first.key()), first_voice, "First voice untouched")
	assert_not_null(contact_sound.voice_for_key(second.key()), "Second got its own voice")


func test_continuing_contacts_pitch_moves_through_the_fader_not_straight_to_it() -> void:
	var contact_sound := _contact_sound()
	var contact := ScoringContact.new(1, 100, 0.0)
	contact_sound.apply_snapshot(_snapshot([contact]))
	var voice := contact_sound.voice_for_key(contact.key())
	contact_sound.apply_snapshot(_snapshot([ScoringContact.new(1, 100, 1.0)]))
	# The target jumped a full octave; one small step of the fader should only
	# have started closing that gap, not arrived.
	contact_sound.advance(1.0 / 60.0)
	assert_gt(voice.target_frequency, 220.0, "Has started moving")
	assert_lt(voice.target_frequency, 440.0, "But not straight to the new pitch in one step")


func test_a_sustained_contacts_pitch_eventually_arrives() -> void:
	var contact_sound := _contact_sound()
	var contact := ScoringContact.new(1, 100, 0.0)
	contact_sound.apply_snapshot(_snapshot([contact]))
	var voice := contact_sound.voice_for_key(contact.key())
	contact_sound.apply_snapshot(_snapshot([ScoringContact.new(1, 100, 1.0)]))
	for i in 300:
		contact_sound.advance(1.0 / 60.0)
		voice.advance(1.0 / 60.0)
	assert_almost_eq(voice.frequency, 440.0, 0.5, "Settles on the new pitch")


func test_voices_are_capped() -> void:
	var contact_sound := _contact_sound(2)
	var contacts: Array[ScoringContact] = [
		ScoringContact.new(1, 100, 0.1),
		ScoringContact.new(1, 200, 0.2),
		ScoringContact.new(1, 300, 0.3),
	]
	contact_sound.apply_snapshot(_snapshot(contacts))
	assert_eq(contact_sound.sounding_count(), 2, "No more than the cap")
	assert_null(contact_sound.voice_for_key(contacts[2].key()), "Third contact stays silent")


func test_a_contact_past_the_cap_does_not_steal_from_one_already_sounding() -> void:
	var contact_sound := _contact_sound(1)
	var first := ScoringContact.new(1, 100, 0.1)
	var second := ScoringContact.new(1, 200, 0.2)
	contact_sound.apply_snapshot(_snapshot([first]))
	contact_sound.apply_snapshot(_snapshot([first, second]))
	assert_eq(contact_sound.sounding_count(), 1, "Still just the first")
	assert_not_null(contact_sound.voice_for_key(first.key()), "First contact keeps its voice")
	assert_null(contact_sound.voice_for_key(second.key()), "Second stays silent, not stolen")


func test_a_freed_slot_lets_a_new_contact_sound() -> void:
	var contact_sound := _contact_sound(1)
	var first := ScoringContact.new(1, 100, 0.1)
	contact_sound.apply_snapshot(_snapshot([first]))
	var empty: Array[ScoringContact] = []
	contact_sound.apply_snapshot(_snapshot(empty))
	var second := ScoringContact.new(1, 200, 0.2)
	contact_sound.apply_snapshot(_snapshot([second]))
	assert_not_null(contact_sound.voice_for_key(second.key()), "New contact takes the free slot")
