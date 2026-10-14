class_name LevelMeter
extends Node
## Watches the whole mix going into the Master bus's limiter and writes down,
## in the log, every time it goes over full scale.
##
## The committed bus layout puts an [AudioEffectCapture] first on Master, then
## an [AudioEffectHardLimiter]. Every frame [AudioManager] hands this the peak
## of all the samples the capture saw since the frame before: the exact
## pre-limiter mix, not a once-a-frame sample of it. A peak at or past 0 dBFS
## is something that would have clipped; the limiter caught it, and it may
## still be audible as pumping, so it is worth knowing about. [ClipWatch]
## groups those into overs, and each is printed once:
## [codeblock lang=text]
## [level] OVER +1.4 dBFS for 0.12 s at bar 37 · level=BoidsLevel · song=Glass Tide
## [/codeblock]
## Context comes from notes anyone can set with [method set_note]: the demo
## menu notes the demo, the carousel the level, the band the song. A change of
## "demo" or "level" also prints that stretch's loudest peak, overs or not, so
## a log says how much headroom each level had:
## [codeblock lang=text]
## [level] peak -1.5 dBFS, 0 overs · level=BoidsLevel · song=Glass Tide
## [/codeblock]
## On a Deck, [code]scripts/deck.sh logs NAME[/code] shows these lines.

## Emitted when an over has ended.
signal over_ended(episode: ClipWatch.Episode)

## Notes whose change ends a segment, printing its peak.
const SEGMENT_NOTES: Array[String] = ["demo", "level"]
## Order notes are printed in; any others follow, alphabetically.
const NOTE_ORDER: Array[String] = ["demo", "level", "song"]

var watch := ClipWatch.new()
## The loudest sample of the last frame, linear.
var latest_peak := 0.0

var _notes := {}


func _process(_delta: float) -> void:
	latest_peak = AudioManager.drain_master_peak()
	var bar := AudioManager.get_current_bar() if AudioManager.is_loops_playing() else -1
	var ended := watch.feed(latest_peak, _now(), bar)
	if ended != null:
		_report(ended)


func _exit_tree() -> void:
	_end_segment()
	print(
		(
			"[level] session peak %s, %d overs"
			% [ClipWatch.format_db(watch.session_peak), watch.session_overs]
		)
	)


## Note [param value] under [param key] for every line logged from now on; an
## empty value clears it. Changing a [constant SEGMENT_NOTES] note first logs
## the segment that is ending.
func set_note(key: String, value: String) -> void:
	if _notes.get(key, "") == value:
		return
	if key in SEGMENT_NOTES:
		_end_segment()
	if value.is_empty():
		_notes.erase(key)
	else:
		_notes[key] = value


## The notes as they would be logged: "demo=… · level=… · song=…".
func describe() -> String:
	var keys: Array[String] = []
	for key in NOTE_ORDER:
		if _notes.has(key):
			keys.append(key)
	var others: Array = _notes.keys().filter(func(key): return key not in NOTE_ORDER)
	others.sort()
	keys.append_array(others)
	var parts: PackedStringArray = []
	for key in keys:
		parts.append("%s=%s" % [key, _notes[key]])
	return " · ".join(parts)


## The over line for [param episode], as printed.
func format_over(episode: ClipWatch.Episode) -> String:
	var line := (
		"[level] OVER %s for %.2f s" % [ClipWatch.format_db(episode.peak), episode.duration()]
	)
	if episode.bar >= 0:
		line += " at bar %d" % episode.bar
	return _with_notes(line)


func _report(episode: ClipWatch.Episode) -> void:
	print(format_over(episode))
	over_ended.emit(episode)


func _end_segment() -> void:
	var open := watch.flush()
	if open != null:
		_report(open)
	var segment := watch.end_segment()
	# Nothing heard: a menu, or a level too short to have made a sound.
	if segment["peak"] <= 0.0:
		return
	print(
		_with_notes(
			"[level] peak %s, %d overs" % [ClipWatch.format_db(segment["peak"]), segment["overs"]]
		)
	)


func _with_notes(line: String) -> String:
	var notes := describe()
	return line if notes.is_empty() else "%s · %s" % [line, notes]


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
