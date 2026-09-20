extends GutTest
## Covers [DeckMotionSource] end to end, with a file standing in for the
## device.
##
## The adapter reads its device by streaming it through a reader process, which
## means everything except the Deck itself — starting the reader, draining the
## pipe without blocking the frame, splitting gravity out of the signal, and
## giving up on a device that cannot be read — can be exercised anywhere. A
## file of recorded sensor bytes is the same stream, just finite.

const G := 9.80665
const UNIT := DeckMotionDecoder.UNITS_PER_G
const STEP := 1.0 / 60.0

## Long enough for a reader to start and a handful of bytes to cross a pipe,
## short enough that a broken adapter fails the run rather than hanging it.
const PATIENCE_FRAMES := 120

var _recording_path: String
var _source: DeckMotionSource


func after_each() -> void:
	if _source != null:
		_source.stop()
		_source = null
	if _recording_path != "" and FileAccess.file_exists(_recording_path):
		DirAccess.remove_absolute(_recording_path)
	_recording_path = ""


func _event(type: int, code: int, value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(DeckMotionDecoder.EVENT_SIZE)
	bytes.encode_u16(16, type)
	bytes.encode_u16(18, code)
	bytes.encode_s32(20, value)
	return bytes


## A file of sensor records, and the path a reader can open it by.
func _recording(x: int, y: int, z: int, repeats: int = 1) -> String:
	var bytes := PackedByteArray()
	for _i in repeats:
		bytes.append_array(_event(DeckMotionDecoder.EV_ABS, DeckMotionDecoder.ABS_X, x))
		bytes.append_array(_event(DeckMotionDecoder.EV_ABS, DeckMotionDecoder.ABS_Y, y))
		bytes.append_array(_event(DeckMotionDecoder.EV_ABS, DeckMotionDecoder.ABS_Z, z))
		bytes.append_array(_event(DeckMotionDecoder.EV_SYN, DeckMotionDecoder.SYN_REPORT, 0))
	_recording_path = "user://test_deck_motion_%d.bin" % Time.get_ticks_usec()
	var file := FileAccess.open(_recording_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return ProjectSettings.globalize_path(_recording_path)


## Poll until the source has something, the way [MotionInput] would.
func _poll_until_available(source: DeckMotionSource) -> MotionReading:
	var reading := source.poll(STEP)
	for _i in PATIENCE_FRAMES:
		if reading.available:
			return reading
		OS.delay_msec(5)
		reading = source.poll(STEP)
	return reading


func test_a_recorded_stream_arrives_as_a_reading() -> void:
	_source = DeckMotionSource.new(_recording(0, int(UNIT), 0, 40))
	var reading := _poll_until_available(_source)
	assert_true(reading.available, "The reader should have delivered the recording")
	assert_true(_source.is_available(), "And the source should say so")
	assert_almost_eq(reading.gravity.y, -G, 0.01, "Upright: gravity points down")


func test_a_held_pose_is_all_gravity_and_no_player_motion() -> void:
	# The Deck has no gravity sensor, so the adapter has to separate the two
	# itself. A pose that never changes must come out as gravity alone, or the
	# jog detector would fire on nothing but the device being held.
	_source = DeckMotionSource.new(_recording(0, int(UNIT), 0, 40))
	var reading := _poll_until_available(_source)
	assert_true(reading.available, "The reader should have delivered the recording")
	assert_almost_eq(reading.acceleration.length(), 0.0, 0.05, "A still device is not moving")


func test_a_device_that_cannot_be_read_gives_up() -> void:
	# A reader that cannot run still forks, so a bad device looks exactly like
	# a reader that started and died. Both have to end in a source that reports
	# nothing, and in bounded work: this used to be the shape of bug that
	# starts a process every frame for as long as the game runs.
	_source = DeckMotionSource.new("/proc/self/no-such-device")
	for _i in 20:
		_source.poll(STEP)
	assert_false(_source.is_available(), "Nothing to read, nothing to report")
	assert_false(_source.poll(STEP).available, "And the reading says so too")


func test_stopping_lets_go_of_the_reader() -> void:
	_source = DeckMotionSource.new(_recording(0, int(UNIT), 0, 40))
	_poll_until_available(_source)
	_source.stop()
	assert_false(_source.is_available(), "Stopping should let go of the reader and the reading")


func test_a_source_with_no_device_describes_itself_honestly() -> void:
	var source := DeckMotionSource.new("")
	if DeckMotionSource.find_device() != "":
		# Running on a Deck: there is a device, and it is the other case.
		assert_true(source.describe().begins_with("Steam Deck sensors"), "Named either way")
		return
	assert_eq(source.describe(), "Steam Deck sensors (none found)")
	assert_false(source.is_available(), "Nothing found means nothing reported")
