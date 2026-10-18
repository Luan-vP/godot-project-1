class_name KeyPrint
extends Node
## Prints the band's key into the middle of the tank when a song starts and
## whenever the key moves, the way the splash prints its logo: the name
## ("F# minor"), in the menus' inscription face and the root's pin colour, to
## drift and swirl away with the water.
##
## [SharedLayers] keeps one, so it happens in every level, whichever of them
## moved the key.

## How wide the name is printed, as a share of the screen, and the most of
## its height it may take.
const WIDTH := 0.42
const MAX_HEIGHT := 0.2
## Pigment the name is printed with, and the size it is rendered at before
## it is scaled into the tank.
const DENSITY := 1.5
const FONT_SIZE := 96

var band: Band
var fluid: FluidSimulation


func _ready() -> void:
	if band != null:
		band.song_started.connect(_on_song_started)
		band.key_changed.connect(_on_key_changed)


## The key as it is printed: "F# minor".
static func key_name(root: int, minor: bool) -> String:
	return "%s %s" % [PinField.NOTE_NAMES[posmod(root, 12)], "minor" if minor else "major"]


## Where a printed name of [param aspect] (height over width) sits on a
## [param screen]-sized tank: centred, a share of the width, but never taller
## than a share of the height.
static func rect_for(screen: Vector2, aspect: float) -> Rect2:
	var width := minf(screen.x * WIDTH, screen.y * MAX_HEIGHT / aspect)
	var size := Vector2(width, width * aspect)
	return Rect2((screen - size) * 0.5, size)


## Print the band's key into the middle of the tank. Takes a frame to render
## the name; a no-op without a tank to print into.
func print_key() -> void:
	if band == null or fluid == null or not FluidGPU.is_available():
		return
	var root := band.key_root()
	var text := key_name(root, band.is_minor())
	var mask: Image = await DyePrint.render_text(self, text, UiTheme.display_font(), FONT_SIZE)
	if mask == null or not is_instance_valid(fluid):
		return
	var world := fluid.get_world_rect()
	var aspect := float(mask.get_height()) / mask.get_width()
	var rect := rect_for(get_viewport().get_visible_rect().size, aspect)
	rect.position -= world.position
	var cells := DyePrint.cells_for(rect, world.size, fluid.config.simulation_size())
	var color := PinField.note_color(root, 1.0).lightened(0.2)
	fluid.add_dye(DyePrint.tinted(mask, cells.size, color, DENSITY), cells.position)


func _on_song_started(_title: String) -> void:
	print_key()


func _on_key_changed(_offset: int) -> void:
	print_key()
