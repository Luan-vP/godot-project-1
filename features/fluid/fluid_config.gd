class_name FluidConfig
extends Resource
## Tunables for [FluidSimulation].
##
## Two coordinate systems meet here. The simulation works in [b]cells per
## second[/b] on a square grid; the game works in [b]pixels per second[/b] over
## [member world_size]. [FluidField] is what converts between them, so nothing
## else has to care.

## Width and height of the simulation grid. Cost is quadratic in this, and the
## painterly pass hides a surprising amount of coarseness — 256 is plenty for a
## 1080p tank.
@export_range(32, 512, 32) var simulation_resolution: int = 256

## Grid the CPU reads back for gameplay. Far smaller than the simulation: the
## eyes need a current to drift on, not a shockwave front.
@export_range(16, 128, 8) var readback_resolution: int = 64

## Jacobi iterations per frame. More means a stricter incompressibility solve
## and tighter, longer-lived vortices; each one costs a full-grid pass. Too few
## leaves the fluid slightly compressible, and a big stir then rings off the
## walls and sloshes back — see the fluid README's Viscosity section.
@export_range(1, 128) var pressure_iterations: int = 12

## The slab of world the tank covers, in pixels.
@export var world_size: Vector2 = Vector2(1920.0, 1080.0)

@export_group("Motion")
## Fraction of the velocity field surviving one [b]second[/b]. Applied as
## pow(value, delta) each step, so the water slows at the same rate whatever
## the frame rate — a fixed per-frame multiplier ties fluid lifetime to the
## monitor's refresh.
@export_range(0.0, 1.0, 0.005) var velocity_dissipation: float = 0.84

## Fraction of the pigment surviving one second. This is what stops the tank
## silting up.
@export_range(0.0, 1.0, 0.005) var dye_dissipation: float = 0.70

## How hard energy is pushed back into existing swirls. Zero gives smooth,
## syrupy drift; high values give a churning, restless medium.
@export_range(0.0, 80.0, 0.5) var vorticity: float = 24.0

## Kinematic viscosity in [b]pixels squared per second[/b]: how far momentum
## spreads into the surrounding fluid, so how thick the medium is. Zero is
## inviscid and skips the diffusion passes entirely. Where
## [member velocity_dissipation] makes all motion fade, this makes sharp
## motion smear out — a thick fluid carries a stir as one slow sheet instead of
## a thin jet, and drags along the walls.
@export_range(0.0, 20000.0, 10.0, "or_greater") var viscosity: float = 0.0

## Jacobi iterations spent on viscous diffusion per frame, when
## [member viscosity] is above zero. Too few under-diffuses a very thick fluid:
## each iteration only spreads momentum about one cell further, so the
## effective thickness tops out around this many cells. Each is a full-grid
## pass. Read when the tank is built; changing it later has no effect.
@export_range(1, 64) var viscosity_iterations: int = 20

## How much the tank walls drag on a viscous fluid, from 0 (free-slip: the
## fluid slides along them and they take no momentum out) to 1 (no-slip: the
## fluid at the wall is held still, the physically correct boundary). With a
## high [member viscosity] in a small tank, no-slip drains a stir into the
## walls within a fraction of a second; lower this for a thick fluid that
## still coasts. Only the viscosity pass reads it.
@export_range(0.0, 1.0, 0.01) var wall_friction: float = 1.0

## A slow standing swell, so the tank never settles into dead water.
@export_range(0.0, 60.0, 0.5) var ambient_current: float = 12.0

## Wavelength of that swell, in tank-widths.
@export_range(0.25, 6.0, 0.05) var ambient_scale: float = 1.7

## Simulation steps are clamped to this. A long frame must not be allowed to
## advect the field halfway across the tank in one go.
@export_range(0.004, 0.1, 0.001) var max_time_step: float = 1.0 / 45.0

@export_group("Readback")
## Whether the CPU mirror is maintained at all. Turn this off for a purely
## decorative tank — it is the only part of the simulation that stalls the GPU.
@export var readback_enabled: bool = true

## Frames between readbacks. Every frame is rarely worth it; the field is
## smooth in time and the bodies reading it are floaty by design.
@export_range(1, 8) var readback_interval: int = 2


## Grid dimensions as a [Vector2i], for viewport sizing.
func simulation_size() -> Vector2i:
	return Vector2i(simulation_resolution, simulation_resolution)


## Readback grid dimensions as a [Vector2i].
func readback_size() -> Vector2i:
	return Vector2i(readback_resolution, readback_resolution)


## Size of one simulation cell in world pixels.
func cell_size() -> Vector2:
	return world_size / float(maxi(simulation_resolution, 1))


## Fraction of a field surviving a step of [param delta] seconds, given a
## per-second retention. Kept separate and pure because the alternative — a
## fixed multiplier per frame — decays at wildly different rates on a 30 Hz
## and a 144 Hz display, and that is not visible by reading the shader.
static func retention_over(per_second: float, delta: float) -> float:
	return pow(clampf(per_second, 0.0, 1.0), maxf(delta, 0.0))


## The implicit diffusion coefficient [code]nu * dt / h^2[/code] per axis for a
## step of [param delta] seconds, where [code]h[/code] is the cell's width or
## height in pixels. Separate axes because cells are only square when the tank
## is, and viscosity is specified in world units so it thickens the fluid
## evenly on screen and does not change with [member simulation_resolution].
func viscous_coefficients(delta: float) -> Vector2:
	var cell := cell_size()
	if viscosity <= 0.0 or delta <= 0.0 or cell.x <= 0.0 or cell.y <= 0.0:
		return Vector2.ZERO
	var spread := viscosity * delta
	return Vector2(spread / (cell.x * cell.x), spread / (cell.y * cell.y))
