extends GutTest
## Covers the bubbles sticking and playing in time: one bubble to a pin,
## stuck pins playing together on the next sixteenth as their bubbles pop,
## the pins gone until the next bar, and the echoes and constellations.

const Hosting := preload("res://tests/hosting.gd")

const _TEST_SETTINGS_PATH := "user://test_bubble_emitter_settings.cfg"
const LEVEL := preload("res://features/levels/spout/bubbles/level_three.tscn")


func before_each() -> void:
	SaveManager.settings_path = _TEST_SETTINGS_PATH
	SaveManager.reload()


func after_each() -> void:
	if FileAccess.file_exists(_TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(_TEST_SETTINGS_PATH)
	SaveManager.settings_path = SaveManager.DEFAULT_SETTINGS_PATH
	SaveManager.reload()
	AudioManager.set_tempo(120.0, 4)
	AudioManager.set_music_time_source(WallClockMusicTime.new())


## The level, with the music held still so its own physics frames never move
## the clock under a test: the tests move it with [method tick_clock].
func _level() -> SpoutLevel:
	AudioManager.set_music_time_source(ScriptedMusicTime.new())
	var level: SpoutLevel = LEVEL.instantiate()
	Hosting.host(self, level)
	level.emitter.reads_input = false
	return level


func test_the_clock_runs_ahead_by_the_lookahead_like_the_bands() -> void:
	var scripted := ScriptedMusicTime.new()
	AudioManager.set_music_time_source(scripted)
	scripted.start()
	scripted.set_beats(2.0)
	var clock := AudioManager.get_music_clock()
	assert_almost_eq(BubbleEmitter.heard_bars(), 2.0 / clock.beats_per_bar, 0.0001)
	scripted.lookahead = clock.seconds_per_beat()
	assert_almost_eq(BubbleEmitter.heard_bars(), 3.0 / clock.beats_per_bar, 0.0001, "A beat ahead")


func test_only_one_bubble_sticks_to_a_pin() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var live := level.pins.live_pins()
	var first := emitter.fire()
	var second := emitter.fire()
	assert_true(emitter.stick(first, live[0], 300.0), "A free pin takes the bubble")
	assert_false(emitter.stick(second, live[0], 300.0), "A pin holds one bubble")
	assert_true(emitter.stick(second, live[1], 300.0), "It can stick elsewhere")
	assert_false(emitter.stick(first, live[2], 300.0), "A stuck bubble stays where it is")
	assert_eq(emitter.stuck_count(), 2)
	assert_eq(emitter.bubble_on(live[0]), first)
	assert_true(first.is_stuck())


func test_nothing_sticks_where_the_scale_has_no_pin() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var empty := -1
	for pin in level.pins.pin_count():
		if not level.pins.is_live(pin):
			empty = pin
			break
	assert_gte(empty, 0, "The fretboard has empty sites")
	assert_false(emitter.stick(emitter.fire(), empty, 300.0))


func test_a_stuck_pin_waits_for_the_next_sixteenth_then_pops() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var heard: Array[int] = []
	level.pins.pin_hit.connect(func(pin: int, _note: int, _strength: float): heard.append(pin))
	var sixteenth := 1.0 / BubbleEmitter.sixteenths_per_bar()
	var pin := level.pins.live_pins()[2]
	emitter.tick_clock(0.01)
	emitter.stick(emitter.fire(), pin, 400.0)
	assert_eq(heard.size(), 0, "Sticking does not sound")
	emitter.tick_clock(sixteenth - 0.001)
	assert_eq(heard.size(), 0, "Not before the sixteenth")
	emitter.tick_clock(sixteenth + 0.001)
	assert_eq(heard, [pin] as Array[int], "On the sixteenth")
	assert_true(level.pins.is_popped(pin), "Then it pops")
	assert_eq(emitter.stuck_count(), 0)
	assert_eq(emitter.in_play(), 0, "Its bubble goes with it")
	var where := level.pins.to_global(level.pins.pin_position(pin))
	assert_ne(level.pins.pin_at(where), pin, "Not found where it was")
	assert_false(level.pins.hit(pin, 1.0), "A popped pin is silent")


func test_pins_stuck_together_play_together_on_the_next_sixteenth() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var heard: Array[int] = []
	level.pins.pin_hit.connect(func(pin: int, _note: int, _strength: float): heard.append(pin))
	var sixteenth := 1.0 / BubbleEmitter.sixteenths_per_bar()
	var live := level.pins.live_pins()
	emitter.tick_clock(0.01)
	emitter.stick(emitter.fire(), live[4], 400.0)
	emitter.stick(emitter.fire(), live[1], 400.0)
	emitter.tick_clock(sixteenth + 0.001)
	assert_eq(heard, [live[4], live[1]] as Array[int], "Both on the one sixteenth")
	assert_true(level.pins.is_popped(live[4]) and level.pins.is_popped(live[1]), "Both pop")
	emitter.tick_clock(2.0 * sixteenth + 0.001)
	assert_eq(heard.size(), 2, "Nothing left for the next")


func test_popped_pins_come_back_at_the_next_bar() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var pin := level.pins.live_pins()[3]
	emitter.tick_clock(0.5)
	emitter.stick(emitter.fire(), pin, 400.0)
	emitter.tick_clock(0.5 + 1.0 / BubbleEmitter.sixteenths_per_bar())
	assert_true(level.pins.is_popped(pin))
	emitter.tick_clock(0.99)
	assert_true(level.pins.is_popped(pin), "Gone for the rest of the bar")
	assert_false(emitter.stick(emitter.fire(), pin, 400.0), "Nothing sticks to a popped pin")
	emitter.tick_clock(1.01)
	assert_false(level.pins.is_popped(pin), "Back on the bar line")
	assert_true(level.pins.is_live(pin))
	assert_eq(level.pins.popped_count(), 0)


func test_a_pin_played_on_the_downbeat_stays_gone_that_bar() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var pin := level.pins.live_pins()[0]
	emitter.tick_clock(0.97)
	emitter.stick(emitter.fire(), pin, 400.0)
	emitter.tick_clock(1.001)
	assert_true(level.pins.is_popped(pin), "Played on the downbeat, then popped")
	emitter.tick_clock(1.9)
	assert_true(level.pins.is_popped(pin))
	emitter.tick_clock(2.001)
	assert_false(level.pins.is_popped(pin))


func test_retiring_a_stuck_bubble_frees_its_pin() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var pin := level.pins.live_pins()[3]
	var bubble := emitter.fire()
	emitter.stick(bubble, pin, 400.0)
	emitter._retire(bubble)
	assert_eq(emitter.stuck_count(), 0)
	assert_eq(emitter.play_waiting(), [] as Array[int], "Nothing left waiting")
	assert_true(emitter.stick(emitter.fire(), pin, 400.0), "The pin is free again")


func test_a_played_pin_echoes_a_bar_later_and_again_softer() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var echoes: Array = []
	emitter.echo.echoed.connect(
		func(note: int, strength: float, repeat: int): echoes.append([note, strength, repeat])
	)
	var sixteenth := 1.0 / BubbleEmitter.sixteenths_per_bar()
	var pin := level.pins.live_pins()[2]
	var note := level.pins.note_for(pin)
	emitter.tick_clock(0.01)
	emitter.stick(emitter.fire(), pin, BubbleEmitter.FULL_STRENGTH_SPEED)
	emitter.tick_clock(sixteenth + 0.001)
	assert_eq(emitter.echo.pending_count(), 2, "Two repeats queued")
	emitter.tick_clock(1.0 + sixteenth - 0.002)
	assert_eq(echoes.size(), 0, "Not before the same sixteenth of the next bar")
	emitter.tick_clock(1.0 + sixteenth + 0.001)
	assert_eq(echoes.size(), 1, "A bar later: the pins' recharge")
	assert_eq(echoes[0][0], note, "The same note")
	assert_almost_eq(echoes[0][1], PinEcho.ECHO_LEVELS[0], 0.001, "Nearly as loud")
	emitter.tick_clock(2.0 + sixteenth + 0.001)
	assert_eq(echoes.size(), 2, "And again a bar after that")
	assert_almost_eq(echoes[1][1], PinEcho.ECHO_LEVELS[1], 0.001, "Softer again")
	assert_eq(echoes[1][2], 2)
	emitter.tick_clock(4.0)
	assert_eq(echoes.size(), 2, "Twice, then done")


func test_an_echo_keeps_its_note_through_a_key_change() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var notes: Array[int] = []
	emitter.echo.echoed.connect(func(note: int, _s: float, _r: int): notes.append(note))
	var sixteenth := 1.0 / BubbleEmitter.sixteenths_per_bar()
	var pin := level.pins.live_pins()[2]
	var note := level.pins.note_for(pin)
	emitter.tick_clock(0.01)
	emitter.stick(emitter.fire(), pin, 400.0)
	emitter.tick_clock(sixteenth + 0.001)
	level.shift_key(KeyShiftInput.FOURTH)
	level.peg_scale.snap()
	emitter.tick_clock(1.0 + sixteenth + 0.001)
	assert_eq(notes, [note] as Array[int])


func test_a_bars_notes_make_one_constellation_that_rises_then_prints() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var echo := emitter.echo
	var sixteenth := 1.0 / BubbleEmitter.sixteenths_per_bar()
	var live := level.pins.live_pins()
	emitter.tick_clock(0.01)
	emitter.stick(emitter.fire(), live[1], 400.0)
	emitter.tick_clock(sixteenth + 0.001)
	emitter.stick(emitter.fire(), live[6], 400.0)
	emitter.tick_clock(0.5 + 0.001)
	assert_eq(echo.phrase_count(), 1, "One bar, one phrase")
	var phrase: PinEcho.Phrase = echo.phrases()[0]
	assert_eq(phrase.stars.size(), 2, "A star for each note")
	echo._process(0.5)
	assert_eq(phrase.drift, Vector2.ZERO, "On the pins while the bar plays")
	emitter.tick_clock(1.2)
	echo._process(0.5)
	assert_lt(phrase.drift.y, 0.0, "Rising once the bar is over")
	emitter.tick_clock(2.9)
	assert_false(phrase.printed, "Not until both loops are over")
	emitter.tick_clock(3.01)
	assert_true(phrase.printed, "Into the water")
	echo._process(PinEcho.FADE_SECONDS + 0.1)
	assert_eq(echo.phrase_count(), 0, "And the ghost is gone")


func test_a_restart_of_the_music_drops_waiting_echoes() -> void:
	var level := _level()
	var emitter: BubbleEmitter = level.emitter
	var sixteenth := 1.0 / BubbleEmitter.sixteenths_per_bar()
	emitter.tick_clock(0.01)
	emitter.stick(emitter.fire(), level.pins.live_pins()[2], 400.0)
	emitter.tick_clock(sixteenth + 0.001)
	emitter.tick_clock(0.5)
	emitter.tick_clock(0.49)
	assert_eq(emitter.echo.pending_count(), 2, "A clock jittering back is not a restart")
	emitter.tick_clock(0.0)
	assert_eq(emitter.echo.pending_count(), 0)
	assert_true(emitter.echo.phrases()[0].printed)
