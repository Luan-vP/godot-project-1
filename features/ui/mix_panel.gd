class_name MixPanel
extends DropDownPanel
## Volume mix controls, in the corner menu ([GameMenu]) and the debug overlay
## ([LevelMeterOverlay]): a slider in dB for each mix bus, set through
## [method AudioManager.set_mix_db], and the spout's delay decay beside its
## delay ([method PinEcho.set_decay_db]).
##
## Made with the rows it should show ([member rows]), so the corner menu can
## show only what the level playing uses ([method rows_for]). With none given
## it shows every row, as the debug overlay does.

## The delay's decay, as a row name. Shown under the delay's own row.
const DECAY := "decay"

const LABELS := {
	AudioManager.BAND_BUS: "band",
	AudioManager.SOLO_BUS: "duck solo",
	AudioManager.DELAY_BUS: "delay",
	DECAY: "decay",
	AudioManager.RHYTHM_BUS: "rhythm",
}

## The rows shown: keys of [constant LABELS].
var rows: Array[String] = []


func _init(shown: Array[String] = []) -> void:
	title = "mix (dB)"
	rows = shown if not shown.is_empty() else all_rows()


## Every row there is.
static func all_rows() -> Array[String]:
	var all: Array[String] = []
	all.assign(LABELS.keys())
	return all


## The rows for [param level]: the band, which plays under every level, and
## what it lists in its [code]mix_rows() -> Array[String][/code] method, in
## [constant LABELS]' order. A level with no such method gets the band alone.
static func rows_for(level: Node) -> Array[String]:
	var wanted: Array = []
	if level != null and is_instance_valid(level) and level.has_method("mix_rows"):
		wanted = level.call("mix_rows")
	var shown: Array[String] = []
	for row: String in LABELS:
		if row == AudioManager.BAND_BUS or wanted.has(row):
			shown.append(row)
	return shown


func _build_rows() -> void:
	for row in rows:
		if row == DECAY:
			_add_decay()
		elif LABELS.has(row):
			_add_bus(row)


func _add_bus(bus_name: String) -> void:
	add_slider(
		LABELS[bus_name],
		Vector2(AudioManager.MIX_MIN_DB, AudioManager.MIX_MAX_DB),
		0.5,
		AudioManager.get_mix_db(bus_name),
		func(db: float) -> String: return "%+.1f" % db,
		func(db: float) -> void: AudioManager.set_mix_db(bus_name, db)
	)


## How many dB each of the delay's two repeats drops below the one before.
func _add_decay() -> void:
	add_slider(
		LABELS[DECAY],
		Vector2(0.0, PinEcho.DECAY_MAX_DB),
		0.5,
		PinEcho.get_decay_db(),
		func(db: float) -> String: return "%.1f" % -db if db > 0.0 else "0.0",
		PinEcho.set_decay_db
	)
