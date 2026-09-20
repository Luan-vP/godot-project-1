extends GutTest
## Covers [DeckMotionDecoder]: the record framing, the axis mapping and the
## scaling that turn a Steam Deck's sensor stream into an accelerometer vector.
##
## This is the half of the Deck adapter that can be checked without a Deck, and
## it is the half most likely to be silently wrong: a sign or a swapped axis
## reads as "the tilt controls feel odd" rather than as a failure, and the
## device itself is unavailable to CI, to a desktop, and to everyone who does
## not own one.

const G := 9.80665
const UNIT := DeckMotionDecoder.UNITS_PER_G

var _decoder: DeckMotionDecoder


func before_each() -> void:
	_decoder = DeckMotionDecoder.new()


## One [code]input_event[/code] as the kernel writes it: a 64-bit timeval,
## then type, code and value.
func _event(type: int, code: int, value: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(DeckMotionDecoder.EVENT_SIZE)
	bytes.encode_u16(16, type)
	bytes.encode_u16(18, code)
	bytes.encode_s32(20, value)
	return bytes


## A complete accelerometer report: the three axes, then the SYN_REPORT that
## says they belong together.
func _report(x: int, y: int, z: int) -> PackedByteArray:
	var bytes := _event(DeckMotionDecoder.EV_ABS, DeckMotionDecoder.ABS_X, x)
	bytes.append_array(_event(DeckMotionDecoder.EV_ABS, DeckMotionDecoder.ABS_Y, y))
	bytes.append_array(_event(DeckMotionDecoder.EV_ABS, DeckMotionDecoder.ABS_Z, z))
	bytes.append_array(_event(DeckMotionDecoder.EV_SYN, DeckMotionDecoder.SYN_REPORT, 0))
	return bytes


func test_nothing_is_reported_before_a_report_is_complete() -> void:
	_decoder.feed(_event(DeckMotionDecoder.EV_ABS, DeckMotionDecoder.ABS_Y, int(UNIT)))
	assert_false(_decoder.has_reading(), "Axes without a SYN_REPORT are half a reading")


func test_a_device_held_upright_reads_as_gravity_pointing_down() -> void:
	# Held upright the sensor's up axis carries the whole of the force holding
	# the Deck up, and core/motion works in gravity, which points the other
	# way. Getting this backwards inverts every control built on it.
	assert_eq(_decoder.feed(_report(0, int(UNIT), 0)), 1, "One complete reading")
	assert_almost_eq(_decoder.acceleration.y, -G, 0.001, "Down is -Y")
	assert_almost_eq(_decoder.acceleration.x, 0.0, 0.001, "No lean sideways")
	assert_almost_eq(_decoder.acceleration.z, 0.0, 0.001, "No lean fore or aft")


func test_leaning_right_leans_gravity_right() -> void:
	# Tip the right-hand edge down and the sensor's right axis reads negative,
	# because it now points partly at the floor rather than at the horizon.
	_decoder.feed(_report(-int(UNIT), 0, 0))
	assert_almost_eq(_decoder.acceleration.x, G, 0.001, "Gravity should move to +X")


func test_the_third_axis_comes_back_out_of_the_screen() -> void:
	# The driver's third axis points into the screen where MotionSource's
	# points out of it, so a Deck lying face up — gravity into the screen —
	# has to arrive as -Z.
	_decoder.feed(_report(0, 0, -int(UNIT)))
	assert_almost_eq(_decoder.acceleration.z, -G, 0.001, "Face up is -Z")


func test_readings_are_scaled_to_metres_per_second_squared() -> void:
	_decoder.feed(_report(0, int(UNIT) / 2, 0))
	assert_almost_eq(_decoder.acceleration.y, -G * 0.5, 0.001, "Half a g is half of 9.8")


func test_the_gyroscope_is_ignored() -> void:
	# The sensor reports six axes on the same stream. Reading a gyro axis as an
	# accelerometer axis would be an enormous, noisy tilt.
	_decoder.feed(_report(0, int(UNIT), 0))
	var gyro := _event(DeckMotionDecoder.EV_ABS, 0x03, 30000)
	gyro.append_array(_event(DeckMotionDecoder.EV_ABS, 0x04, -30000))
	gyro.append_array(_event(DeckMotionDecoder.EV_ABS, 0x05, 30000))
	gyro.append_array(_event(DeckMotionDecoder.EV_SYN, DeckMotionDecoder.SYN_REPORT, 0))
	_decoder.feed(gyro)
	assert_almost_eq(_decoder.acceleration.y, -G, 0.001, "The reading should be untouched")


func test_a_record_split_across_two_reads_still_decodes() -> void:
	# The stream arrives in whatever lumps the pipe hands over, so a record
	# cut in half is normal traffic rather than an error.
	var report := _report(0, int(UNIT), 0)
	var head := report.slice(0, 40)
	var tail := report.slice(40)
	assert_eq(_decoder.feed(head), 0, "Half a record is not a reading yet")
	assert_eq(_decoder.feed(tail), 1, "The rest of it completes one")
	assert_almost_eq(_decoder.acceleration.y, -G, 0.001, "And it decodes correctly")


func test_several_reports_in_one_read_leave_the_latest() -> void:
	# The device streams far faster than the game draws, so a frame's worth of
	# bytes holds many reports and only the last of them is current.
	var chunk := _report(0, int(UNIT), 0)
	chunk.append_array(_report(-int(UNIT), 0, 0))
	assert_eq(_decoder.feed(chunk), 2, "Both reports should decode")
	assert_almost_eq(_decoder.acceleration.x, G, 0.001, "The newest reading wins")
	assert_eq(_decoder.reports, 2, "Both should be counted")


func test_unknown_event_types_are_passed_over() -> void:
	# Keys, switches and anything else a future driver adds share the stream.
	_decoder.feed(_event(0x01, 0x130, 1))
	assert_false(_decoder.has_reading(), "A button is not a reading")
	_decoder.feed(_report(0, int(UNIT), 0))
	assert_almost_eq(_decoder.acceleration.y, -G, 0.001, "And the stream stays in step")


func test_reset_forgets_everything_including_a_partial_record() -> void:
	_decoder.feed(_report(0, int(UNIT), 0))
	_decoder.feed(_report(0, int(UNIT), 0).slice(0, 10))
	_decoder.reset()
	assert_false(_decoder.has_reading(), "Nothing should be held")
	assert_eq(_decoder.acceleration, Vector3.ZERO, "Including the last reading")
	_decoder.feed(_report(-int(UNIT), 0, 0))
	assert_almost_eq(
		_decoder.acceleration.x, G, 0.001, "A dropped partial must not offset the next"
	)
