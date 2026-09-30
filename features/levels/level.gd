class_name Level
extends Resource
## Everything that makes one playable level read differently from another: its
## background, how the medium in front of it moves and looks, how much debris
## drifts there, and how looking around feels.
##
## References a [FluidConfig] rather than inlining its fields, the same reason
## [FluidConfig] and [PainterlyStyle]/[RefractionStyle] are kept apart — see
## the fluid README's note on that split. One medium's physics can then be
## shared and retuned once across every level that uses it, instead of a
## level's own tuning fighting it.
##
## Assigning [member PanoramaLevel.level] is the whole job of loading a level:
## no scene to edit, no script to touch.

## Equirectangular image shown behind the [PanoramaLookCamera].
@export var panorama_texture: Texture2D

## How the medium in front of the background moves. A reference, not an inline
## copy, so the same medium can be reused across levels and retuned once.
@export var fluid_config: FluidConfig

## Where the edges in [member panorama_texture] are, for Level 2 scoring
## ([code]#9[/code]) to judge floaters against. A reference behind the
## [EdgeSource] port, not inlined geometry, so a hand-authored overlay
## ([ManualEdgeSource]) and a future image-based detector are both just an
## [EdgeSource] this field can point at — see that class for the panorama
## space and once-per-load contract. Left [code]null[/code], a level simply
## has no edges to score against.
@export var edge_source: EdgeSource

@export_group("Floaters")
## How many drift in the medium.
@export_range(0, 400) var floater_count: int = 60

## Radius range floaters are drawn from, in pixels; see [member
## FloaterField.radius_range].
@export var floater_radius_range: Vector2 = Vector2(2.0, 8.0)

## Skews the radius distribution towards the small end above 1; see [member
## FloaterField.size_skew].
@export_range(0.1, 4.0) var floater_size_skew: float = 1.8

@export_group("Look")
## How strongly the medium bends the background behind it; see [member
## RefractionStyle.strength]. Zero turns the bend off entirely.
@export_range(0.0, 0.1, 0.001) var distortion_strength: float = 0.012

## Multiplies every look source's contribution; see [member
## PanoramaLookCamera.sensitivity]. 1 leaves each source's own sensitivity
## untouched.
@export_range(0.1, 5.0, 0.05) var look_sensitivity: float = 1.0


## A bright, high-key overcast sky where the floaters are the whole point:
## barely any bend to the medium, and enough debris that nobody could miss it.
static func overcast_sky() -> Level:
	var level := Level.new()
	level.panorama_texture = _gradient_panorama(
		Color(0.90, 0.93, 0.97), Color(0.80, 0.84, 0.90), Color(0.64, 0.68, 0.76)
	)
	var fluid := FluidConfig.new()
	fluid.viscosity = 200.0
	fluid.vorticity = 10.0
	fluid.ambient_current = 6.0
	level.fluid_config = fluid
	level.floater_count = 220
	level.floater_radius_range = Vector2(3.0, 14.0)
	level.floater_size_skew = 1.4
	level.distortion_strength = 0.02
	level.look_sensitivity = 1.0
	return level


## A dim interior where the medium sits almost still and its handful of
## floaters are easy to miss — proof the same systems can nearly vanish.
static func dim_interior() -> Level:
	var level := Level.new()
	level.panorama_texture = _gradient_panorama(
		Color(0.11, 0.10, 0.11), Color(0.07, 0.065, 0.075), Color(0.03, 0.03, 0.035)
	)
	var fluid := FluidConfig.new()
	fluid.viscosity = 1200.0
	fluid.vorticity = 0.0
	fluid.velocity_dissipation = 0.98
	fluid.ambient_current = 1.0
	level.fluid_config = fluid
	level.floater_count = 8
	level.floater_radius_range = Vector2(1.0, 3.0)
	level.floater_size_skew = 2.5
	level.distortion_strength = 0.002
	level.look_sensitivity = 0.6
	return level


## Level 1: pure exploration (issue #22). An overcast sky, brighter and flatter
## than [method overcast_sky], because a first-time player has to read one
## floater against it rather than take in a whole crowded field. No [member
## edge_source] and nothing outside [Level] itself tracks score, time, or an
## end condition — leaving is the only way this level ends.
##
## Fewer, larger floaters than [method overcast_sky] and a current between
## its brisk drift and [method dim_interior]'s near-stillness: enough motion
## to see, and enough settle time after a look that stopping still reads as
## the medium going still, not as nothing having happened.
static func pure_exploration() -> Level:
	var level := Level.new()
	level.panorama_texture = _gradient_panorama(
		Color(0.94, 0.96, 0.99), Color(0.89, 0.92, 0.96), Color(0.83, 0.86, 0.91)
	)
	var fluid := FluidConfig.new()
	fluid.viscosity = 260.0
	fluid.vorticity = 6.0
	fluid.ambient_current = 3.0
	level.fluid_config = fluid
	level.floater_count = 40
	level.floater_radius_range = Vector2(4.0, 12.0)
	level.floater_size_skew = 1.6
	level.distortion_strength = 0.006
	level.look_sensitivity = 1.0
	return level


## A small vertical-gradient equirectangular sky: [param top] at the zenith
## fading through [param horizon] to [param bottom] at the nadir. Generated
## rather than shipped as an image, the same reason [code]refraction_demo.gd[/code]
## paints its checkerboard in code — no binary asset, so no export-size cost.
static func _gradient_panorama(top: Color, horizon: Color, bottom: Color) -> ImageTexture:
	const WIDTH := 4
	const HEIGHT := 256
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
	for y in HEIGHT:
		var t := float(y) / float(HEIGHT - 1)
		var color := (
			top.lerp(horizon, t * 2.0) if t < 0.5 else horizon.lerp(bottom, (t - 0.5) * 2.0)
		)
		for x in WIDTH:
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
