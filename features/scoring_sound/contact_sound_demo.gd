extends Control
## Manual, audible proof of #33: contacts sound, shaped by where they sit
## along their edge, and a held contact does not retrigger.
##
## Keys 1-6 hold a simulated floater's contact with one shared edge. While
## held, its position along the edge drifts continuously (a sine wave, a
## different rate per key) rather than sitting still — a static contact is not
## the case that matters, since the real medium never stops moving. Listen for
## a glissando while a key is held, not a repeated ping. [ContactSound]'s
## voice cap defaults to 4, so holding a 5th and 6th key at once demonstrates
## the cap policy: they stay silent until an earlier one is released, rather
## than cutting one already sounding.
##
## Space fires a burst: every floater flickers on and off in a fast, uneven
## flurry for a few seconds — the stress case the issue calls "the most likely
## way this ends up sounding like a machine gun". It should sound busy but
## not chattery.

const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
const EDGE_ID := 0
const BURST_SECONDS := 4.0

## Radians per second each floater's position oscillates at along the edge —
## different per floater so several held at once do not glide in lockstep.
const DRIFT_RATE := [0.6, 0.9, 1.3, 0.5, 1.7, 1.1]

var _contact_sound: ContactSound
var _held := {}  # int (keycode) -> true
var _time := 0.0
var _status: Label
var _burst_rng := RandomNumberGenerator.new()
var _burst_timer := 0.0
var _bursting := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_burst_rng.randomize()

	_contact_sound = ContactSound.new()
	add_child(_contact_sound)

	var help := Label.new()
	help.position = Vector2(16, 16)
	help.text = (
		"Contact sound (#33)\n\n"
		+ "1-6    hold a simulated floater's contact; position drifts while held\n"
		+ "Space  fire a burst: every floater flickers on and off for a few seconds\n\n"
		+ "Voice cap is %d — a 5th and 6th held contact stay silent until one frees."
		% _contact_sound.voice_cap
	)
	add_child(help)

	_status = Label.new()
	_status.position = Vector2(16, 190)
	add_child(_status)


func _process(delta: float) -> void:
	_time += delta
	if _bursting:
		_advance_burst(delta)
	_publish_snapshot()
	_update_status()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	var index := KEYS.find(key.keycode)
	if index >= 0:
		if key.pressed:
			_held[key.keycode] = true
		else:
			_held.erase(key.keycode)
	elif key.keycode == KEY_SPACE and key.pressed:
		_bursting = true
		_burst_timer = 0.0


## Flips a random floater's held state at a random short interval — bursty and
## uneven on purpose, not a metronomic on/off, since that is closer to how
## several drifting floaters would actually cross an edge in a flurry.
func _advance_burst(delta: float) -> void:
	_burst_timer += delta
	if _burst_timer > BURST_SECONDS:
		_bursting = false
		return
	if _burst_rng.randf() < delta * 6.0:
		var keycode: int = KEYS[_burst_rng.randi_range(0, KEYS.size() - 1)]
		if _held.has(keycode):
			_held.erase(keycode)
		else:
			_held[keycode] = true


func _publish_snapshot() -> void:
	var contacts: Array[ScoringContact] = []
	for index in KEYS.size():
		var keycode: int = KEYS[index]
		if not _held.has(keycode):
			continue
		var position := 0.5 + 0.5 * sin(_time * DRIFT_RATE[index] + index)
		contacts.append(ScoringContact.new(EDGE_ID, keycode, position))
	EventBus.scoring_updated.emit(ScoringSnapshot.new(contacts))


func _update_status() -> void:
	var burst_note := "   (bursting)" if _bursting else ""
	_status.text = (
		"held: %d   sounding: %d / %d%s"
		% [_held.size(), _contact_sound.sounding_count(), _contact_sound.voice_cap, burst_note]
	)
