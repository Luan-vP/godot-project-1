class_name BirdWakes
extends RefCounted
## How birds stir the fluid behind the sky. One-way on purpose: birds push the
## water, the water never pushes birds — [FlockSim] never samples it.
##
## A tank takes only [constant FluidSimulation.MAX_SPLATS] stirrers a frame
## and drops the faintest past that, so 64 birds each pushing on their own
## would leave most of the sky still. Instead birds are binned on a coarse
## grid and each occupied cell pushes once, with the summed momentum of the
## birds in it: a flock reads as one broad wake, and a lone bird as a faint
## one that still makes the cut when the sky is quiet.


## One cell's worth of birds: where they are on average, the sum of their
## velocities, how many, and the average of their colours.
class Wake:
	extends RefCounted
	var position: Vector2 = Vector2.ZERO
	var momentum: Vector2 = Vector2.ZERO
	var count: int = 0
	var color: Color = Color(0, 0, 0, 0)


## Bin [param birds] into cells [param cell_size] pixels across. [param color_of]
## maps a [Bird] to the colour it paints with. Strongest wake first, so a
## caller that only wants a few can take them off the front.
static func gather(birds: Array[Bird], cell_size: float, color_of: Callable) -> Array[Wake]:
	var cells := {}
	for bird in birds:
		var key := Vector2i((bird.position / cell_size).floor())
		var wake: Wake = cells.get(key)
		if wake == null:
			wake = Wake.new()
			cells[key] = wake
		wake.position += bird.position
		wake.momentum += bird.velocity
		wake.color += color_of.call(bird)
		wake.count += 1
	var wakes: Array[Wake] = []
	for wake: Wake in cells.values():
		wake.position /= wake.count
		wake.color /= wake.count
		wakes.append(wake)
	wakes.sort_custom(
		func(a: Wake, b: Wake) -> bool: return a.momentum.length() > b.momentum.length()
	)
	return wakes
