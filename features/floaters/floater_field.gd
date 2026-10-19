class_name FloaterField
extends Node2D
## Populates a [FluidSimulation] with a configurable dusting of [Floater]s.
##
## A level picks how much debris its tank has and how it is sized by setting
## the exports below — the count and the size distribution are the whole
## interface, not a fixed roster of scenes.
##
## Given [member depths], the population is also split across depth bands and
## each band is drawn out of focus. Each band is an offscreen, transparent
## [SubViewport] its floaters draw into at their real positions, blurred in a
## second [SubViewport] around it, and composited back over the screen as
## glass. That assumes this field sits untransformed over the whole viewport —
## true of a screen-space overlay, which is what floaters are.
##
## Both offscreen passes draw at the resolution [RenderScale] gives — on a
## phone, a quarter of the screen's pixels — and only the cheap glass
## composite runs at the screen's own.

const BOKEH_SHADER := preload("res://features/floaters/shaders/bokeh.gdshader")
const GLASS_SHADER := preload("res://features/floaters/shaders/bokeh_glass.gdshader")

## How many floaters to keep in the tank.
@export_range(0, 400) var count: int = 60

## Radius range floaters are drawn from, in pixels.
@export var radius_range: Vector2 = Vector2(2.0, 8.0)

## Skews the radius distribution towards the small end of [member
## radius_range] when above 1 — real floaters are mostly small specks with a
## few large clumps, not a flat spread. 1 is uniform.
@export_range(0.1, 4.0) var size_skew: float = 1.8

## Relative odds of dot, strand and cobweb, in that order. Need not sum to
## anything in particular — they are normalised against each other.
@export var shape_weights: Vector3 = Vector3(3.0, 2.0, 1.0)

@export var color: Color = ArtPalette.FLOATER

## Tank to populate. Left empty, the first tank in the scene is used.
@export var simulation_path: NodePath

@export_group("Shape")
## Radius range for dots alone, in pixels. Left at zero, dots use [member
## radius_range]. Separate ranges are what allow the tiniest specks alongside
## long strands, which one shared range cannot.
@export var dot_radius_range: Vector2 = Vector2.ZERO

## Radius range for strands alone — half their length, in pixels. Zero falls
## back to [member radius_range].
@export var strand_radius_range: Vector2 = Vector2.ZERO

## Radius range for cobwebs alone, in pixels. Zero falls back to [member
## radius_range].
@export var cobweb_radius_range: Vector2 = Vector2.ZERO

## How far a strand wanders off straight per segment; see [method
## FloaterShape.make_strand]. Lower is straighter.
@export_range(0.0, 1.0, 0.01) var strand_wander: float = 0.3

## Line thickness in pixels for strands and cobweb arms, whatever the floater's
## size. Zero keeps each shape's own proportion of its radius, so a long strand
## draws thicker than a short one.
@export_range(0.0, 8.0, 0.1) var line_width_px: float = 0.0

## Spin each floater to a random angle. Off, every strand lies left to right,
## which reads as hatching once there are many of them.
@export var random_rotation: bool = false

@export_group("Motion")
## Copied onto every floater. The defaults match [Floater]'s own; a thicker
## medium wants a higher [member drag] so floaters ride with it rather than
## coast through it.
@export var drag: float = 2.2

## Sinking rate copied onto every floater; see [member FluidBody.buoyancy].
@export var buoyancy: float = 12.0

## Speed cap copied onto every floater.
@export var max_speed: float = 140.0

@export_group("Focus")
## Depth bands, far to near. Empty draws every floater sharp, directly, with no
## offscreen layers at all.
@export var depths: Array[FloaterDepth] = []

## Whether bands are blurred. Off shows the same bands sharp, which is useful
## for comparing the two.
@export var defocus_enabled: bool = true:
	set = set_defocus_enabled

## Most a banded floater bends the background behind it, in screen pixels —
## the faint lens that makes debris read as glass. Zero turns it off.
@export_range(0.0, 8.0, 0.1) var refraction_px: float = 1.5:
	set = set_refraction_px

var _rng := RandomNumberGenerator.new()
var _layers: Array[SubViewport] = []
var _blurs: Array[SubViewport] = []
var _blur_materials: Array[ShaderMaterial] = []
var _materials: Array[ShaderMaterial] = []
var _composites: Array[Sprite2D] = []
# Buffer pixels per canvas unit, which the blur radius is measured against.
var _texels_per_unit := 1.0


func _ready() -> void:
	_rng.randomize()
	var simulation := _resolve_simulation()
	if simulation == null:
		return
	_build_layers()
	var rect := simulation.get_world_rect()
	for i in count:
		var depth_index := pick_depth(_rng, depths)
		var parent: Node = self if depth_index < 0 else _layers[depth_index]
		parent.add_child(_make_floater(rect, depth_index))


func set_defocus_enabled(value: bool) -> void:
	defocus_enabled = value
	_apply_focus()


func set_refraction_px(value: float) -> void:
	refraction_px = value
	_apply_focus()


## The layer a depth band draws into, or null when the field has no bands.
func get_layer(depth_index: int) -> SubViewport:
	if depth_index < 0 or depth_index >= _layers.size():
		return null
	return _layers[depth_index]


## The blur pass of a depth band, or null when the field has no bands.
func get_blur(depth_index: int) -> SubViewport:
	if depth_index < 0 or depth_index >= _blurs.size():
		return null
	return _blurs[depth_index]


## Radius range for a shape [param family] (0 dot, 1 strand, 2 cobweb): its own
## override when one is set, otherwise [member radius_range].
func radius_range_for(family: int) -> Vector2:
	var override: Vector2 = [dot_radius_range, strand_radius_range, cobweb_radius_range][family]
	return radius_range if override == Vector2.ZERO else override


func _resolve_simulation() -> FluidSimulation:
	if not simulation_path.is_empty():
		return get_node_or_null(simulation_path) as FluidSimulation
	return get_tree().get_first_node_in_group(FluidSimulation.GROUP_NAME) as FluidSimulation


func _build_layers() -> void:
	for depth in depths:
		# The blur reads the layer, so the layer sits inside it: a viewport's
		# children draw before it does, so the blur never sees last frame's.
		var blur := SubViewport.new()
		blur.transparent_bg = true
		blur.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(blur)
		_blurs.append(blur)

		# The layer lays out in canvas units, whatever its resolution, so
		# floaters draw into it at their real positions.
		var layer := SubViewport.new()
		layer.transparent_bg = true
		layer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		layer.size_2d_override_stretch = true
		blur.add_child(layer)
		_layers.append(layer)

		var blur_material := ShaderMaterial.new()
		blur_material.shader = BOKEH_SHADER
		_blur_materials.append(blur_material)

		var blurred := Sprite2D.new()
		blurred.centered = false
		blurred.texture = layer.get_texture()
		blurred.material = blur_material
		blur.add_child(blurred)

		var material := ShaderMaterial.new()
		material.shader = GLASS_SHADER
		_materials.append(material)

		# Each composite reads the screen behind it, and the screen texture is
		# otherwise copied once per frame — a nearer band would read a screen
		# without the farther bands in it and paint over them. A fresh copy per
		# band costs one full-screen blit each.
		var copy := BackBufferCopy.new()
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(copy)

		var composite := Sprite2D.new()
		composite.centered = false
		composite.texture = blur.get_texture()
		composite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		composite.material = material
		add_child(composite)
		_composites.append(composite)

	if not _layers.is_empty():
		_fit_layers()
		get_viewport().size_changed.connect(_fit_layers)
	_apply_focus()


func _fit_layers() -> void:
	var canvas := get_viewport_rect().size
	var buffer := RenderScale.buffer_size_for(get_viewport(), canvas)
	_texels_per_unit = float(buffer.x) / maxf(canvas.x, 1.0)
	for i in _layers.size():
		_layers[i].size = buffer
		_layers[i].size_2d_override = Vector2i(canvas.round())
		_blurs[i].size = buffer
		_composites[i].scale = canvas / Vector2(buffer)
	_apply_focus()


func _apply_focus() -> void:
	for i in _materials.size():
		var depth := depths[i]
		var tint := color
		tint.a *= depth.opacity
		_materials[i].set_shader_parameter("tint", tint)
		_materials[i].set_shader_parameter("refraction_px", refraction_px)
		var radius := depth.blur_px * _texels_per_unit if defocus_enabled else 0.0
		_blur_materials[i].set_shader_parameter("radius_px", radius)
		_blur_materials[i].set_shader_parameter("gain", depth.gain if defocus_enabled else 1.0)


func _make_floater(rect: Rect2, depth_index: int) -> Floater:
	var family := pick_family(_rng, shape_weights)
	var magnify := 1.0 if depth_index < 0 else depths[depth_index].magnify
	var floater := Floater.new()
	floater.radius = sampled_radius(_rng, radius_range_for(family), size_skew) * magnify
	floater.shape = _make_shape(_rng, family, strand_wander)
	if line_width_px > 0.0 and family != 0:
		floater.shape.strand_width = line_width_px / maxf(floater.radius, 0.001)
	if random_rotation:
		floater.rotation = _rng.randf() * TAU
	# Inside a band the layer only records coverage; its composite owns colour.
	floater.color = color if depth_index < 0 else Color.WHITE
	floater.drag = drag
	floater.buoyancy = buoyancy
	floater.max_speed = max_speed
	floater.global_position = rect.position + Vector2(_rng.randf(), _rng.randf()) * rect.size
	return floater


## A radius drawn from [param radius_range], skewed towards the low end by
## [param skew] (1 is uniform, higher pushes the distribution smaller). Kept
## pure and static so the distribution can be checked without a scene tree.
static func sampled_radius(rng: RandomNumberGenerator, radius_range: Vector2, skew: float) -> float:
	return lerpf(radius_range.x, radius_range.y, pow(rng.randf(), skew))


## Picks a shape family index (0 dot, 1 strand, 2 cobweb) from [param weights],
## which need not be normalised. Static and pure for the same reason as
## [method sampled_radius].
static func pick_family(rng: RandomNumberGenerator, weights: Vector3) -> int:
	var total := weights.x + weights.y + weights.z
	if total <= 0.0:
		return 0
	var roll := rng.randf() * total
	if roll < weights.x:
		return 0
	if roll < weights.x + weights.y:
		return 1
	return 2


## Picks a band index from [param bands] by their shares, or -1 when there are
## no bands. All-zero shares fall back to the first band.
static func pick_depth(rng: RandomNumberGenerator, bands: Array[FloaterDepth]) -> int:
	if bands.is_empty():
		return -1
	var total := 0.0
	for band in bands:
		total += maxf(band.share, 0.0)
	if total <= 0.0:
		return 0
	var roll := rng.randf() * total
	for i in bands.size():
		roll -= maxf(bands[i].share, 0.0)
		if roll < 0.0:
			return i
	return bands.size() - 1


static func _make_shape(rng: RandomNumberGenerator, family: int, wander: float) -> FloaterShape:
	match family:
		0:
			return FloaterShape.make_dot()
		1:
			return FloaterShape.make_strand(rng, 6, wander)
		_:
			return FloaterShape.make_cobweb(rng)
