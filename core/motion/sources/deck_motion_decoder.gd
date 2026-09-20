class_name DeckMotionDecoder
extends RefCounted
## Turns the Steam Deck's raw sensor stream into an accelerometer vector.
##
## The Deck's IMU is published by the kernel's [code]hid-steam[/code] driver as
## an ordinary Linux input device named "Steam Deck Motion Sensors": a stream
## of 24-byte [code]input_event[/code] records, the accelerometer on
## [code]ABS_X/Y/Z[/code] and the gyroscope on [code]ABS_RX/RY/RZ[/code], with
## one [code]SYN_REPORT[/code] closing each set of axes.
##
## Pure, and separate from [DeckMotionSource], for the same reason the rest of
## [code]core/motion[/code] is split that way: the bytes can be written by hand
## in a test, so the record framing, the axis mapping and the scaling are
## pinned in CI rather than discovered on a device.
##
## Only the accelerometer is read. Tilt is an orientation against gravity, which
## the accelerometer gives directly and without drift; the gyroscope would only
## make a fast tilt arrive sooner, and [MotionSource] has nowhere to carry it.

## Bytes per [code]input_event[/code]: two 64-bit timeval fields, then type,
## code and value. 64-bit only, which the Deck is.
const EVENT_SIZE := 24

const EV_SYN := 0x00
const EV_ABS := 0x03
const SYN_REPORT := 0x00

## Accelerometer axes. The driver publishes the sensor's own Y and Z swapped,
## so these are, in order: screen right, screen up, and into the screen.
const ABS_X := 0x00
const ABS_Y := 0x01
const ABS_Z := 0x02

## Reported units per g, from the driver's [code]STEAM_ACCEL_RES_PER_G[/code].
const UNITS_PER_G := 16384.0

const GRAVITY := 9.80665

## Latest complete reading, in m/s^2 and in the axes [MotionSource] speaks:
## x right, y up, z out of the screen, and at rest it points down.
var acceleration: Vector3 = Vector3.ZERO

## How many complete readings have been decoded, ever.
var reports: int = 0

var _pending := Vector3.ZERO
var _tail := PackedByteArray()


## Feed bytes read from the device. They arrive in whatever sized lumps the
## pipe hands over, so a record split across two reads is normal and its head
## is held until the rest of it turns up. Returns how many complete readings
## this call produced.
func feed(bytes: PackedByteArray) -> int:
	if not _tail.is_empty():
		var joined := _tail.duplicate()
		joined.append_array(bytes)
		bytes = joined
		_tail = PackedByteArray()

	var decoded := 0
	var offset := 0
	while offset + EVENT_SIZE <= bytes.size():
		if _decode_event(bytes, offset):
			decoded += 1
		offset += EVENT_SIZE
	if offset < bytes.size():
		_tail = bytes.slice(offset)
	return decoded


func has_reading() -> bool:
	return reports > 0


func reset() -> void:
	acceleration = Vector3.ZERO
	reports = 0
	_pending = Vector3.ZERO
	_tail = PackedByteArray()


## Returns true when this event completed a reading.
func _decode_event(bytes: PackedByteArray, offset: int) -> bool:
	var type := bytes.decode_u16(offset + 16)
	var code := bytes.decode_u16(offset + 18)
	var value := bytes.decode_s32(offset + 20)

	if type == EV_ABS:
		# Axes the sensor reports but this does not use — the gyroscope — land
		# here and are ignored.
		match code:
			ABS_X:
				_pending.x = value
			ABS_Y:
				_pending.y = value
			ABS_Z:
				_pending.z = value
		return false

	if type != EV_SYN or code != SYN_REPORT:
		return false

	# An accelerometer measures the force holding the device up, so at rest it
	# reads one g along whichever axis points at the sky — the opposite sign to
	# the gravity the rest of core/motion works in. The driver's third axis
	# points into the screen where MotionSource's points out of it, so that one
	# comes back the right way round by the same negation.
	var scale := GRAVITY / UNITS_PER_G
	acceleration = Vector3(-_pending.x, -_pending.y, _pending.z) * scale
	reports += 1
	return true
