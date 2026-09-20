class_name DeckMotionDecoder
extends RefCounted
## Turns the Steam Deck's raw HID input-report stream into an accelerometer vector.
##
## [b]Why hidraw and not evdev.[/b] The first version of this read a
## [code]Steam Deck Motion Sensors[/code] evdev device that [code]hid-steam[/code]
## was believed to register. On real hardware
## ([code]6.11.11-valve27-1-neptune-611[/code]) that device does not exist:
## [code]hid_steam[/code] loads with only [code]lizard_mode[/code], there is no
## sensor sub-device under [code]/sys/class/input[/code], and the IMU is not on
## IIO either. What does exist, and what Steam itself reads for gyro input, is a
## plain [code]hidraw[/code] node for the controller's raw HID interface —
## [code]/dev/hidrawN[/code] whose [code]uevent[/code] names driver
## [code]hid-steam[/code] and a phys ending [code]input2[/code]. Multiple readers
## are allowed, so reading it alongside Steam is fine. [DeckMotionSource] finds
## that node; this decodes what comes out of it.
##
## [b]The report.[/b] Every report is [constant REPORT_SIZE] bytes, sent by the
## kernel as one indivisible block, so framing is just "every 64 bytes is a
## report" — there is no [code]SYN_REPORT[/code] to wait for the way there was on
## evdev. Byte 3 carries the report's own length and is checked before decoding,
## so a stream that starts mid-report is dropped rather than read as one shifted
## by however many bytes it takes to catch up:
## [codeblock lang=text]
## byte    0-1   report version (u16 LE) — observed 0x0001
## byte    2     report type    (u8)     — observed 0x09
## byte    3     report length  (u8)     — observed 0x40 (64); framing check
## byte    4-7   packet sequence number (u32 LE) — not read
## byte   8-47   buttons, pads, triggers — not read
## byte  48-53   accelerometer X, Y, Z (s16 LE each)
## byte  54-59   gyroscope pitch, roll, yaw (s16 LE each) — not read
## byte  60-63   unidentified — not read
## [/codeblock]
## Reasoned from a report captured at rest on real hardware
## ([code]0100 0940 1357 0200 0000 ... 1d08 800d 4806 72fd 0000 0000 2400 0a00[/code]):
## byte 3 reading exactly 0x40, the size of the report itself, is what pins the
## header's shape; the accelerometer offset falls out of which three [code]s16[/code]
## fields sit at a magnitude a resting accelerometer should be near — regardless
## of how the device was held — and the gyroscope offset is the three that sit
## near zero, which a gyroscope should be at rest and an accelerometer packing
## real buttons or pads should not.
##
## [b]Scale.[/b] [constant UNITS_PER_G] is reasoned the same way: the captured
## sample's accelerometer magnitude is about 4341 counts, and gravity is always
## about 1 g regardless of orientation, so units-per-g is about 4341. 4096 is the
## nearest value a real IMU would actually report (an 8g-range, 16-bit sensor —
## common, and consistent with a device meant to survive being dropped), within
## the sample's quantisation and bias. The old evdev path's 16384 units/g does
## not fit this sample at all — it would put a resting Deck at a quarter of a g.
##
## [b]Axis mapping — unverified.[/b] The evdev path's Y/Z swap was specific to
## how [code]hid-steam[/code] remapped the sensor for its virtual input device;
## it says nothing about the IMU chip's native axes in a raw HID report, which is
## what this reads. Absent a tilt sample to check against, the three axes are
## read as the chip reports them and negated uniformly — the same "reaction force
## is gravity's opposite" reasoning [DeckMotionDecoder] has always used for a
## resting accelerometer, applied with no assumed permutation. This is the one
## part of the mapping [code]scripts/run.sh motion[/code] has to settle on
## hardware: tilt right, and if the horizon rolls the wrong way or a raw axis
## moves on the wrong sign, the fix is here, not in [MotionTiltDriver].

## Bytes in one HID input report.
const REPORT_SIZE := 64

## Where the report's own length lives, used to keep a misaligned read from
## being decoded as a shifted report instead of dropped.
const LENGTH_OFFSET := 3

## Where the accelerometer's three axes start, each a little-endian [code]s16[/code].
const ACCEL_OFFSET := 48

## Where the gyroscope's three axes start. Decoded nowhere below — [MotionSource]
## has nowhere to carry it — but named so the layout is complete in one place.
const GYRO_OFFSET := 54

## Reported units per g. See the class doc for how this was read off a captured
## sample rather than assumed.
const UNITS_PER_G := 4096.0

const GRAVITY := 9.80665

## Latest complete reading, in m/s^2 and in the axes [MotionSource] speaks:
## x right, y up, z out of the screen, and at rest it points down.
var acceleration: Vector3 = Vector3.ZERO

## How many complete readings have been decoded, ever.
var reports: int = 0

var _tail := PackedByteArray()


## Feed bytes read from the device. They arrive in whatever sized lumps the
## pipe hands over, so a report split across two reads is normal and its head
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
	while offset + REPORT_SIZE <= bytes.size():
		if _decode_report(bytes, offset):
			decoded += 1
		offset += REPORT_SIZE
	if offset < bytes.size():
		_tail = bytes.slice(offset)
	return decoded


func has_reading() -> bool:
	return reports > 0


func reset() -> void:
	acceleration = Vector3.ZERO
	reports = 0
	_tail = PackedByteArray()


## Returns true when this block decoded as a report.
func _decode_report(bytes: PackedByteArray, offset: int) -> bool:
	if bytes[offset + LENGTH_OFFSET] != REPORT_SIZE:
		# Not a report this decoder understands — most likely a stream that
		# started mid-report. Dropped rather than read shifted by an unknown
		# number of bytes, which would decode as a reading that is simply wrong.
		return false

	var x := bytes.decode_s16(offset + ACCEL_OFFSET)
	var y := bytes.decode_s16(offset + ACCEL_OFFSET + 2)
	var z := bytes.decode_s16(offset + ACCEL_OFFSET + 4)

	# An accelerometer at rest reads the force holding the device up, the
	# opposite sign to the gravity the rest of core/motion works in — see the
	# class doc for why no axis is otherwise reordered pending a hardware check.
	var scale := GRAVITY / UNITS_PER_G
	acceleration = Vector3(-x, -y, -z) * scale
	reports += 1
	return true
