class_name DeckMotionSource
extends MotionSource
## Adapter: the Steam Deck's built-in accelerometer.
##
## The Deck has a six-axis IMU, and none of it reaches Godot. [code]Input[/code]'s
## sensor functions are fed on Android and iOS only, and Godot exposes no
## gamepad sensors at all (godot-proposals#2829), so on the Deck
## [DeviceMotionSource] reports nothing and [MotionInput] falls back to the
## keyboard. That is what this exists to fix.
##
## [b]evdev does not have it, on real hardware.[/b] The first version of this
## looked for a [code]Steam Deck Motion Sensors[/code] evdev device, the way
## [code]hid-steam[/code]'s own documentation describes it. On a real Deck
## running [code]6.11.11-valve27-1-neptune-611[/code] that device does not
## exist: [code]hid_steam[/code] loads with only its [code]lizard_mode[/code]
## parameter, nothing named that appears under [code]/sys/class/input[/code],
## and the IMU is not on IIO either — only the two ambient-light sensors are.
## Retrying the evdev path from the godot-proposals thread alone will not find
## it on this kernel.
##
## What is there, and readable without root, is a [code]hidraw[/code] node for
## the controller's own raw HID interface — the same one Steam reads for gyro.
## [code]hid-steam[/code] binds several [code]hidraw[/code] nodes to one
## physical device (mouse, keyboard, controller state); the one that streams
## motion is identified by its [code]uevent[/code] naming driver
## [constant DEVICE_DRIVER] and a phys ending [constant DEVICE_PHYS_SUFFIX].
## This finds that node, reads it, and hands the result to the same pipeline a
## phone's sensors would feed. [DeckMotionDecoder] has the report layout.
##
## [b]Why it reads the device through [code]cat[/code].[/b] [FileAccess] refuses
## anything that is not a regular file, so a character device such as
## [code]/dev/hidraw*[/code] cannot be opened from GDScript at all. The
## alternatives are a GDExtension — native code to build, ship and keep in step
## with the engine version, for one vector — or borrowing a process that can
## already do the one thing needed. [method OS.execute_with_pipe] gives a pipe
## whose [method FileAccess.get_length] is a [code]FIONREAD[/code] count, so the
## stream is drained without ever blocking the frame, and a missing device, a
## denied permission or a dead reader all come out the same way: no readings,
## and [MotionInput] moves on to the next source.

## What [code]hid-steam[/code] names itself as, in a hidraw node's
## [code]device/uevent[/code].
const DEVICE_DRIVER := "hid-steam"

## The HID interface that streams motion, identified by the tail of its
## [code]HID_PHYS[/code]. The same physical controller exposes other
## [code]hidraw[/code] nodes for its mouse and keyboard emulation; this is what
## tells them apart.
const DEVICE_PHYS_SUFFIX := "input2"

## Where Linux lists raw HID devices.
const HIDRAW_CLASS_DIR := "/sys/class/hidraw"

## Readers to try, in order. Plain [code]cat[/code] is the fallback because
## [method OS.execute_with_pipe] resolves a bare name through [code]PATH[/code].
const READERS: Array[String] = ["/usr/bin/cat", "/bin/cat", "cat"]

## Most bytes to take from the pipe in one frame. Well over a frame's worth at
## the Deck's report rate; the cap only bounds the work if the game stalls and
## the pipe backs up.
const MAX_CHUNK := 1 << 16

## How many times a reader that was working may be restarted after it dies.
## A bound, because a reader that cannot survive is a reader that would
## otherwise be started again on every single frame.
const MAX_RESTARTS := 3

## Seconds for the gravity estimate to settle. Same job as the estimate in
## [DeviceMotionSource]: the accelerometer is gravity plus whatever the player
## is doing, and the jog detector wants only the second half.
const GRAVITY_TIME_CONSTANT := 1.2

var _device_path: String
var _decoder := DeckMotionDecoder.new()
var _stdio: FileAccess
var _stderr: FileAccess
var _pid: int = -1
var _reader_index: int = 0
var _restarts: int = 0
var _gave_up: bool = false
var _gravity_estimate := Vector3.ZERO
var _settled: bool = false
var _reported_failure: bool = false


func _init(device_path: String = "") -> void:
	_device_path = device_path if device_path != "" else find_device()


## The Deck's sensor device, or an empty string where there is none. Cheap, and
## touches nothing but [code]/sys[/code], so [MotionInput] can ask before
## deciding whether this source is worth starting.
static func find_device() -> String:
	if OS.get_name() != "Linux":
		return ""
	var dir := DirAccess.open(HIDRAW_CLASS_DIR)
	if dir == null:
		return ""
	for entry in dir.get_directories() + dir.get_files():
		if not entry.begins_with("hidraw"):
			continue
		var fields := _read_uevent("%s/%s/device/uevent" % [HIDRAW_CLASS_DIR, entry])
		if fields.get("DRIVER", "") != DEVICE_DRIVER:
			continue
		if not String(fields.get("HID_PHYS", "")).ends_with(DEVICE_PHYS_SUFFIX):
			continue
		return "/dev/%s" % entry
	return ""


func poll(delta: float) -> MotionReading:
	_ensure_running()
	_drain()

	if not _decoder.has_reading():
		_reading.clear()
		return _reading

	var raw := _decoder.acceleration
	# The Deck has no separate gravity sensor, so gravity is the part of the
	# signal that does not change: everything else is the player. Without this
	# split the jog detector would fire on gravity alone.
	if not _settled:
		_gravity_estimate = raw
		_settled = true
	elif delta > 0.0:
		# A zero step is a reading taken out of band — MotionInput.calibrate()
		# takes one — and no time has passed for the estimate to move in.
		_gravity_estimate = MotionFilter.smooth3(
			_gravity_estimate, raw, GRAVITY_TIME_CONSTANT, delta
		)

	_reading.gravity = _gravity_estimate
	_reading.acceleration = raw - _gravity_estimate
	_reading.available = true
	return _reading


func is_available() -> bool:
	return _decoder.has_reading()


## Kill the reader and forget what it had said. [method poll] starts it again
## from nothing, so a source that is stopped and then used once more reports
## only what the device has done since.
func stop() -> void:
	_close()
	_decoder.reset()
	_gravity_estimate = Vector3.ZERO
	_settled = false


func describe() -> String:
	if _device_path == "":
		return "Steam Deck sensors (none found)"
	return "Steam Deck sensors (%s)" % _device_path


## A hidraw node's [code]device/uevent[/code], as [code]KEY=value[/code] pairs.
## [code]DRIVER[/code] and [code]HID_PHYS[/code] are what tell one Valve HID
## interface from another; the rest is read along with them and ignored.
static func _read_uevent(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var fields := {}
	# Read a bounded chunk rather than the file's length: a sysfs attribute
	# reports a page as its size and then returns far less than that.
	var text := file.get_buffer(4096).get_string_from_utf8()
	for line in text.split("\n"):
		var separator := line.find("=")
		if separator == -1:
			continue
		fields[line.substr(0, separator)] = line.substr(separator + 1).strip_edges()
	return fields


## Keep exactly one reader alive, and know when to stop trying.
##
## A reader that cannot be run is not reported as such: the fork succeeds and
## the failure happens in the child, so a bad path looks exactly like a reader
## that started and died. Both are handled the same way — try the next
## candidate, and give up once they are exhausted, rather than starting a
## process per frame forever.
func _ensure_running() -> void:
	if _gave_up or _device_path == "":
		return
	if _stdio != null and OS.is_process_running(_pid):
		return

	if _stdio != null:
		var was_working := _decoder.has_reading()
		_close()
		if was_working:
			_restarts += 1
			if _restarts > MAX_RESTARTS:
				_give_up("the reader for %s keeps dying" % _device_path)
				return
		else:
			_reader_index += 1

	if _reader_index >= READERS.size():
		_give_up("no reader could stream %s" % _device_path)
		return

	var pipes := OS.execute_with_pipe(READERS[_reader_index], [_device_path], false)
	if pipes.is_empty():
		_reader_index += 1
		return
	_stdio = pipes.get("stdio")
	_stderr = pipes.get("stderr")
	_pid = pipes.get("pid", -1)


func _drain() -> void:
	if _stdio == null:
		return
	_report_reader_errors()
	var waiting := _stdio.get_length()
	if waiting < DeckMotionDecoder.REPORT_SIZE:
		return
	_decoder.feed(_stdio.get_buffer(mini(waiting, MAX_CHUNK)))


func _close() -> void:
	# Drain before letting go. A pipe outlives the process that filled it, so
	# the last readings — and whatever the reader had to say about why it is
	# going, which is where a permission error arrives and nowhere else — are
	# still there to be had, and are lost by closing first and asking after.
	_drain()
	_stdio = null
	_stderr = null
	if _pid != -1:
		OS.kill(_pid)
		_pid = -1


## Whatever the reader complained about, once. The likely one is a permission
## error: the device is readable by the user holding the seat, which is the
## player in Game Mode but not, say, an ssh session.
func _report_reader_errors() -> void:
	if _stderr == null:
		return
	var waiting := _stderr.get_length()
	if waiting <= 0:
		return
	_report_failure(_stderr.get_buffer(waiting).get_string_from_utf8().strip_edges())


## Stop trying, and say why once. Bounded work is the whole point: a source
## that cannot read its device has to settle into reporting nothing, not into
## starting a process on every frame for as long as the game runs.
func _give_up(message: String) -> void:
	_gave_up = true
	_report_failure(message)


func _report_failure(message: String) -> void:
	if _reported_failure:
		return
	_reported_failure = true
	push_warning("Steam Deck sensors unavailable: %s" % message)
