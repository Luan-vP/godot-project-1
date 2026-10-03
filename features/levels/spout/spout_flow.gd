class_name SpoutFlow
extends RefCounted
## How hard the spout pours, in steps of the bar: 2 droplets a bar, then 3, 4
## and so on up to 10, then 12, 14 and 16. Pure — depth or distance in, a step
## out, and which droplets fall due between two moments of the music — so it
## can be tested without a pad or a clock.
##
## The rate is set two ways. RT (or its keyboard stand-ins) by depth: past a
## small deadzone the trigger's travel is split evenly into the steps, so a
## gentle press is 2 a bar and the bottom of the travel 16. A touch by
## distance: the further from the spout, the higher the step, in even bands
## between [code]inner[/code] and [code]reach[/code] that [SpoutFlowOverlay]
## draws as rings.
##
## Droplets fall on the grid. With [code]n[/code] a bar, one is due at each
## [code]k/n[/code] of the bar, so 4 a bar is quarter notes, 3 a triplet feel,
## 16 sixteenths — the stream plays in time with the band.

## Droplets per bar at each step, gentlest first.
const STEPS: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16]
## Trigger travel ignored before the first step.
const DEADZONE := 0.06
## Droplets due in one frame are capped, so a stalled frame or a jump in the
## music does not dump a burst.
const MAX_DUE := 2


## The step for trigger [param depth] (0..1), or -1 for closed.
static func step_for_depth(depth: float) -> int:
	if depth <= DEADZONE:
		return -1
	var past := clampf((depth - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
	return mini(floori(past * STEPS.size()), STEPS.size() - 1)


## The step for a touch [param distance] from the spout, with bands running
## evenly from [param inner] to [param reach]. Never closed: any touch pours,
## inside [param inner] at the gentlest step, past [param reach] at the
## fullest.
static func step_for_distance(distance: float, inner: float, reach: float) -> int:
	if reach <= inner:
		return STEPS.size() - 1
	var past := clampf((distance - inner) / (reach - inner), 0.0, 1.0)
	return mini(floori(past * STEPS.size()), STEPS.size() - 1)


## Droplets a bar at [param step]; 0 for closed (-1).
static func per_bar(step: int) -> int:
	return STEPS[step] if step >= 0 and step < STEPS.size() else 0


## The outer radius of [param step]'s band, between [param inner] and
## [param reach].
static func band_outer(step: int, inner: float, reach: float) -> float:
	return inner + (reach - inner) * float(step + 1) / STEPS.size()


## Droplets falling due as the music moves from [param from_bars] to
## [param to_bars] — positions in bars, counting from the start — at
## [param count] a bar: one for each [code]k/count[/code] of a bar crossed.
static func due(from_bars: float, to_bars: float, count: int) -> int:
	if count <= 0 or to_bars <= from_bars:
		return 0
	var crossed := floori(to_bars * count) - floori(from_bars * count)
	return clampi(crossed, 0, MAX_DUE)


## Trigger depth this frame: the right trigger on whichever pad is pressed
## furthest, or a keyboard stand-in — [kbd]Space[/kbd] (the Deck's Y outside
## Steam) fully pressed, [kbd]1[/kbd]–[kbd]5[/kbd] fifths of the way.
static func read_depth() -> float:
	var depth := 0.0
	for device in Input.get_connected_joypads():
		depth = maxf(depth, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT))
	if Input.is_physical_key_pressed(KEY_SPACE):
		depth = 1.0
	var steps: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
	for i in steps.size():
		if Input.is_physical_key_pressed(steps[i]):
			depth = maxf(depth, (i + 1) / 5.0)
	return depth


## Where the music is now, in bars from the start, fractional. Read from the
## same [MusicTimeSource] the band's [StepClock] plays from — not
## [method AudioManager.get_current_bar], which only moves while loop layers
## play, and the band plays live.
static func music_bars() -> float:
	var source := AudioManager.get_music_time_source()
	if not source.is_running():
		return 0.0
	var beats_per_bar := maxi(1, AudioManager.get_music_clock().beats_per_bar)
	return source.get_beats() / beats_per_bar
