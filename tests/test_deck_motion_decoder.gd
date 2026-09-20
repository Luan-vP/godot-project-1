extends GutTest
## Covers [DeckMotionDecoder]: the report framing, the axis mapping and the
## scaling that turn a Steam Deck's hidraw stream into an accelerometer vector.
##
## This is the half of the Deck adapter that can be checked without a Deck, and
## it is the half most likely to be silently wrong: a sign, a swapped axis or a
## wrong offset reads as "the tilt controls feel odd" or "nothing happens"
## rather than as a failure, and the device itself is unavailable to CI, to a
## desktop, and to everyone who does not own one.

const G := 9.80665
const UNIT := DeckMotionDecoder.UNITS_PER_G

## A report captured at rest on real hardware (kernel
## 6.11.11-valve27-1-neptune-611, /dev/hidraw3): the header at bytes 0-9, the
## rest zero up to byte 48, then the changing tail. Reproduced here so the
## framing and the header check are pinned against actual device bytes rather
## than only ones this suite made up.
const CAPTURED_HEADER := [0x01, 0x00, 0x09, 0x40, 0x13, 0x57, 0x02, 0x00, 0x00, 0x00]
const CAPTURED_TAIL := [
	0x1d, 0x08, 0x80, 0x0d, 0x48, 0x06, 0x72, 0xfd, 0x00, 0x00, 0x00, 0x00, 0x24, 0x00, 0x0a, 0x00,
]

var _decoder: DeckMotionDecoder


func before_each() -> void:
	_decoder = DeckMotionDecoder.new()


## A complete 64-byte HID report, with the header a real device sends and the
## accelerometer and gyroscope filled in at their offsets. Everything else is
## zero, matching an idle controller.
func _report(accel: Vector3, gyro: Vector3 = Vector3.ZERO) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(DeckMotionDecoder.REPORT_SIZE)
	bytes.encode_u16(0, 0x0001)
	bytes.encode_u8(2, 0x09)
	bytes.encode_u8(DeckMotionDecoder.LENGTH_OFFSET, DeckMotionDecoder.REPORT_SIZE)
	bytes.encode_s16(DeckMotionDecoder.ACCEL_OFFSET, int(accel.x))
	bytes.encode_s16(DeckMotionDecoder.ACCEL_OFFSET + 2, int(accel.y))
	bytes.encode_s16(DeckMotionDecoder.ACCEL_OFFSET + 4, int(accel.z))
	bytes.encode_s16(DeckMotionDecoder.GYRO_OFFSET, int(gyro.x))
	bytes.encode_s16(DeckMotionDecoder.GYRO_OFFSET + 2, int(gyro.y))
	bytes.encode_s16(DeckMotionDecoder.GYRO_OFFSET + 4, int(gyro.z))
	return bytes


func test_nothing_is_reported_before_a_report_is_complete() -> void:
	var report := _report(Vector3(0.0, UNIT, 0.0))
	assert_eq(_decoder.feed(report.slice(0, 40)), 0, "Half a report is not a reading yet")
	assert_false(_decoder.has_reading(), "Nothing decoded yet")


func test_a_device_held_upright_reads_as_gravity_pointing_down() -> void:
	# Held upright the sensor's up axis carries the whole of the force holding
	# the Deck up, and core/motion works in gravity, which points the other
	# way. Getting this backwards inverts every control built on it.
	assert_eq(_decoder.feed(_report(Vector3(0.0, UNIT, 0.0))), 1, "One complete reading")
	assert_almost_eq(_decoder.acceleration.y, -G, 0.001, "Down is -Y")
	assert_almost_eq(_decoder.acceleration.x, 0.0, 0.001, "No lean sideways")
	assert_almost_eq(_decoder.acceleration.z, 0.0, 0.001, "No lean fore or aft")


func test_leaning_right_leans_gravity_right() -> void:
	_decoder.feed(_report(Vector3(-UNIT, 0.0, 0.0)))
	assert_almost_eq(_decoder.acceleration.x, G, 0.001, "Gravity should move to +X")


func test_readings_are_scaled_to_metres_per_second_squared() -> void:
	_decoder.feed(_report(Vector3(0.0, UNIT / 2.0, 0.0)))
	assert_almost_eq(_decoder.acceleration.y, -G * 0.5, 0.001, "Half a g is half of 9.8")


func test_the_gyroscope_is_ignored() -> void:
	# The report carries both sensors in the same 64 bytes. Reading a gyro
	# field as an accelerometer field would be an enormous, noisy tilt.
	_decoder.feed(_report(Vector3(0.0, UNIT, 0.0), Vector3(30000.0, -30000.0, 30000.0)))
	assert_almost_eq(_decoder.acceleration.y, -G, 0.001, "The reading should be untouched")


func test_a_report_split_across_two_reads_still_decodes() -> void:
	# The stream arrives in whatever lumps the pipe hands over, so a report cut
	# in half is normal traffic rather than an error.
	var report := _report(Vector3(0.0, UNIT, 0.0))
	var head := report.slice(0, 40)
	var tail := report.slice(40)
	assert_eq(_decoder.feed(head), 0, "Half a report is not a reading yet")
	assert_eq(_decoder.feed(tail), 1, "The rest of it completes one")
	assert_almost_eq(_decoder.acceleration.y, -G, 0.001, "And it decodes correctly")


func test_several_reports_in_one_read_leave_the_latest() -> void:
	# The device streams far faster than the game draws, so a frame's worth of
	# bytes holds many reports and only the last of them is current.
	var chunk := _report(Vector3(0.0, UNIT, 0.0))
	chunk.append_array(_report(Vector3(-UNIT, 0.0, 0.0)))
	assert_eq(_decoder.feed(chunk), 2, "Both reports should decode")
	assert_almost_eq(_decoder.acceleration.x, G, 0.001, "The newest reading wins")
	assert_eq(_decoder.reports, 2, "Both should be counted")


func test_a_report_with_the_wrong_length_byte_is_dropped() -> void:
	# A misaligned stream — one that starts mid-report — is not decoded as a
	# report shifted by however many bytes it takes to catch up: it is dropped,
	# and reads as no reading rather than a wrong one.
	var report := _report(Vector3(0.0, UNIT, 0.0))
	report.encode_u8(DeckMotionDecoder.LENGTH_OFFSET, 0)
	_decoder.feed(report)
	assert_false(_decoder.has_reading(), "A report that does not claim its own length is dropped")


func test_reset_forgets_everything_including_a_partial_report() -> void:
	_decoder.feed(_report(Vector3(0.0, UNIT, 0.0)))
	_decoder.feed(_report(Vector3(0.0, UNIT, 0.0)).slice(0, 10))
	_decoder.reset()
	assert_false(_decoder.has_reading(), "Nothing should be held")
	assert_eq(_decoder.acceleration, Vector3.ZERO, "Including the last reading")
	_decoder.feed(_report(Vector3(-UNIT, 0.0, 0.0)))
	assert_almost_eq(
		_decoder.acceleration.x, G, 0.001, "A dropped partial must not offset the next"
	)


func test_a_report_captured_on_real_hardware_decodes_as_one_reading() -> void:
	# Bytes actually seen on a Deck, not just ones this suite constructed —
	# pins the framing and the header check against real traffic, even though
	# the axis convention this reading implies still needs a hardware tilt
	# check (see the class doc).
	var bytes := PackedByteArray()
	bytes.resize(DeckMotionDecoder.REPORT_SIZE)
	for i in CAPTURED_HEADER.size():
		bytes[i] = CAPTURED_HEADER[i]
	var tail_offset := DeckMotionDecoder.REPORT_SIZE - CAPTURED_TAIL.size()
	for i in CAPTURED_TAIL.size():
		bytes[tail_offset + i] = CAPTURED_TAIL[i]
	assert_eq(_decoder.feed(bytes), 1, "A real report should decode as one reading")
	assert_gt(_decoder.acceleration.length(), 0.0, "At rest gravity should read as non-zero")
