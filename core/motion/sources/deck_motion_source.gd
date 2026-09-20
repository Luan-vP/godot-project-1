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
## Linux publishes the Deck's IMU itself, without Steam: the kernel's
## [code]hid-steam[/code] driver registers a second input device named
## [constant DEVICE_NAME] alongside the controller, streaming continuously.
## This finds that device, reads it, and hands the result to the same pipeline
## a phone's sensors would feed.
##
## [b]Why it reads the device through [code]cat[/code].[/b] [FileAccess] refuses
## anything that is not a regular file, so [code]/dev/input/event*[/code] cannot
## be opened from GDScript at all. The alternatives are a GDExtension — native
## code to build, ship and keep in step with the engine version, for one vector
## — or borrowing a process that can already do the one thing needed.
## [method OS.execute_with_pipe] gives a pipe whose [method FileAccess.get_length]
## is a [code]FIONREAD[/code] count, so the stream is drained without ever
## blocking the frame, and a missing device, a denied permission or a dead
## reader all come out the same way: no readings, and [MotionInput] moves on to
## the next source.

## What [code]hid-steam[/code] calls the Deck's sensor device.
const DEVICE_NAME := "Steam Deck Motion Sensors"

## Where Linux lists input devices, each with the name it reports.
const INPUT_CLASS_DIR := "/sys/class/input"

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
	var dir := DirAccess.open(INPUT_CLASS_DIR)
	if dir == null:
		return ""
	for entry in dir.get_directories() + dir.get_files():
		if not entry.begins_with("event"):
			continue
		if _read_device_name("%s/%s/device/name" % [INPUT_CLASS_DIR, entry]) == DEVICE_NAME:
			return "/dev/input/%s" % entry
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


static func _read_device_name(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	# Read a bounded chunk rather than the file's length: a sysfs attribute
	# reports a page as its size and then returns far less than that.
	return file.get_buffer(256).get_string_from_utf8().strip_edges()


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
	if waiting < DeckMotionDecoder.EVENT_SIZE:
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
