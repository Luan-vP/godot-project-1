class_name EyeBandSongs
extends RefCounted
## The songs the eye band can play, one picked at random each time it starts.
##
## Each is written for the band's seven parts — beat, bass, pads, melody, arp,
## ghost, shimmer — plus a fill that plays on the last bar of a section. They
## differ in key, tempo, groove and branching, so two sessions rarely sound
## alike: see [Song] for the notation and [SongWalker] for the branching.
##
## All of them stay slow (60-74 bpm) and low: melodies top out at A4.

const MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 10]
const DORIAN: Array[int] = [0, 2, 3, 5, 7, 9, 10]
const MAJOR: Array[int] = [0, 2, 4, 5, 7, 9, 11]


static func all() -> Array[Song]:
	return [glass_tide(), low_sun(), night_pool(), slow_orbit()]


static func pick_random(rng: RandomNumberGenerator) -> Song:
	var songs := all()
	return songs[rng.randi() % songs.size()]


## A minor, 70 bpm. The band's original loop, grown into four sections that
## wander between the home progression, a longer answer, a turn to the iv and
## a lift.
static func glass_tide() -> Song:
	var song := Song.new()
	song.title = "Glass Tide"
	song.tempo_bpm = 70.0
	song.key_root = 9
	song.scale = MINOR
	song.start_section = "A"
	song.sections = {
		"A": {"bars": "Am | F | C | G", "next": {"A2": 2, "B": 1}},
		"A2": {"bars": "Am | F | C | Em | F | G | Am | Am", "next": {"B": 2, "C": 1}},
		"B": {"bars": "Dm | Am | F | G", "next": {"A": 1, "C": 2}},
		"C": {"bars": "F | G | Em | Am", "next": {"A": 2, "A2": 1}},
	}
	song.drums = {
		"beat":
		{
			"kick": "9.......9..5....",
			"snare": "....9.......9...",
			"hat": "5.3.5.3.5.3.5.3.",
			"open_hat": "..............4.",
		},
		"ghost": {"snare": "..2......2....2.", "kick": "..........4....."},
		"shimmer": {"hat": ".3.3.3.3.3.3.3.3", "clap": "....5.......5..3"},
		"fill": {"snare": "........5.5.6.79", "open_hat": "......4........."},
	}
	song.bass_line = "R.RO.RR.OR.RO.RO"
	song.bass_hold_steps = 1
	song.arp_pattern = "0.1.2.3.2.1.0.1."
	song.melody_rhythms = ["x-----x-x-------", "x-------x---x---", "x---x---x-x-x---"]
	return song


## D dorian, 64 bpm, half-time. A two-chord vamp that opens out into a
## descending turn and a suspended pull home; long bass notes and a sparse arp.
static func low_sun() -> Song:
	var song := Song.new()
	song.title = "Low Sun"
	song.tempo_bpm = 64.0
	song.key_root = 2
	song.scale = DORIAN
	song.start_section = "A"
	song.sections = {
		"A": {"bars": "Dm9 | G | Dm9 | G", "next": {"A": 1, "B": 2}},
		"B": {"bars": "Bbmaj7 | Am7 | Gm7 | Am7", "next": {"A": 2, "C": 1}},
		"C": {"bars": "Fmaj7 | C | Gm7 | A7sus4", "next": {"A": 3, "B": 1}},
	}
	song.drums = {
		"beat":
		{
			"kick": "9.........5.....",
			"snare": "........9.......",
			"hat": "3...3...3...3...",
		},
		"ghost": {"snare": "......2......2..", "kick": ".......4........"},
		"shimmer": {"hat": ".2.2.2.2.2.2.2.2", "open_hat": "..4.......4....."},
		"fill": {"snare": "............6799", "kick": "........7......."},
	}
	song.bass_line = "R.......R...5..."
	song.bass_hold_steps = 6
	song.arp_pattern = "0...2...1...3..."
	song.melody_rhythms = ["x-------x-------", "x-----x-x-------", "x---------x-----"]
	song.timbres = {
		"pads": {"waveform": SynthWavetable.Waveform.SAW, "attack": 1.0, "level": 0.035},
		"melody": {"waveform": SynthWavetable.Waveform.SINE, "level": 0.08},
	}
	return song


## F major, 74 bpm. Soft four-on-the-floor under a running sixteenth arp; the
## long C section takes the scenic way round before it lands.
static func night_pool() -> Song:
	var song := Song.new()
	song.title = "Night Pool"
	song.tempo_bpm = 74.0
	song.key_root = 5
	song.scale = MAJOR
	song.start_section = "A"
	song.sections = {
		"A": {"bars": "Fmaj7 | G | Em7 | Am7", "next": {"B": 2, "A": 1}},
		"B": {"bars": "Dm7 | Bbmaj7 | F | C", "next": {"C": 2, "A": 1}},
		"C":
		{
			"bars": "Bbmaj7 | C | Am7 | Dm7 | Gm7 | C7sus4 | Fmaj7 | Fmaj7",
			"next": {"A": 2, "B": 1},
		},
	}
	song.drums = {
		"beat":
		{
			"kick": "7...7...7...7...",
			"snare": "....6.......6...",
			"hat": "..4...4...4...4.",
		},
		"ghost": {"snare": "...2......2.....", "kick": "..............3."},
		"shimmer": {"hat": ".3.3.3.3.3.3.3.3", "clap": "............5..."},
		"fill": {"snare": "..........5.6.79", "open_hat": "......5........."},
	}
	song.bass_line = "R.R.O.R.R.R.O.5."
	song.bass_hold_steps = 1
	song.arp_pattern = "0123210101232101"
	song.melody_rhythms = ["x---x---x-------", "x-x-x-----x-----", "x-------x-x-x---"]
	song.timbres = {
		"arp": {"level": 0.045, "release": 0.18},
		"pads": {"waveform": SynthWavetable.Waveform.SINE, "level": 0.07},
	}
	return song


## E minor, 60 bpm. The slowest and most spacious: a kick that drifts behind
## the beat, and a borrowed B7 that leans back towards home.
static func slow_orbit() -> Song:
	var song := Song.new()
	song.title = "Slow Orbit"
	song.tempo_bpm = 60.0
	song.key_root = 4
	song.scale = MINOR
	song.start_section = "A"
	song.sections = {
		"A": {"bars": "Em | Cmaj7 | G | D", "next": {"A": 1, "B": 2}},
		"B": {"bars": "Am7 | Em | Cmaj7 | D,Bm7", "next": {"C": 2, "A": 1}},
		"C": {"bars": "Cmaj7 | Bm7 | Am7 | B7", "next": {"A": 2, "B": 1}},
	}
	song.drums = {
		"beat":
		{
			"kick": "9.....5...9.....",
			"snare": "........8.......",
			"hat": "4.......4.......",
		},
		"ghost": {"hat": "..2...2...2...2.", "snare": "...........2...."},
		"shimmer": {"open_hat": "......3.......3.", "clap": "............4..."},
		"fill": {"snare": "........4.5.6.8.", "kick": "..............6."},
	}
	song.bass_line = "R.........5....."
	song.bass_hold_steps = 8
	song.arp_pattern = "0...1...2...1..."
	song.melody_rhythms = ["x-----------x---", "x-------x-------", "x---x-----------"]
	song.timbres = {
		"melody": {"attack": 0.2, "release": 0.9},
		"pads": {"attack": 1.2, "release": 2.0},
	}
	return song
