extends GutTest
## Covers the corner menu's mix ([MixPanel] in [GameMenu]): it shows only
## what the level playing uses, its sliders set the mix, and the spout's
## delay and decay rows set its echoes ([PinEcho]).

const EYE_BAND := preload("res://features/levels/secret_eyes/eye_band_demo.gd")
const SPOUT := preload("res://features/levels/spout/spout_level.gd")
const BOIDS := preload("res://features/levels/boids/boids_level.gd")

var _shared: SharedLayers


func before_each() -> void:
	_shared = SharedLayers.new()
	add_child_autofree(_shared)


func _menu() -> GameMenu:
	return _shared.game_menu


func test_the_menus_mix_slider_sets_the_mix() -> void:
	var before := AudioManager.get_mix_db(AudioManager.RHYTHM_BUS)
	_menu().level = autofree(BOIDS.new())
	var sliders := _mix_sliders()
	assert_eq(sliders.size(), 2, "The band and the rhythm")
	var rhythm := sliders[1] as HSlider
	rhythm.value = before - 3.0
	assert_almost_eq(AudioManager.get_mix_db(AudioManager.RHYTHM_BUS), before - 3.0, 0.01)
	AudioManager.set_mix_db(AudioManager.RHYTHM_BUS, before)


func _mix_panel() -> MixPanel:
	return _menu().find_child("MixPanel", true, false) as MixPanel


func _mix_sliders() -> Array[Node]:
	return _mix_panel().find_children("*", "HSlider", true, false)


func test_the_mix_shows_only_what_the_level_plays() -> void:
	var band := AudioManager.BAND_BUS
	assert_eq(_mix_panel().rows, [band] as Array[String], "No level: the band alone")
	var levels := [
		[EYE_BAND, [band]],
		[SPOUT, [band, AudioManager.SOLO_BUS, AudioManager.DELAY_BUS, MixPanel.DECAY]],
		[BOIDS, [band, AudioManager.RHYTHM_BUS]],
	]
	for pair: Array in levels:
		var script: Script = pair[0]
		_menu().level = autofree(script.new())
		var expected: Array[String] = []
		expected.assign(pair[1])
		assert_eq(_mix_panel().rows, expected, script.resource_path)
		assert_eq(_mix_sliders().size(), expected.size(), "A slider a row")
	assert_eq(_menu().find_children("MixPanel", "", true, false).size(), 1, "Only ever one mix")


func test_a_new_level_keeps_the_mix_open_or_folded_and_above_the_swing() -> void:
	_menu().level = autofree(SPOUT.new())
	_mix_panel().set_collapsed(false)
	_menu().level = autofree(BOIDS.new())
	assert_false(_mix_panel().is_collapsed(), "Still open")
	var swing := _menu().find_child("SwingPanel", true, false)
	assert_eq(_mix_panel().get_index() + 1, swing.get_index())


func test_the_spouts_delay_and_decay_rows_set_them() -> void:
	var delay_before := AudioManager.get_mix_db(AudioManager.DELAY_BUS)
	var decay_before := PinEcho.get_decay_db()
	_menu().level = autofree(SPOUT.new())
	var sliders := _mix_sliders()
	(sliders[2] as HSlider).value = -6.0
	assert_almost_eq(AudioManager.get_mix_db(AudioManager.DELAY_BUS), -6.0, 0.01, "The delay")
	(sliders[3] as HSlider).value = 9.0
	assert_almost_eq(PinEcho.get_decay_db(), 9.0, 0.01, "The decay")
	AudioManager.set_mix_db(AudioManager.DELAY_BUS, delay_before)
	PinEcho.set_decay_db(decay_before)
