class_name MelodyWriter
extends RefCounted
## Writes a section's melody over its chords, the same way every time that
## section comes round.
##
## Each bar takes one of the song's rhythms; each note in it gets a pitch.
## Notes on the beat land on a chord tone, notes off it on a scale step, and
## every pitch is the candidate nearest the note before, so the line moves by
## small steps instead of leaping about. The last note of a section settles on
## the chord's root or third. The generator is seeded from the song title and
## section name: a section's melody is a fixed piece of the song, and only the
## order sections come in varies.


## [[step, MIDI note, length in steps], ...] for every bar of [param section],
## one array per bar.
static func write_section(song: Song, section: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%s" % [song.title, section])
	var bars := song.bars_of(section)
	var steps := song.beats_per_bar * 4
	var previous := (song.melody_range.x + song.melody_range.y) / 2
	var written := []
	for bar_index in bars.size():
		var rhythm: String = song.melody_rhythms[rng.randi() % song.melody_rhythms.size()]
		var notes := []
		for start in note_starts(rhythm):
			var chord := song.chord_in_bar(bars[bar_index], start)
			var on_beat := start % 4 == 0
			var candidates := (
				chord.tones_between(song.melody_range.x, song.melody_range.y)
				if on_beat
				else scale_between(song, song.melody_range.x, song.melody_range.y)
			)
			var note := nearest(candidates, previous + rng.randi_range(-2, 2))
			notes.append([start, note, note_length(rhythm, start)])
			previous = note
		written.append(notes)
	_settle_ending(song, bars, written)
	return written


## Steps where [param rhythm] starts a note.
static func note_starts(rhythm: String) -> Array[int]:
	var starts: Array[int] = []
	for i in rhythm.length():
		if rhythm[i] == "x":
			starts.append(i)
	return starts


## Steps a note starting at [param start] lasts: itself plus every hold after.
static func note_length(rhythm: String, start: int) -> int:
	var length := 1
	while start + length < rhythm.length() and rhythm[start + length] == "-":
		length += 1
	return length


## The song's scale notes between two MIDI notes, ascending.
static func scale_between(song: Song, low: int, high: int) -> Array[int]:
	var notes: Array[int] = []
	for note in range(low, high + 1):
		if posmod(note - song.key_root, 12) in song.scale:
			notes.append(note)
	return notes


## The candidate closest to [param target]; the lower one on a tie.
static func nearest(candidates: Array[int], target: int) -> int:
	var best := candidates[0]
	for note in candidates:
		if absi(note - target) < absi(best - target):
			best = note
	return best


static func _settle_ending(song: Song, bars: Array, written: Array) -> void:
	for bar_index in range(written.size() - 1, -1, -1):
		var notes: Array = written[bar_index]
		if notes.is_empty():
			continue
		var last: Array = notes[notes.size() - 1]
		var chord := song.chord_in_bar(bars[bar_index], last[0])
		var resting: Array[int] = []
		for note in chord.tones_between(song.melody_range.x, song.melody_range.y):
			var above_root := posmod(note - chord.root, 12)
			if above_root == 0 or above_root == 3 or above_root == 4:
				resting.append(note)
		if not resting.is_empty():
			last[1] = nearest(resting, last[1])
		return
