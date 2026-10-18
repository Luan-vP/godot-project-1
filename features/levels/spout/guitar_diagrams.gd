class_name GuitarDiagrams
extends RefCounted
## Every scale the spout's pins can play, drawn as a scale diagram over the
## whole neck of a six-string guitar in standard tuning — the source the
## fretboard layout ([FretboardScale]) reads which frets hold a pin.
##
## One diagram per scale in [constant PegScale.SCALES], all in E (root on the
## open low and high E strings), frets 0 to 24. One line a string, highest
## first as in tab: the string's name, a space, then one character a fret —
## [code]R[/code] the root, [code]o[/code] another scale tone,
## [code]-[/code] not in the scale. Another key is the same diagram slid
## along the neck: see [method in_scale].
##
## The level plays the top few strings ([member PinField.strings]); the rest
## are here so a layout with more strings needs nothing new.

## Open strings in standard tuning, as MIDI, highest first: e B G D A E.
const STANDARD_TUNING: Array[int] = [64, 59, 55, 50, 45, 40]
const STRING_NAMES: Array[String] = ["e", "B", "G", "D", "A", "E"]
## The key every diagram is drawn in: E.
const DIAGRAM_ROOT := 4
## The highest fret drawn.
const LAST_FRET := 24

const DIAGRAMS := {
	"major pentatonic":
	[
		#  0    5    10   15   20  24
		"e R-o-o--o-o--R-o-o--o-o--R",
		"B o-o--R-o-o--o-o--R-o-o--o",
		"G -o--o-o--R-o-o--o-o--R-o-",
		"D --R-o-o--o-o--R-o-o--o-o-",
		"A --o-o--R-o-o--o-o--R-o-o-",
		"E R-o-o--o-o--R-o-o--o-o--R",
	],
	"minor pentatonic":
	[
		#  0    5    10   15   20  24
		"e R--o-o-o--o-R--o-o-o--o-R",
		"B o--o-R--o-o-o--o-R--o-o-o",
		"G o-o-o--o-R--o-o-o--o-R--o",
		"D o-R--o-o-o--o-R--o-o-o--o",
		"A o-o--o-R--o-o-o--o-R--o-o",
		"E R--o-o-o--o-R--o-o-o--o-R",
	],
	"major":
	[
		#  0    5    10   15   20  24
		"e R-o-oo-o-o-oR-o-oo-o-o-oR",
		"B o-o-oR-o-oo-o-o-oR-o-oo-o",
		"G -oo-o-o-oR-o-oo-o-o-oR-o-",
		"D -oR-o-oo-o-o-oR-o-oo-o-o-",
		"A o-o-o-oR-o-oo-o-o-oR-o-oo",
		"E R-o-oo-o-o-oR-o-oo-o-o-oR",
	],
	"natural minor":
	[
		#  0    5    10   15   20  24
		"e R-oo-o-oo-o-R-oo-o-oo-o-R",
		"B oo-o-R-oo-o-oo-o-R-oo-o-o",
		"G o-o-oo-o-R-oo-o-oo-o-R-oo",
		"D o-R-oo-o-oo-o-R-oo-o-oo-o",
		"A o-oo-o-R-oo-o-oo-o-R-oo-o",
		"E R-oo-o-oo-o-R-oo-o-oo-o-R",
	],
	"dorian":
	[
		#  0    5    10   15   20  24
		"e R-oo-o-o-oo-R-oo-o-o-oo-R",
		"B o-oo-R-oo-o-o-oo-R-oo-o-o",
		"G o-o-o-oo-R-oo-o-o-oo-R-oo",
		"D o-R-oo-o-o-oo-R-oo-o-o-oo",
		"A o-o-oo-R-oo-o-o-oo-R-oo-o",
		"E R-oo-o-o-oo-R-oo-o-o-oo-R",
	],
	"blues":
	[
		#  0    5    10   15   20  24
		"e R--o-ooo--o-R--o-ooo--o-R",
		"B o--o-R--o-ooo--o-R--o-ooo",
		"G o-ooo--o-R--o-ooo--o-R--o",
		"D o-R--o-ooo--o-R--o-ooo--o",
		"A ooo--o-R--o-ooo--o-R--o-o",
		"E R--o-ooo--o-R--o-ooo--o-R",
	],
}


static func has(scale_name: String) -> bool:
	return DIAGRAMS.has(scale_name)


## The diagram's mark at [param fret] on string [param string_index] (0 the
## high e): "R", "o" or "-".
static func mark(scale_name: String, string_index: int, fret: int) -> String:
	var line: String = DIAGRAMS[scale_name][string_index]
	return line.substr(2 + fret, 1)


## Whether [param fret] on string [param string_index] (0 the high e) is in
## [param scale_name] over [param root_pitch_class] (0 = C): the E diagram
## slid along the neck to that key. Frets past [constant LAST_FRET] repeat
## the octave below.
static func in_scale(
	scale_name: String, string_index: int, fret: int, root_pitch_class: int
) -> bool:
	var shifted := posmod(fret - (root_pitch_class - DIAGRAM_ROOT), 12)
	return mark(scale_name, string_index, shifted) != "-"
