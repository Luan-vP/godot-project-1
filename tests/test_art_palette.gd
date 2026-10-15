extends GutTest
## Covers the game art's palette: one set of dyes everywhere, a pitch wheel
## through them, and art scripts that take their colours from it.

## Every script that colours game art. Each may fade or mix the palette's
## colours, or clear to transparent, but spells out no colour of its own.
const ART_SCRIPTS := [
	"res://core/audio/rhythm/rhythm_table.gd",
	"res://features/floaters/floater.gd",
	"res://features/floaters/floater_field.gd",
	"res://features/fluid/fluid_body.gd",
	"res://features/fluid/fluid_motion_driver.gd",
	"res://features/fluid/painterly_style.gd",
	"res://features/levels/boids/boids_level.gd",
	"res://features/levels/carousel/shared_layers.gd",
	"res://features/levels/secret_eyes/eye_band_demo.gd",
	"res://features/levels/secret_eyes/floaty_eye.gd",
	"res://features/levels/spout/pin_field.gd",
	"res://features/levels/spout/spout.gd",
	"res://features/levels/spout/a_fluid/droplet.gd",
	"res://features/levels/spout/a_fluid/fluid_emitter.gd",
	"res://features/levels/spout/b_balls/ball_emitter.gd",
	"res://features/levels/spout/b_balls/spout_ball.gd",
]


func test_every_pour_uses_the_same_dyes() -> void:
	assert_eq(SharedLayers.SEED_PALETTE, ArtPalette.DYES, "Seed blobs")
	assert_eq(FluidEmitter.PALETTE, ArtPalette.DYES, "Spout stream")
	assert_eq(ArtPalette.dye(ArtPalette.DYES.size()), ArtPalette.DYES[0], "Wraps")


func test_pins_take_twelve_distinct_colours() -> void:
	var seen := {}
	for note in 12:
		seen[PinField.note_color(note).to_html()] = true
	assert_eq(seen.size(), 12, "One per pitch class")
	assert_eq(PinField.note_color(0), PinField.note_color(12), "Octaves match")


func test_the_art_does_not_lean_on_the_ui_tokens() -> void:
	# So the menus can be restyled without the water changing with them.
	var source := FileAccess.get_file_as_string("res://features/ui/design/art_palette.gd")
	assert_false(source.contains("UiTokens."), "ArtPalette stands on its own")


func test_the_paper_is_a_light_slate_not_a_void() -> void:
	assert_gt(ArtPalette.PAPER.get_luminance(), 0.12, "Light enough for a wash to read")
	assert_gt(ArtPalette.PAPER.b, ArtPalette.PAPER.r, "Blue-slate")


func test_the_tank_paints_on_the_palettes_paper() -> void:
	var style := PainterlyStyle.new()
	assert_eq(style.paper_color, ArtPalette.PAPER)
	assert_eq(style.deep_color, ArtPalette.DEEP)
	assert_eq(style.absorption, ArtPalette.ABSORPTION)


func test_art_scripts_spell_out_no_colours_of_their_own() -> void:
	var literal := RegEx.create_from_string("Color\\(\\s*[0-9]")
	var transparent := RegEx.create_from_string(
		"Color\\(\\s*0(\\.0)?,\\s*0(\\.0)?,\\s*0(\\.0)?,\\s*0(\\.0)?\\s*\\)"
	)
	for path in ART_SCRIPTS:
		var source := FileAccess.get_file_as_string(path)
		var stripped := transparent.sub(source, "", true)
		assert_null(literal.search(stripped), "%s takes its colours from ArtPalette" % path)
