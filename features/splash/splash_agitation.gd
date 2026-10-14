class_name SplashAgitation
extends Resource
## How the splash stirs the tank once time starts: the one thing that differs
## between the fluid splash's versions. [Splash] calls [method stir] every frame
## for [member seconds], then leaves the water to settle on its own.

## How long the stirring lasts.
@export var seconds: float = 1.4


## Push [param fluid] for one frame, [param t] seconds into the stirring (0 to
## [member seconds]), [param delta] long. [param logo] is the logo's rectangle
## in world pixels, which is what there is to stir.
func stir(_fluid: FluidSimulation, _t: float, _delta: float, _logo: Rect2) -> void:
	pass
