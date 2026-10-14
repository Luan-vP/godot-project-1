class_name LevelMeterOverlay
extends CanvasLayer
## A small meter in the top-right corner for the whole mix, as the
## [LevelMeter] hears it before the Master limiter: the peak now, a peak hold,
## a lamp that lights on an over and fades, and the session's loudest peak and
## overs as text.
##
## F8 toggles it; [DemoMenu] starts it showing when launched with
## [code]--meter[/code], which is the way to have it on a Deck, where there is
## no F8: [code]scripts/deck.sh run NAME --meter[/code].

const TOGGLE_KEY := KEY_F8
## The scale, in dBFS. Above 0 is where the limiter is working.
const FLOOR_DB := -36.0
const TOP_DB := 6.0
## Peaks above this are drawn amber, and at or over 0 dBFS red.
const HOT_DB := -6.0
## Seconds the hold mark stays put before it starts to fall.
const HOLD_SECONDS := 1.5
## Seconds the over lamp takes to fade.
const LAMP_SECONDS := 2.0

const PANEL_SIZE := Vector2(240.0, 46.0)

var _panel: Control
var _peak_db := FLOOR_DB
var _hold_db := FLOOR_DB
var _hold_age := 0.0
var _lamp := 0.0


func _ready() -> void:
	layer = 128
	_panel = Control.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -PANEL_SIZE.x - 16.0
	_panel.offset_right = -16.0
	_panel.offset_top = 16.0
	_panel.offset_bottom = 16.0 + PANEL_SIZE.y
	_panel.draw.connect(_draw_panel)
	add_child(_panel)


func _process(delta: float) -> void:
	var meter := AudioManager.get_level_meter()
	if meter == null:
		return
	var peak := meter.latest_peak
	_peak_db = linear_to_db(peak) if peak > 0.0 else FLOOR_DB
	_hold_age += delta
	if _peak_db >= _hold_db:
		_hold_db = _peak_db
		_hold_age = 0.0
	elif _hold_age > HOLD_SECONDS:
		_hold_db = maxf(_hold_db - 12.0 * delta, _peak_db)
	if peak >= ClipWatch.OVER:
		_lamp = 1.0
	else:
		_lamp = maxf(_lamp - delta / LAMP_SECONDS, 0.0)
	if visible:
		_panel.queue_redraw()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
		visible = not visible


## Where [param db] sits along the meter, 0 at [constant FLOOR_DB] to 1 at
## [constant TOP_DB].
static func fraction_for_db(db: float) -> float:
	return clampf(inverse_lerp(FLOOR_DB, TOP_DB, db), 0.0, 1.0)


static func colour_for_db(db: float) -> Color:
	if db >= 0.0:
		return UiTokens.ALERT
	if db >= HOT_DB:
		return UiTokens.EMBER
	return UiTokens.RUNE


func _draw_panel() -> void:
	var size := _panel.size
	var plate := Rect2(Vector2.ZERO, size)
	_panel.draw_rect(plate, UiTokens.OVERLAY)
	_panel.draw_rect(plate, Color(UiTokens.SIGIL, 0.35), false, 1.0)

	var bar := Rect2(8.0, 8.0, size.x - 36.0, 10.0)
	_panel.draw_rect(bar, Color(UiTokens.LINE, 0.8))
	var lit := bar
	lit.size.x = bar.size.x * fraction_for_db(_peak_db)
	_panel.draw_rect(lit, colour_for_db(_peak_db))
	var zero_x := bar.position.x + bar.size.x * fraction_for_db(0.0)
	_panel.draw_line(
		Vector2(zero_x, bar.position.y - 2.0), Vector2(zero_x, bar.end.y + 2.0), UiTokens.TEXT, 1.0
	)
	var hold_x := bar.position.x + bar.size.x * fraction_for_db(_hold_db)
	_panel.draw_line(
		Vector2(hold_x, bar.position.y), Vector2(hold_x, bar.end.y), colour_for_db(_hold_db), 2.0
	)

	var lamp_centre := Vector2(size.x - 14.0, bar.get_center().y)
	_panel.draw_circle(lamp_centre, 6.0, Color(UiTokens.LINE, 0.9))
	if _lamp > 0.0:
		_panel.draw_circle(lamp_centre, 6.0, Color(UiTokens.ALERT, _lamp))

	var watch := AudioManager.get_level_meter().watch
	var text := (
		"mix %s · session %s · %d overs"
		% [
			"%+.1f" % _peak_db if _peak_db > FLOOR_DB else "—",
			ClipWatch.format_db(watch.session_peak),
			watch.session_overs,
		]
	)
	_panel.draw_string(
		UiTheme.hud_font(),
		Vector2(8.0, size.y - 9.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 16.0,
		12,
		UiTokens.HUD_TEXT
	)
