class_name PainterlyStyle
extends Resource
## Look of the fluid, kept apart from how it moves.
##
## [FluidConfig] decides what the water does; this decides how it is painted.
## They are separate resources on purpose — retuning the palette should never
## risk changing the physics, and one style can dress several tanks.

@export_group("Pigment")
## The unpainted ground. Everything is a wash over this.
@export var paper_color: Color = Color(0.129, 0.156, 0.219)

## Colour the wash tends towards where pigment piles up thickest.
@export var deep_color: Color = Color(0.043, 0.055, 0.098)

## Per-channel absorption. Unequal channels are what stops thick pigment from
## going flatly grey — here blue survives longest, so depth reads cold.
@export var absorption: Vector3 = Vector3(1.15, 1.45, 1.75)

## Pigment present everywhere, even with no dye. Sets the resting depth.
@export_range(0.0, 2.0, 0.01) var ambient_density: float = 0.28

## How quickly a thin wash reaches its full colour.
@export_range(0.1, 4.0, 0.05) var pigment_gain: float = 1.5

@export_group("Brushwork")
## Brush width in simulation texels. This is the single strongest control over
## how abstract the result looks.
@export_range(0.0, 12.0, 0.1) var stroke_size: float = 2.4

## How far the brush elongates along the current at full speed.
@export_range(1.0, 8.0, 0.1) var stroke_stretch: float = 3.2

## Speed, in cells/second, at which the brush reaches full elongation.
@export_range(1.0, 400.0, 1.0) var stroke_speed_reference: float = 45.0

@export_group("Edges")
## Strength of the darker rim left where a wash stops.
@export_range(0.0, 2.0, 0.01) var edge_darkening: float = 0.7

## How far out the rim is measured, in texels. Wider reads as wetter paper.
@export_range(0.5, 6.0, 0.1) var edge_width: float = 1.8

@export_group("Paper")
## Depth of the paper tooth.
@export_range(0.0, 1.0, 0.01) var canvas_grain: float = 0.16

## Grain frequency. Should be tuned against output resolution, not tank size.
@export_range(16.0, 2048.0, 1.0) var canvas_scale: float = 420.0

## Hand-drawn unsteadiness along wash edges, in texels.
@export_range(0.0, 8.0, 0.05) var wobble: float = 1.1


## Push every parameter onto a material running `painterly.gdshader`.
func apply_to(material: ShaderMaterial) -> void:
	if material == null:
		return
	material.set_shader_parameter("paper_color", paper_color)
	material.set_shader_parameter("deep_color", deep_color)
	material.set_shader_parameter("absorption", absorption)
	material.set_shader_parameter("ambient_density", ambient_density)
	material.set_shader_parameter("pigment_gain", pigment_gain)
	material.set_shader_parameter("stroke_size", stroke_size)
	material.set_shader_parameter("stroke_stretch", stroke_stretch)
	material.set_shader_parameter("stroke_speed_reference", stroke_speed_reference)
	material.set_shader_parameter("edge_darkening", edge_darkening)
	material.set_shader_parameter("edge_width", edge_width)
	material.set_shader_parameter("canvas_grain", canvas_grain)
	material.set_shader_parameter("canvas_scale", canvas_scale)
	material.set_shader_parameter("wobble", wobble)
