class_name RefractionStyle
extends Resource
## How strongly a clear medium bends the background, kept apart from how it
## moves.
##
## Pairs with [FluidRefractionRenderer] the way [PainterlyStyle] pairs with
## [FluidRenderer] — a separate resource so retuning the bend can never touch
## the physics, and one style can dress several tanks.

## How far the background sample shifts, in UV. Kept small on purpose: the
## medium should be nearly invisible at rest and only read as a ripple where
## the fluid is actually moving. Zero turns the bend off entirely.
@export_range(0.0, 0.1, 0.001) var strength: float = 0.012

## Speed, in cells/second, at which the bend reaches full strength. Lower this
## to make a gentle drift visible; raise it so only a hard swish shows.
@export_range(1.0, 400.0, 1.0) var speed_reference: float = 50.0


## Push every parameter onto a material running `refraction.gdshader`.
func apply_to(material: ShaderMaterial) -> void:
	if material == null:
		return
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("speed_reference", speed_reference)
