class_name UiTheme
extends RefCounted
## The menus' one [Theme], built from [UiTokens], and the names of the styles
## in it.
##
## A menu calls [method apply] on its root Control and everything under it
## picks the look up: buttons, sliders, scroll bars and tooltips by type, and
## anything that needs a particular role by [member Control.theme_type_variation]
## set to one of the names below ([constant TITLE], [constant CARD] ...).
## [method label] makes a [Label] in one of those roles.
##
## No menu sets its own colours, fonts or sizes. To restyle, change
## [UiTokens]; to add a role, add a name here and give it a look in
## [method _build].
##
## The theme is built once and shared, so every menu that applies it gets the
## same instance.

## A page's name, in the inscription face with a faint glow.
const TITLE := &"Title"
## A small tracked line above a title: what kind of page this is.
const KICKER := &"Kicker"
## Instructions and secondary lines.
const HINT := &"Hint"
## A line that changes as things happen.
const STATUS := &"Status"
## Monospaced output, like a build log.
const LOG := &"Log"
## A card's name, its line of description, and its index in the corner.
const CARD_TITLE := &"CardTitle"
const CARD_BLURB := &"CardBlurb"
const CARD_INDEX := &"CardIndex"
## A [Button] that is a card in a list or grid.
const CARD := &"Card"
## A [Button] that should sit back: no plate, just text, lit on hover.
const GHOST := &"Ghost"
## A [ProgressBar] for a hold that will do something irreversible.
const HOLD_BAR := &"HoldBar"

static var _theme: Theme


## The shared theme, built on first use.
static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Give [param control] and everything under it the menu look.
static func apply(control: Control) -> void:
	control.theme = get_theme()


## A [Label] in role [param variation] that lets clicks through.
static func label(text: String, variation: StringName) -> Label:
	var made := Label.new()
	made.text = text
	made.theme_type_variation = variation
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A page's heading: a [constant KICKER] line, the [constant TITLE], a rule
## under it, and a [constant HINT] when [param hint] is not empty.
static func header(kicker: String, title: String, hint: String = "") -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.name = "Header"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 6)
	var kicker_label := label(kicker, KICKER)
	kicker_label.name = "Kicker"
	stack.add_child(kicker_label)
	var title_label := label(title, TITLE)
	title_label.name = "Title"
	stack.add_child(title_label)
	stack.add_child(rule())
	if not hint.is_empty():
		var hint_label := label(hint, HINT)
		hint_label.name = "Hint"
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(hint_label)
	return stack


## A divider: a sigil-coloured hairline that fades out to the right, with a
## small rune diamond at its start.
static func rule() -> Control:
	var line := Control.new()
	line.name = "Rule"
	line.custom_minimum_size = Vector2(0.0, 12.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(
		func() -> void:
			var y := line.size.y * 0.5
			var width := line.size.x
			var points := PackedVector2Array([Vector2(14.0, y), Vector2(width, y)])
			var colours := PackedColorArray(
				[Color(UiTokens.SIGIL, 0.7), Color(UiTokens.SIGIL, 0.0)]
			)
			line.draw_polyline_colors(points, colours, 1.0)
			var half := 4.0
			var diamond_points := PackedVector2Array(
				[
					Vector2(half, y - half),
					Vector2(half * 2.0, y),
					Vector2(half, y + half),
					Vector2(0.0, y),
				]
			)
			line.draw_colored_polygon(diamond_points, UiTokens.RUNE)
	)
	return line


## The inscription face, at the tokens' weight and with [param tracking]
## extra pixels between letters.
static func display_font(tracking: int = UiTokens.DISPLAY_TRACKING) -> Font:
	var font := FontVariation.new()
	font.base_font = load(UiTokens.DISPLAY_FONT_PATH)
	font.variation_opentype = {"wght": UiTokens.DISPLAY_WEIGHT}
	font.spacing_glyph = tracking
	return font


## The terminal face, with [param tracking] extra pixels between letters.
static func mono_font(tracking: int = 0) -> Font:
	var base: Font = load(UiTokens.MONO_FONT_PATH)
	if tracking == 0:
		return base
	var font := FontVariation.new()
	font.base_font = base
	font.spacing_glyph = tracking
	return font


## A flat plate: [param fill], a [param border] in [param edge], and the
## tokens' corner radius.
static func plate(fill: Color, edge: Color, border: int = UiTokens.BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(UiTokens.RADIUS)
	box.set_content_margin_all(UiTokens.PAD * 0.5)
	box.content_margin_left = UiTokens.PAD
	box.content_margin_right = UiTokens.PAD
	box.anti_aliasing = false
	return box


static func _build() -> Theme:
	var theme := Theme.new()
	var mono := mono_font()
	var display := display_font()
	theme.default_font = mono
	theme.default_font_size = UiTokens.SIZE_BODY

	_labels(theme, mono, display)
	_buttons(theme)
	_bars(theme)
	_sliders(theme)
	_scrolling(theme)
	_panels(theme)
	return theme


static func _labels(theme: Theme, mono: Font, display: Font) -> void:
	theme.set_color("font_color", "Label", UiTokens.TEXT)

	_label_role(theme, TITLE, display, UiTokens.SIZE_TITLE, UiTokens.TEXT)
	var glow := UiTokens.RUNE
	glow.a = 0.35
	theme.set_color("font_shadow_color", TITLE, glow)
	theme.set_constant("shadow_offset_x", TITLE, 0)
	theme.set_constant("shadow_offset_y", TITLE, 0)
	theme.set_constant("shadow_outline_size", TITLE, 10)

	_label_role(
		theme, KICKER, mono_font(UiTokens.LABEL_TRACKING), UiTokens.SIZE_TINY, UiTokens.SIGIL
	)
	_label_role(theme, HINT, mono, UiTokens.SIZE_SMALL, UiTokens.MUTED)
	_label_role(theme, STATUS, mono, UiTokens.SIZE_BODY, UiTokens.TEXT)
	_label_role(theme, LOG, mono, UiTokens.SIZE_TINY, UiTokens.MUTED)
	_label_role(theme, CARD_TITLE, display_font(1), UiTokens.SIZE_HEADING, UiTokens.TEXT)
	_label_role(theme, CARD_BLURB, mono, UiTokens.SIZE_SMALL, UiTokens.MUTED)
	_label_role(
		theme, CARD_INDEX, mono_font(UiTokens.LABEL_TRACKING), UiTokens.SIZE_TINY, UiTokens.FAINT
	)

	theme.set_stylebox("panel", "TooltipPanel", plate(UiTokens.VOID_DEEP, UiTokens.SIGIL))
	theme.set_font("font", "TooltipLabel", mono)
	theme.set_font_size("font_size", "TooltipLabel", UiTokens.SIZE_TINY)
	theme.set_color("font_color", "TooltipLabel", UiTokens.MUTED)


static func _label_role(
	theme: Theme, role: StringName, font: Font, size: int, color: Color
) -> void:
	theme.set_type_variation(role, "Label")
	theme.set_font("font", role, font)
	theme.set_font_size("font_size", role, size)
	theme.set_color("font_color", role, color)


static func _buttons(theme: Theme) -> void:
	_button_states(theme, "Button")
	theme.set_font_size("font_size", "Button", UiTokens.SIZE_BODY)
	theme.set_font("font", "Button", mono_font(UiTokens.LABEL_TRACKING))

	theme.set_type_variation(CARD, "Button")
	_button_states(theme, CARD)

	theme.set_type_variation(GHOST, "Button")
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		theme.set_stylebox(state, GHOST, none)
	theme.set_font_size("font_size", GHOST, UiTokens.SIZE_SMALL)
	var quiet := UiTokens.MUTED
	quiet.a = 0.75
	theme.set_color("font_color", GHOST, quiet)
	theme.set_color("font_focus_color", GHOST, quiet)
	theme.set_color("font_hover_color", GHOST, UiTokens.RUNE)
	theme.set_color("font_pressed_color", GHOST, UiTokens.TEXT)


## Rest, hover, pressed and focus plates for a button type. Focus is drawn
## over whichever of the others applies, so it is a border alone.
static func _button_states(theme: Theme, type: StringName) -> void:
	var hover_edge := UiTokens.SIGIL
	hover_edge.a = 0.7
	theme.set_stylebox("normal", type, plate(UiTokens.PANEL, UiTokens.LINE))
	theme.set_stylebox("hover", type, plate(UiTokens.PANEL_HOVER, hover_edge))
	theme.set_stylebox("pressed", type, plate(UiTokens.PANEL_PRESSED, UiTokens.RUNE))
	theme.set_stylebox("hover_pressed", type, plate(UiTokens.PANEL_PRESSED, UiTokens.RUNE))
	var dim := UiTokens.PANEL
	dim.a *= 0.5
	theme.set_stylebox("disabled", type, plate(dim, UiTokens.LINE))
	var focus := plate(Color.TRANSPARENT, UiTokens.RUNE, UiTokens.BORDER_FOCUS)
	focus.draw_center = false
	theme.set_stylebox("focus", type, focus)
	theme.set_color("font_color", type, UiTokens.TEXT)
	theme.set_color("font_hover_color", type, UiTokens.RUNE)
	theme.set_color("font_focus_color", type, UiTokens.RUNE)
	theme.set_color("font_pressed_color", type, UiTokens.RUNE)
	theme.set_color("font_hover_pressed_color", type, UiTokens.RUNE)
	theme.set_color("font_disabled_color", type, UiTokens.FAINT)


static func _bars(theme: Theme) -> void:
	theme.set_stylebox("background", "ProgressBar", _bar(UiTokens.LINE))
	theme.set_stylebox("fill", "ProgressBar", _bar(UiTokens.RUNE))
	theme.set_type_variation(HOLD_BAR, "ProgressBar")
	theme.set_stylebox("background", HOLD_BAR, StyleBoxEmpty.new())
	theme.set_stylebox("fill", HOLD_BAR, _bar(UiTokens.EMBER))


static func _bar(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_content_margin_all(0.0)
	return box


static func _sliders(theme: Theme) -> void:
	var track := _bar(UiTokens.LINE)
	track.content_margin_top = 1.0
	track.content_margin_bottom = 1.0
	theme.set_stylebox("slider", "HSlider", track)
	var lit := _bar(UiTokens.RUNE)
	lit.content_margin_top = 1.0
	lit.content_margin_bottom = 1.0
	theme.set_stylebox("grabber_area", "HSlider", lit)
	theme.set_stylebox("grabber_area_highlight", "HSlider", lit)
	theme.set_icon("grabber", "HSlider", diamond(18, UiTokens.RUNE))
	theme.set_icon("grabber_highlight", "HSlider", diamond(18, UiTokens.TEXT))


static func _scrolling(theme: Theme) -> void:
	var gutter := StyleBoxFlat.new()
	gutter.bg_color = UiTokens.LINE
	gutter.bg_color.a = 0.4
	gutter.content_margin_left = 2.0
	gutter.content_margin_right = 2.0
	theme.set_stylebox("scroll", "VScrollBar", gutter)
	theme.set_stylebox("scroll_focus", "VScrollBar", gutter)
	var grip := _bar(UiTokens.SIGIL)
	grip.bg_color.a = 0.55
	grip.content_margin_left = 2.0
	grip.content_margin_right = 2.0
	theme.set_stylebox("grabber", "VScrollBar", grip)
	var lit := _bar(UiTokens.RUNE)
	theme.set_stylebox("grabber_highlight", "VScrollBar", lit)
	theme.set_stylebox("grabber_pressed", "VScrollBar", lit)


static func _panels(theme: Theme) -> void:
	var panel := plate(UiTokens.PANEL, UiTokens.LINE)
	panel.set_content_margin_all(UiTokens.PAD)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)


## A filled diamond [param size] pixels across, for slider grabbers.
static func diamond(size: int, color: Color) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			# Distance outside the diamond's edge, in pixels, softened over one.
			var reach := absf(x + 0.5 - half) + absf(y + 0.5 - half)
			var cover := clampf(half - 1.0 - reach + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(color, color.a * cover))
	return ImageTexture.create_from_image(image)
