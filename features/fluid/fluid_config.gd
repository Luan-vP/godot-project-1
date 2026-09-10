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
## and tighter, longer-lived vortices; each one costs a full-grid pass.
@export_range(1, 32) var pressure_iterations: int = 12

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
