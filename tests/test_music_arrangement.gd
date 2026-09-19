extends GutTest
## Covers [MusicArrangement] wired up to the real [AudioManager] and
## [EventBus]: a scripted sequence of [ScoringSnapshot]s drives which loop
## layers are active, without a running game — the acceptance criterion #34
## calls out directly.
##
## Time comes from a [ScriptedMusicTime] like [code]test_music_time_sources.gd[/code]:
## it only moves in beats when [method ScriptedMusicTime.advance] is called
## (#74), which [MusicArrangement] converts to the wall seconds
## [ArrangementDirector]'s release hysteresis runs on — so advancing it lets
## that hysteresis be driven on demand instead of waiting on the wall clock.
## A bar boundary still needs a real frame to pass afterwards for
## [AudioManager]'s scheduler to notice, same as every other loop layer test.

const FRAME_TIMEOUT := 5.0
const TEMPO := 1200.0  # 0.05s per bar: fast enough for a boundary within the timeout.

var _scripted: ScriptedMusicTime
var _arrangement: MusicArrangement


func before_each() -> void:
	_scripted = ScriptedMusicTime.new()
	AudioManager.set_music_time_source(_scripted)
	AudioManager.set_tempo(TEMPO, 1)

	var beat := LoopLayer.new()
	beat.layer_name = "beat"
	beat.stream = _looping_tone()
	var hats := LoopLayer.new()
	hats.layer_name = "hats"
	hats.stream = _looping_tone()
	var layers: Array[LoopLayer] = [beat, hats]
	AudioManager.configure_loop_layers(layers)
	AudioManager.play_loops()
	await wait_frames(2)  # Let the scheduler establish bar 0 as its baseline, at t=0.

	_arrangement = add_child_autofree(MusicArrangement.new())
	_arrangement.configure(["beat", "hats"], [1.0, 3.0], 2.0)


func after_each() -> void:
	AudioManager.stop_loops()
	AudioManager.set_music_time_source(WallClockMusicTime.new())
	var no_layers: Array[LoopLayer] = []
	AudioManager.configure_loop_layers(no_layers)
	AudioManager.set_tempo(120.0, 4)


func _looping_tone() -> AudioStreamWAV:
	var stream := AudioTestTone.generate(440.0, 0.2, 0.3)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	return stream


func _snapshot(contacts_on_edge_one: int) -> ScoringSnapshot:
	var contacts: Array[ScoringContact] = []
	for i in contacts_on_edge_one:
		contacts.append(ScoringContact.new(1, i, 0.5))
	return ScoringSnapshot.new(contacts)


func test_no_scoring_yet_leaves_every_layer_inactive() -> void:
	assert_eq(_arrangement.active_layers(), [])
	assert_false(AudioManager.is_layer_active("beat"))


func test_scoring_brings_layers_in_once_a_bar_boundary_passes() -> void:
	EventBus.scoring_updated.emit(_snapshot(3))  # 3^2 = 9: both layers justified.
	assert_eq(_arrangement.active_layers(), ["beat", "hats"], "Director updates synchronously")
	assert_false(AudioManager.is_layer_active("beat"), "But AudioManager waits for a bar")

	_scripted.advance(1.01)  # Past the 1-beat (0.05s) bar.
	var both_active := func():
		return AudioManager.is_layer_active("beat") and AudioManager.is_layer_active("hats")
	var arrived: bool = await wait_until(both_active, FRAME_TIMEOUT)
	assert_true(arrived, "Both layers should land once a bar boundary passes")


func test_falling_scoring_does_not_drop_a_layer_before_release_seconds() -> void:
	EventBus.scoring_updated.emit(_snapshot(1))  # One layer justified.
	_scripted.advance(1.01)  # Past the 1-beat bar.
	await wait_until(func(): return AudioManager.is_layer_active("beat"), FRAME_TIMEOUT)

	EventBus.scoring_updated.emit(_snapshot(0))  # Score drops, but no time has passed.
	await wait_frames(3)
	assert_true(AudioManager.is_layer_active("beat"), "Must not cut out instantly")


func test_falling_scoring_drops_the_layer_once_release_seconds_have_passed() -> void:
	EventBus.scoring_updated.emit(_snapshot(1))
	_scripted.advance(1.01)  # Past the 1-beat bar.
	await wait_until(func(): return AudioManager.is_layer_active("beat"), FRAME_TIMEOUT)

	EventBus.scoring_updated.emit(_snapshot(0))  # Starts the release countdown.
	_scripted.advance(41.0)  # 2.05s at this tempo: past release_seconds, under this test's control.
	EventBus.scoring_updated.emit(_snapshot(0))  # A later tick confirms it stayed down.

	var beat_left := func(): return not AudioManager.is_layer_active("beat")
	var arrived: bool = await wait_until(beat_left, FRAME_TIMEOUT)
	assert_true(arrived, "Layer should leave once the score has stayed down long enough")
