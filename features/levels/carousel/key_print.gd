class_name KeyPrint
extends Node
## Prints the band's key into the middle of the tank when a song starts and
## whenever the key moves, the way the splash prints its logo: the name
## ("F# minor"), in the menus' inscription face and the root's pin colour, to
## drift and swirl away with the water.
##
## [SharedLayers] keeps one, so it happens in every level, whichever of them
## moved the key. The name goes in the middle, unless the level on the stage
## has a [code]prints_key_anywhere()[/code] that says true (the eye tank's
## does): then it lands at a random spot, wholly on the screen.
##
## Every move of the band's scale ([signal Band.scale_changed]) prints the
## scale's name too, smaller and higher up ([method print_scale]); the spout
## also prints it when it arrives. A scale's name hovers over the water for
## [constant SCALE_HOVER] seconds first, so it can be read before it swirls
## away. A level can print other names the same way with [method print_name].

## How wide the name is printed, as a share of the screen, and the most of
## its height it may take.
const WIDTH := 0.42
const MAX_HEIGHT := 0.2
## Pigment the name is printed with, and the size it is rendered at before
## it is scaled into the tank.
const DENSITY := 1.5
const FONT_SIZE := 96
## Pixels a name printed anywhere keeps clear of the screen's edges.
const MARGIN := 24.0
## A scale's name: narrower and shorter than a key's, and centred this far
## down the screen, above the key's.
const SCALE_WIDTH := 0.5
const SCALE_MAX_HEIGHT := 0.14
const SCALE_HEIGHT := 0.3
## Seconds a scale's name hovers over the water before it is printed into it,
## and the seconds it takes to fade in, and out as it is printed.
const SCALE_HOVER := 1.5
const HOVER_FADE := 0.25
## Over the levels, under [KeyScaleButtons].
const HOVER_LAYER := 85

var band: Band
var fluid: FluidSimulation
## Where the levels are, to ask the newest where it wants the name.
var stage: Node

var _rng := RandomNumberGenerator.new()
## Whether the band's first song has started; it prints only that one, as
## every later one also moves the key.
var _heard_song := false
## Where names hover before they are printed.
var _overlay: CanvasLayer
## Counts hovering names; a newer one cuts the one before short.
var _hover_id := 0


func _ready() -> void:
	_rng.randomize()
	_overlay = CanvasLayer.new()
	_overlay.name = "Hover"
	_overlay.layer = HOVER_LAYER
	add_child(_overlay)
	if band != null:
		band.song_started.connect(_on_song_started)
		band.key_changed.connect(_on_key_changed)
		band.scale_changed.connect(print_scale)


## The key as it is printed: "F# minor".
static func key_name(root: int, minor: bool) -> String:
	return "%s %s" % [PinField.NOTE_NAMES[posmod(root, 12)], "minor" if minor else "major"]


## Where a printed name of [param aspect] (height over width) sits on a
## [param screen]-sized tank: centred across it with its middle
## [param height] of the way down, [param width] of the screen wide but never
## taller than [param max_height] of it.
static func rect_for(
	screen: Vector2,
	aspect: float,
	width: float = WIDTH,
	max_height: float = MAX_HEIGHT,
	height: float = 0.5
) -> Rect2:
	var across := minf(screen.x * width, screen.y * max_height / aspect)
	var size := Vector2(across, across * aspect)
	return Rect2(Vector2(screen.x * 0.5, screen.y * height) - size * 0.5, size)


## [param rect] moved to a random spot on a [param screen]-sized tank, all of
## it on the screen and clear of its edges by [constant MARGIN] where the
## screen has room.
static func anywhere(rect: Rect2, screen: Vector2, rng: RandomNumberGenerator) -> Rect2:
	var room := (screen - rect.size - Vector2.ONE * MARGIN * 2.0).max(Vector2.ZERO)
	var spot := Vector2(rng.randf() * room.x, rng.randf() * room.y)
	var inset := ((screen - rect.size) * 0.5).min(Vector2.ONE * MARGIN).max(Vector2.ZERO)
	return Rect2(inset + spot, rect.size)


## Whether the level on the stage wants the name anywhere rather than in the
## middle. The newest level is the one arriving.
func wants_anywhere() -> bool:
	if stage == null or stage.get_child_count() == 0:
		return false
	var level := stage.get_child(stage.get_child_count() - 1)
	return level.has_method("prints_key_anywhere") and level.prints_key_anywhere()


## Print the band's key into the tank, in the middle or anywhere, in its
## root's pin colour.
func print_key() -> void:
	if band == null:
		return
	var root := band.key_root()
	var color := PinField.note_color(root, 1.0).lightened(0.2)
	var at_random := wants_anywhere()
	var place := func(screen: Vector2, aspect: float) -> Rect2:
		var rect := rect_for(screen, aspect)
		return anywhere(rect, screen, _rng) if at_random else rect
	print_name(key_name(root, band.is_minor()), color, place)


## Print a scale's name ("minor pentatonic"), smaller and above where the
## key goes, in the band's root colour, paled.
func print_scale(scale_name: String) -> void:
	if band == null:
		return
	var color := PinField.note_color(band.key_root(), 1.0).lerp(Color.WHITE, 0.45)
	var place := func(screen: Vector2, aspect: float) -> Rect2:
		return rect_for(screen, aspect, SCALE_WIDTH, SCALE_MAX_HEIGHT, SCALE_HEIGHT)
	print_name(scale_name, color, place, SCALE_HOVER)


## Print [param text] into the tank in [param color], at the screen rect
## [param place] gives for the screen's size and the rendered text's aspect
## (height over width), as [method rect_for] lays one out. With a
## [param hover], the name first floats over the water there for that many
## seconds, or until the next hovering name. Takes a frame to render the
## text; a no-op without a tank to print into.
func print_name(text: String, color: Color, place: Callable, hover: float = 0.0) -> void:
	if fluid == null or not FluidGPU.is_available():
		return
	var mask: Image = await DyePrint.render_text(self, text, UiTheme.display_font(), FONT_SIZE)
	if mask == null or not is_instance_valid(fluid):
		return
	var world := fluid.get_world_rect()
	var aspect := float(mask.get_height()) / mask.get_width()
	var screen := get_viewport().get_visible_rect().size
	var rect: Rect2 = place.call(screen, aspect)
	if hover > 0.0:
		await _hover(mask, color, rect, hover)
		if not is_instance_valid(fluid) or not is_inside_tree():
			return
		world = fluid.get_world_rect()
	rect.position -= world.position
	var cells := DyePrint.cells_for(rect, world.size, fluid.config.simulation_size())
	fluid.add_dye(DyePrint.tinted(mask, cells.size, color, DENSITY), cells.position)


## Float [param mask] in [param color] over the screen at [param rect] for
## [param seconds], or until another name starts hovering, then fade it out
## while the caller prints it into the water beneath.
func _hover(mask: Image, color: Color, rect: Rect2, seconds: float) -> void:
	_hover_id += 1
	var id := _hover_id
	var shape := TextureRect.new()
	shape.texture = ImageTexture.create_from_image(mask)
	shape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shape.stretch_mode = TextureRect.STRETCH_SCALE
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.position = rect.position
	shape.size = rect.size
	shape.modulate = Color(color, 0.0)
	_overlay.add_child(shape)
	shape.create_tween().tween_property(shape, "modulate:a", 1.0, HOVER_FADE)
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until and _hover_id == id and is_inside_tree():
		await get_tree().process_frame
	if not is_instance_valid(shape):
		return
	var fade := shape.create_tween()
	fade.tween_property(shape, "modulate:a", 0.0, HOVER_FADE)
	fade.tween_callback(shape.queue_free)


func _on_song_started(_title: String) -> void:
	# A later song (Band.next_song) says so with key_changed too, which prints.
	if _heard_song:
		return
	_heard_song = true
	# The first song starts while the carousel is still being built, before the
	# stage or its first level exists. Wait a frame so wants_anywhere() sees it.
	await get_tree().process_frame
	if is_inside_tree():
		print_key()


func _on_key_changed(_offset: int) -> void:
	print_key()
