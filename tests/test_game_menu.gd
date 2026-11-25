extends GutTest
## Covers the corner menu every level shares ([GameMenu]): its key, scale and
## next-song buttons, the level's hint in it, and opening and closing it; the
## levels' HUD text, which only a build with the developer tools shows; and the
## shake that moves the band on to its next song ([SongShake]).

const Hosting := preload("res://tests/hosting.gd")
const BOIDS_SCENE := preload("res://features/levels/boids/boids_level.tscn")
const EYE_BAND_SCENE := preload("res://features/levels/secret_eyes/eye_band_demo.tscn")

const LEVEL_HINTS := {
	"res://features/levels/secret_eyes/eye_band_demo.gd":
	"Keep eyes off the edges to hear them play.",
	"res://features/levels/spout/spout_level.gd": "Shoot bubbles at the ducks to solo.",
	"res://features/levels/boids/boids_level.gd": "Play a rhythm to strengthen that group.",
}

var _shared: SharedLayers


func before_each() -> void:
	_shared = SharedLayers.new()
	add_child_autofree(_shared)


func after_each() -> void:
	DevTools.forced = null
	AudioManager.set_tempo(120.0, 4)


func _menu() -> GameMenu:
	return _shared.game_menu


func _button(button_name: String) -> Button:
	return _menu().find_child(button_name, true, false) as Button


func _hint_label() -> Label:
	return _menu().find_child("Hint", true, false) as Label


func test_the_host_keeps_the_menu_so_every_level_has_it() -> void:
	assert_not_null(_menu())
	assert_eq(_menu().band, _shared.band)
	for button_name in ["MenuButton", "KeyDown", "KeyUp", "NextScale", "NextSong"]:
		var button := _button(button_name)
		assert_not_null(button, button_name)
		assert_eq(button.focus_mode, Control.FOCUS_NONE, "Never steals the pad's focus")
	assert_false(_shared.stage.is_ancestor_of(_menu()), "Off the stage, so a slide leaves it put")


func test_it_starts_closed_and_the_menu_button_opens_and_closes_it() -> void:
	assert_false(_menu().is_open(), "Only the menu button shows")
	assert_true(_button("MenuButton").is_visible_in_tree())
	assert_false(_button("KeyUp").is_visible_in_tree())
	_button("MenuButton").pressed.emit()
	assert_true(_menu().is_open())
	assert_true(_button("KeyUp").is_visible_in_tree())
	assert_true(_button("NextSong").is_visible_in_tree())
	_button("MenuButton").pressed.emit()
	assert_false(_menu().is_open())


func test_a_tap_outside_the_panel_closes_it() -> void:
	_menu().open()
	await get_tree().process_frame
	var inside := InputEventScreenTouch.new()
	inside.pressed = true
	inside.position = _button("KeyUp").get_global_rect().get_center()
	_menu()._input(inside)
	assert_true(_menu().is_open(), "A tap on the panel keeps it open")
	var outside := InputEventScreenTouch.new()
	outside.pressed = true
	# Left of the panel, level with its middle: clear of it and of the button.
	var panel := _menu().find_child("Panel", true, false) as Control
	outside.position = panel.get_global_rect().get_center() - Vector2(panel.size.x, 0.0)
	_menu()._input(outside)
	assert_false(_menu().is_open(), "A tap on the level closes it")


func test_the_buttons_move_the_bands_key_and_scale() -> void:
	var band := _shared.band
	_button("KeyUp").pressed.emit()
	assert_eq(band.get_key_offset(), KeyShiftInput.FOURTH)
	_button("KeyDown").pressed.emit()
	_button("KeyDown").pressed.emit()
	assert_eq(band.get_key_offset(), -KeyShiftInput.FOURTH)
	var before := band.scale_name()
	_button("NextScale").pressed.emit()
	assert_ne(band.scale_name(), before)
	assert_false(band.follows_key_scale())


func test_next_song_asks_the_band_for_another() -> void:
	assert_false(_shared.band.has_next_song())
	_button("NextSong").pressed.emit()
	assert_true(_shared.band.has_next_song(), "On the next bar line")


func test_the_mix_and_swing_are_in_the_menu_folded() -> void:
	_menu().open()
	for panel_name in ["MixPanel", "SwingPanel"]:
		var panel := _menu().find_child(panel_name, true, false) as DropDownPanel
		assert_not_null(panel, panel_name)
		assert_true(panel.is_visible_in_tree(), "%s shows when the menu opens" % panel_name)
		assert_true(panel.is_collapsed(), "%s starts folded" % panel_name)
		for slider in panel.find_children("*", "HSlider", true, false):
			assert_eq((slider as Control).focus_mode, Control.FOCUS_NONE, "Never takes focus")


func test_every_level_has_its_hint() -> void:
	for path in LEVEL_HINTS:
		var level: Node = load(path).new()
		assert_eq(GameMenu.hint_for(level), LEVEL_HINTS[path], path)
		level.free()


func test_the_panel_shows_the_hint_of_the_level_playing() -> void:
	assert_false(_hint_label().visible, "No level, no hint")
	var level: Node = load("res://features/levels/spout/spout_level.gd").new()
	autofree(level)
	_menu().level = level
	_menu().open()
	assert_true(_hint_label().visible)
	assert_eq(_hint_label().text, "Shoot bubbles at the ducks to solo.")
	_menu().level = Node.new()
	autofree(_menu().level)
	assert_false(_hint_label().visible, "A level with no hint shows none")


func test_a_player_sees_no_hud_text_over_the_level() -> void:
	DevTools.forced = false
	var level: BoidsLevel = BOIDS_SCENE.instantiate()
	Hosting.host(self, level)
	var layers := level.find_children("*", "CanvasLayer", true, false)
	assert_gt(layers.size(), 0)
	for layer in layers:
		assert_false((layer as CanvasLayer).visible, "Hidden for a player")


func test_a_player_sees_no_readouts_over_the_eye_band() -> void:
	DevTools.forced = false
	var level: Node2D = EYE_BAND_SCENE.instantiate()
	Hosting.host(self, level)
	var layers := level.find_children("*", "CanvasLayer", true, false)
	assert_gt(layers.size(), 0)
	for layer in layers:
		assert_false((layer as CanvasLayer).visible, "%s hidden for a player" % layer.name)
	assert_null(level.get_node_or_null("MotionDebugOverlay"), "No tilt readout at all")


func test_the_developer_tools_keep_the_hud_text() -> void:
	DevTools.forced = true
	var level: BoidsLevel = BOIDS_SCENE.instantiate()
	Hosting.host(self, level)
	var layers := level.find_children("*", "CanvasLayer", true, false)
	assert_gt(layers.size(), 0)
	for layer in layers:
		assert_true((layer as CanvasLayer).visible, "Shown on the Deck and in the editor")


func test_two_hard_jogs_close_together_are_a_shake() -> void:
	var shake := SongShake.new()
	autofree(shake)
	assert_false(shake.jog(1.0), "One jog is a nudge")
	assert_true(shake.jog(1.0 + SongShake.WINDOW * 0.5), "Back and forth")
	assert_false(shake.jog(1.6), "Resting")
	assert_false(shake.jog(1.0 + SongShake.COOLDOWN + 0.5), "A fresh first jog")
	assert_true(shake.jog(1.0 + SongShake.COOLDOWN + 0.7), "And a second shake")


func test_jogs_far_apart_are_not_a_shake() -> void:
	var shake := SongShake.new()
	autofree(shake)
	assert_false(shake.jog(1.0))
	assert_false(shake.jog(1.0 + SongShake.WINDOW + 0.1))
	assert_true(shake.jog(1.0 + SongShake.WINDOW + 0.3), "The second counts from the one before it")


func test_a_shake_is_harder_than_the_tanks_nudge() -> void:
	assert_gt(SongShake.JOG_THRESHOLD, MotionInput.new().jog_threshold)
	assert_eq(_shared.song_shake.motion.jog_threshold, SongShake.JOG_THRESHOLD)


func test_the_keyboards_space_jog_never_changes_the_song() -> void:
	var shake := _shared.song_shake
	shake.motion.set_source(KeyboardMotionSource.new())
	watch_signals(shake)
	shake._on_jogged(Vector2.RIGHT)
	shake._clock += 0.1
	shake._on_jogged(Vector2.LEFT)
	assert_signal_not_emitted(shake, "shaken")
	assert_false(_shared.band.has_next_song())


func test_a_sensor_shake_asks_the_band_for_the_next_song() -> void:
	var shake := _shared.song_shake
	shake.motion.set_source(ScriptedMotionSource.new())
	shake._on_jogged(Vector2.RIGHT)
	shake._clock += 0.1
	shake._on_jogged(Vector2.LEFT)
	assert_true(_shared.band.has_next_song())
