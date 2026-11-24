class_name RhythmDial
extends Node2D
## The rhythm level's dial and drum pads ([BoidsLevel]), drawn over the water
## and under the flocks.
##
## The dial is the bar as a clock face, downbeat at the top. From the rim in:
## the last bar of each drum's taps (hi-hats as dots, snares as dashes, kicks
## as squares, a track each, as a drum part is written from the top line
## down), then a ring of pulses per rhythm in play, outermost the fewest
## pulses, each as bright as its rhythm is in favour. The hand is the
## playhead, an arc round the outside is the charge building (grey while it
## settles after a scatter), an arc inside the rings fills while the dial is
## held to shuffle, and the reading sits in the middle.
##
## After a shuffle the old rhythms' rings fade where they were as the new
## ones come in ([method fade_out]).
##
## The drum pads ([DrumPads]) are faint rings in the corners, breathing on
## every beat and lit by a hit ([method flash_pad]), each with its drum's mark.
##
## It reads everything from [member level] and keeps only what is its own:
## the fades.

## The radius the dial's marks were sized for; they scale with it.
const DESIGN_RADIUS := 96.0
## Each drum's track of taps, in design units in from the rim.
const TAP_TRACKS := {
	DrumPads.Pad.HAT: 6.0,
	DrumPads.Pad.SNARE: 13.0,
	DrumPads.Pad.KICK: 20.0,
}
## Where the outermost rhythm ring sits, in design units in from the rim, and
## the space between rings.
const RING_INSET := 31.0
const RING_GAP := 14.0
## Seconds the old rhythms' rings take to fade after a shuffle.
const FADE_SECONDS := 0.8
## Seconds a pad's flash takes to die away after a hit.
const FLASH_SECONDS := 0.33

var level: BoidsLevel

## pad -> 0..1, a ring's flash after a hit.
var _pad_flash := {}
## The rhythms a shuffle replaced, fading out.
var _faded: Array[Rhythm] = []
var _fade := 0.0

# The dial's geometry, worked out once per draw.
var _centre := Vector2.ZERO
var _outer := 0.0
var _unit := 1.0
var _clock: MusicClock


func _process(delta: float) -> void:
	_fade = maxf(_fade - delta / FADE_SECONDS, 0.0)
	for pad in _pad_flash:
		_pad_flash[pad] = maxf(_pad_flash[pad] - delta / FLASH_SECONDS, 0.0)


## Light [param pad]'s ring: it was just hit.
func flash_pad(pad: int) -> void:
	_pad_flash[pad] = 1.0


## How lit [param pad]'s ring is, 0 to 1.
func pad_flash(pad: int) -> float:
	return _pad_flash.get(pad, 0.0)


## Fade [param rhythms]' rings out where they were: a shuffle replaced them.
func fade_out(rhythms: Array[Rhythm]) -> void:
	_faded = rhythms
	_fade = 1.0


## How far the replaced rings still show, 1 just after a shuffle down to 0.
func fade() -> float:
	return _fade


func _draw() -> void:
	if level == null or level.table == null:
		return
	_draw_pads()
	var rect := get_viewport_rect()
	_centre = rect.get_center()
	_outer = BoidsLevel.dial_radius(rect.size)
	_unit = _outer / DESIGN_RADIUS
	_clock = AudioManager.get_music_clock()

	draw_circle(_centre, _outer + 4.0 * _unit, UiTokens.OVERLAY)
	draw_arc(_centre, _outer + 4.0 * _unit, 0.0, TAU, 128, Color(UiTokens.SIGIL, 0.35), _unit, true)
	if _fade > 0.0:
		_draw_rings(_faded, _fade, false)
	_draw_rings(level.table.rhythms, 1.0 - _fade, true)
	_draw_taps()
	_draw_hold()

	var playhead := fposmod(level.heard_beats(), BoidsLevel.BEATS_PER_BAR)
	var hand := Color(UiTokens.TEXT, 0.35)
	var tip := _point(playhead / BoidsLevel.BEATS_PER_BAR, _outer)
	draw_line(_centre, _centre + tip, hand, _unit, true)

	_draw_charge()

	var reading := level.reading
	var label := str(reading.winner) if reading != null and reading.tap_count > 0 else ""
	var font_size := roundi(20.0 * _unit)
	draw_string(
		UiTheme.hud_font(),
		_centre + Vector2(-_outer, font_size * 0.35),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		_outer * 2.0,
		font_size,
		UiTokens.HUD_TEXT
	)


## A ring of pulses for each of [param rhythms], outermost first, faded by
## [param fade], and as bright as its rhythm is in favour when
## [param weighted].
func _draw_rings(rhythms: Array[Rhythm], fade: float, weighted: bool) -> void:
	var ring := _outer - RING_INSET * _unit
	for rhythm in rhythms:
		var color := rhythm.color
		color.a = 0.6
		if weighted:
			var weight := level.sim.weight_for(rhythm.pulses)
			var span := BoidsLevel.WEIGHT_HIGH - BoidsLevel.WEIGHT_LOW
			color.a = clampf(0.25 + (weight - BoidsLevel.WEIGHT_LOW) / span * 0.75, 0.2, 1.0)
		color.a *= fade
		draw_arc(_centre, ring, 0.0, TAU, 96, Color(color, color.a * 0.3), _unit, true)
		for k in rhythm.pulses:
			var phase := BoidsLevel.heard_phase(float(k) / rhythm.pulses, _clock)
			draw_circle(_centre + _point(phase, ring), 3.5 * _unit, color)
		ring -= RING_GAP * _unit


## The last bar of each drum's taps, on its own track round the rim.
func _draw_taps() -> void:
	for pad in DrumPads.ALL:
		var track: float = _outer - TAP_TRACKS[pad] * _unit
		var color := DrumPads.color_of(pad)
		for phase in level.readers[pad].window(level.score_beats()):
			var along := _point(BoidsLevel.heard_phase(phase, _clock), 1.0)
			DrumPads.draw_mark(self, pad, _centre + along * track, along, 4.0 * _unit, color)


## The hold that shuffles the rhythms, filling clockwise just inside the
## innermost ring.
func _draw_hold() -> void:
	var held := level.hold.progress(BoidsLevel.now())
	if held <= 0.0:
		return
	var inner := _outer - (RING_INSET + RING_GAP * level.table.rhythms.size()) * _unit
	var top := -PI / 2.0
	draw_arc(
		_centre, inner, top, top + TAU * held, 64, Color(UiTokens.TEXT, 0.8), 2.0 * _unit, true
	)


## The charge round the outside, in its rhythm's colour; grey while it
## settles after a scatter.
func _draw_charge() -> void:
	var charge := level.charge
	var top := -PI / 2.0
	var radius := _outer + 3.0 * _unit
	if charge.is_cooling_down():
		var left := charge.cooldown / charge.cooldown_beats
		draw_arc(
			_centre, radius, top, top + TAU * left, 128, Color(UiTokens.SIGIL, 0.3), 3.0 * _unit
		)
	elif charge.charge > 0.0:
		var rhythm := level.table.get_rhythm(charge.winner)
		var color := rhythm.color if rhythm != null else ArtPalette.LIGHT
		draw_arc(_centre, radius, top, top + TAU * charge.charge, 128, color, 4.0 * _unit, true)


## The three drum pads: a faint ring in each corner, breathing on every beat
## and lit by a hit, with its drum's mark in the middle.
func _draw_pads() -> void:
	var size := get_viewport_rect().size
	var reach := DrumPads.radius(size)
	var insets := level.safe_insets()
	var breath := pow(1.0 - fposmod(level.heard_beats(), 1.0), 3.0)
	for pad in DrumPads.ALL:
		var at := DrumPads.centre(pad, size, insets)
		var flash := pad_flash(pad)
		var color := DrumPads.color_of(pad)
		var line := Color(color, 0.35 + 0.15 * breath + 0.5 * flash)
		var swell := reach * (1.0 + 0.03 * breath + 0.06 * flash)
		draw_circle(at, swell, Color(color, 0.05 + 0.15 * flash))
		draw_arc(at, swell, 0.0, TAU, 64, line, 2.0, true)
		DrumPads.draw_mark(self, pad, at, Vector2.RIGHT, reach * 0.22, line)


## The point [param radius] out from the centre at bar phase [param phase],
## the downbeat at the top.
static func _point(phase: float, radius: float) -> Vector2:
	return Vector2.from_angle(-PI / 2.0 + phase * TAU) * radius
