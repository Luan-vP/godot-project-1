class_name MixPanel
extends DropDownPanel
## Volume mix controls, in the corner menu ([GameMenu]) and the debug overlay
## ([LevelMeterOverlay]): a slider
## in dB for the band, the duck solo and the rhythm voices, set through
## [method AudioManager.set_mix_db].

const LABELS := {
	AudioManager.BAND_BUS: "band",
	AudioManager.SOLO_BUS: "duck solo",
	AudioManager.RHYTHM_BUS: "rhythm",
}


func _init() -> void:
	title = "mix (dB)"


func _build_rows() -> void:
	for bus_name: String in LABELS:
		add_slider(
			LABELS[bus_name],
			Vector2(AudioManager.MIX_MIN_DB, AudioManager.MIX_MAX_DB),
			0.5,
			AudioManager.get_mix_db(bus_name),
			func(db: float) -> String: return "%+.1f" % db,
			func(db: float) -> void: AudioManager.set_mix_db(bus_name, db)
		)
