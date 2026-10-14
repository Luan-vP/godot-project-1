extends GutTest
## Covers the menus' design system: one shared theme with every role in it,
## cards made one way, and menus that take their whole look from the theme.

## Every menu script, which must leave colours and type to the theme.
const MENU_SCRIPTS := [
	"res://features/ui/demo_menu/demo_menu.gd",
	"res://features/ui/pr_picker/pr_picker.gd",
	"res://features/ui/comfort_settings/comfort_settings_demo.gd",
]

## Every script that puts text or controls over a level or a demo. Their game
## art may have colours of its own; their text and controls may not.
const HUD_SCRIPTS := [
	"res://autoload/TempoControl.gd",
	"res://core/audio/audio_demo.gd",
	"res://core/audio/groove_demo.gd",
	"res://core/audio/synth_demo.gd",
	"res://core/motion/motion_demo.gd",
	"res://core/motion/motion_debug_overlay.gd",
	"res://features/levels/boids/boids_level.gd",
	"res://features/levels/secret_eyes/eye_band_demo.gd",
	"res://features/levels/spout/spout_level.gd",
	"res://features/levels/spout/pin_field.gd",
	"res://features/ui/level_meter_overlay.gd",
]

## The pull request picker is left out: opening it asks GitHub for the list.
const MENU_SCENES := [
	"res://features/ui/demo_menu/demo_menu.tscn",
	"res://features/ui/comfort_settings/comfort_settings_demo.tscn",
]


func test_the_theme_is_built_once_and_shared() -> void:
	assert_same(UiTheme.get_theme(), UiTheme.get_theme())


func test_every_role_is_in_the_theme() -> void:
	var theme := UiTheme.get_theme()
	var labels := [
		UiTheme.TITLE,
		UiTheme.KICKER,
		UiTheme.HINT,
		UiTheme.STATUS,
		UiTheme.LOG,
		UiTheme.CARD_TITLE,
		UiTheme.CARD_BLURB,
		UiTheme.CARD_INDEX,
	]
	for role in labels:
		assert_eq(theme.get_type_variation_base(role), &"Label", "%s is a Label role" % role)
		assert_true(theme.has_font("font", role), "%s has a font" % role)
	for role in [UiTheme.HUD, UiTheme.HUD_FAINT, UiTheme.TOAST]:
		assert_eq(theme.get_type_variation_base(role), &"Label", "%s is a Label role" % role)
	assert_eq(theme.get_type_variation_base(UiTheme.HUD_PANEL), &"PanelContainer")
	for role in [UiTheme.CARD, UiTheme.GHOST]:
		assert_eq(theme.get_type_variation_base(role), &"Button", "%s is a Button role" % role)
	assert_eq(theme.get_type_variation_base(UiTheme.HOLD_BAR), &"ProgressBar")


func test_the_fonts_load() -> void:
	assert_not_null(load(UiTokens.DISPLAY_FONT_PATH), "Display face")
	assert_not_null(load(UiTokens.MONO_FONT_PATH), "Mono face")
	assert_eq(UiTheme.get_theme().default_font, UiTheme.mono_font(), "Mono by default")


func test_a_card_carries_its_text_and_ornament() -> void:
	var card := ArcaneCard.make("Synth", "Synth", "Voices.", ArcaneCard.index_for(10))
	add_child_autofree(card)
	assert_eq(card.theme_type_variation, UiTheme.CARD, "Card role")
	var title := card.find_child("Title", true, false) as Label
	assert_eq(title.text, "Synth")
	assert_eq((card.find_child("Blurb", true, false) as Label).text, "Voices.")
	assert_eq((card.find_child("Index", true, false) as Label).text, "0x0A")
	assert_not_null(card.find_child("Ornament", true, false), "Ornament")
	for label: Label in card.find_children("*", "Label", true, false):
		assert_eq(
			label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s lets clicks through" % label.name
		)


func test_a_card_without_blurb_or_index_leaves_them_out() -> void:
	var card := ArcaneCard.make("Bare", "Bare", "", "")
	add_child_autofree(card)
	assert_null(card.find_child("Blurb", true, false))
	assert_null(card.find_child("Index", true, false))


func test_a_header_has_kicker_title_rule_and_hint() -> void:
	var header := UiTheme.header("KICKER", "Title", "Hint")
	add_child_autofree(header)
	assert_eq((header.get_node("Kicker") as Label).theme_type_variation, UiTheme.KICKER)
	assert_eq((header.get_node("Title") as Label).theme_type_variation, UiTheme.TITLE)
	assert_not_null(header.get_node_or_null("Rule"))
	assert_eq((header.get_node("Hint") as Label).text, "Hint")
	assert_null(UiTheme.header("K", "T").get_node_or_null("Hint"), "No hint, no hint label")


func test_menus_take_the_shared_theme() -> void:
	for path in MENU_SCENES:
		var menu: Control = load(path).instantiate()
		add_child_autofree(menu)
		assert_same(menu.theme, UiTheme.get_theme(), path)
		assert_not_null(menu.find_children("*", "ArcaneBackdrop", true, false).front(), path)


func test_menu_labels_set_no_colours_or_sizes_of_their_own() -> void:
	for path in MENU_SCENES:
		var menu: Control = load(path).instantiate()
		add_child_autofree(menu)
		for label: Label in menu.find_children("*", "Label", true, false):
			assert_false(
				label.has_theme_color_override("font_color"), "%s in %s" % [label.name, path]
			)
			assert_false(
				label.has_theme_font_size_override("font_size"), "%s in %s" % [label.name, path]
			)


func test_menu_scripts_leave_colour_and_type_to_the_tokens() -> void:
	for path in MENU_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.contains("Color("), "%s builds no colours" % path)
		assert_false(source.contains("font_size_override"), "%s sets no font sizes" % path)
		assert_false(source.contains("theme_color_override"), "%s sets no colours" % path)


func test_a_diamond_is_solid_in_the_middle_and_clear_in_the_corners() -> void:
	var image := UiTheme.diamond(18, Color.WHITE).get_image()
	assert_eq(image.get_pixel(9, 9).a, 1.0, "Centre")
	assert_eq(image.get_pixel(0, 0).a, 0.0, "Corner")


func test_installed_the_look_reaches_controls_with_no_theme_above_them() -> void:
	UiTheme.install()
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var hud := UiTheme.label("70 bpm", UiTheme.TOAST)
	layer.add_child(hud)
	assert_eq(
		hud.get_theme_font_size("font_size"), UiTokens.SIZE_TOAST, "A role, through a CanvasLayer"
	)
	var plain := Label.new()
	layer.add_child(plain)
	assert_eq(plain.get_theme_font("font"), UiTheme.mono_font(), "A plain Label gets the mono face")
	assert_eq(ThemeDB.fallback_font, UiTheme.mono_font(), "draw_string's fallback too")


func test_the_faces_fall_back_to_the_symbol_font() -> void:
	for font in [UiTheme.mono_font(), UiTheme.display_font(), UiTheme.mono_font(2)]:
		assert_eq(font.fallbacks.size(), 1, "One fallback")
		assert_eq(font.fallbacks[0], load(UiTokens.SYMBOL_FONT_PATH), "The symbol font")
	var symbols := load(UiTokens.SYMBOL_FONT_PATH) as Font
	for glyph in ["♩", "♪", "←", "→", "↑", "↓", "●", "○", "◐", "▸"]:
		assert_true(symbols.has_char(glyph.unicode_at(0)), "Symbol font has %s" % glyph)


func test_hud_scripts_leave_text_colour_and_type_to_the_theme() -> void:
	for path in HUD_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.contains("font_size_override"), "%s sets no font sizes" % path)
		assert_false(source.contains("theme_color_override"), "%s sets no text colours" % path)
		assert_false(source.contains("ThemeDB.fallback_font"), "%s draws in the HUD face" % path)
