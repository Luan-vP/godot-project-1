class_name EyeBand
extends Band
## Every eye in the tank plays one part of the arrangement, but only while it
## keeps clear of the tank walls. Drift one against a wall and its part drops
## out at the next bar; let it float free again and the part comes back.
##
## Parts go to eyes by size, biggest first: the heaviest eye carries the beat,
## the next the bass, down to the smallest carrying the lightest shimmer. So
## what is audible can be read off what is on screen.
##
## The music itself — songs, parts, key shifts — is [Band]'s; this only
## decides which parts are wanted, by overriding [method Band.wants_part].
##
## An eye near a wall uses two distances, not one, so one hovering at the
## threshold does not flicker its part on and off: it counts as touching once
## it comes within [member touch_px], and only lets go past [member release_px].

## Emitted when an eye starts or stops touching a wall.
signal contact_changed(part: String, touching: bool)

## Within this many pixels of a wall (from the eye's rim), an eye is touching.
@export var touch_px: float = 10.0

## A touching eye lets go only once it is this far from every wall.
@export var release_px: float = 40.0

var _eyes: Array[FloatyEye] = []
## Part index for each eye in [member _eyes]; -1 for an eye with no part.
var _eye_parts: Array[int] = []
var _touching: Array[bool] = []


func _ready() -> void:
	super()
	if _eyes.is_empty() and get_parent() != null:
		var found: Array[FloatyEye] = []
		for child in get_parent().get_children():
			if child is FloatyEye:
				found.append(child)
		bind_eyes(found)


## Hand the band its eyes, and give each one a part by size.
func bind_eyes(eyes: Array[FloatyEye]) -> void:
	_eyes = eyes
	var radii: Array[float] = []
	for eye in eyes:
		radii.append(eye.radius)
	_eye_parts = parts_by_size(radii, PARTS.size())
	_touching.resize(eyes.size())
	_touching.fill(false)


## The part an eye plays, or an empty string for one with none.
func part_for(eye: FloatyEye) -> String:
	var i := _eyes.find(eye)
	if i < 0 or _eye_parts[i] < 0:
		return ""
	return PARTS[_eye_parts[i]]


## Whether the eye playing [param part] is clear of the walls, which is what
## decides if the part should sound from the next bar on. A part with no eye
## never plays.
func wants_part(part: String) -> bool:
	var index := PARTS.find(part)
	for i in _eyes.size():
		if _eye_parts[i] == index:
			return not _touching[i]
	return false


func is_touching(eye: FloatyEye) -> bool:
	var i := _eyes.find(eye)
	return i >= 0 and _touching[i]


func _process(_delta: float) -> void:
	var simulation := get_tree().get_first_node_in_group(FluidSimulation.GROUP_NAME)
	if simulation != null:
		update_contacts((simulation as FluidSimulation).get_world_rect())


## Re-measure every eye against [param tank]. Every part, drum or live, only
## catches up with the result at the next bar line, in [method _latch_live_parts].
func update_contacts(tank: Rect2) -> void:
	for i in _eyes.size():
		var eye := _eyes[i]
		if not is_instance_valid(eye) or _eye_parts[i] < 0:
			continue
		var clearance := wall_clearance(eye.global_position, eye.radius, tank)
		var touching := next_touching(clearance, _touching[i], touch_px, release_px)
		if touching == _touching[i]:
			continue
		_touching[i] = touching
		var part: String = PARTS[_eye_parts[i]]
		contact_changed.emit(part, touching)


## Pixels between [param position]'s circle of [param radius] and the nearest
## wall of [param tank]. Negative once the rim pokes past it.
static func wall_clearance(position: Vector2, radius: float, tank: Rect2) -> float:
	var to_wall := minf(
		minf(position.x - tank.position.x, tank.end.x - position.x),
		minf(position.y - tank.position.y, tank.end.y - position.y)
	)
	return to_wall - radius


## Touching from here on, given the last answer: the threshold to let go sits
## further out than the one to take hold.
static func next_touching(
	clearance: float, was_touching: bool, touch: float, release: float
) -> bool:
	return clearance < (release if was_touching else touch)


## For each radius, the index into a list of [param part_count] parts, handed
## out biggest first; -1 for radii past the last part. Ties keep their order.
static func parts_by_size(radii: Array[float], part_count: int) -> Array[int]:
	var order: Array[int] = []
	for i in radii.size():
		order.append(i)
	order.sort_custom(
		func(a: int, b: int): return radii[a] > radii[b] or (radii[a] == radii[b] and a < b)
	)
	var parts: Array[int] = []
	parts.resize(radii.size())
	parts.fill(-1)
	for rank in mini(order.size(), part_count):
		parts[order[rank]] = rank
	return parts
