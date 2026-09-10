class_name FluidField
extends RefCounted
## CPU-side mirror of the simulated velocity field.
##
## The simulation itself lives on the GPU, which gameplay code cannot read.
## This is the seam: [FluidSimulation] copies a small downsampled grid back
## every few frames, and everything that needs to know which way the water is
## going asks here instead of touching the GPU.
##
## Grid values are stored in simulation cells per second. [method sample_world]
## returns pixels per second, which is what game code actually wants.

var _width: int = 0
var _height: int = 0
var _cells: PackedVector2Array = PackedVector2Array()
var _world_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0))
var _pixels_per_cell: Vector2 = Vector2.ONE


## Allocate a [param width] x [param height] grid, zeroed.
func resize(width: int, height: int) -> void:
	_width = maxi(width, 0)
	_height = maxi(height, 0)
	_cells.resize(_width * _height)
	_cells.fill(Vector2.ZERO)


## Set the slab of world the grid covers, and what one cell of the grid the
## velocities were *measured* on is worth in pixels.
##
## Those are two different grids, which is the trap. This mirror is usually
## much coarser than the simulation that fills it, but the values in it are
## still in the simulation's cells per second — so the mirror's own spacing is
## the wrong number to convert them with.
##
## Sampling outside [param rect] clamps to the nearest edge rather than
## returning zero, so a body that drifts out of the tank still feels the
## current at the wall instead of going limp.
func configure_world(rect: Rect2, pixels_per_cell: Vector2) -> void:
	_world_rect = rect
	_pixels_per_cell = pixels_per_cell


func get_size() -> Vector2i:
	return Vector2i(_width, _height)


func get_world_rect() -> Rect2:
	return _world_rect


func is_empty() -> bool:
	return _cells.is_empty()


func clear() -> void:
	_cells.fill(Vector2.ZERO)


## Cell velocity in cells/second. Coordinates are clamped into the grid.
func get_cell_velocity(x: int, y: int) -> Vector2:
	if _cells.is_empty():
		return Vector2.ZERO
	var cx := clampi(x, 0, _width - 1)
	var cy := clampi(y, 0, _height - 1)
	return _cells[cy * _width + cx]


func set_cell_velocity(x: int, y: int, velocity: Vector2) -> void:
	if _cells.is_empty():
		return
	var cx := clampi(x, 0, _width - 1)
	var cy := clampi(y, 0, _height - 1)
	_cells[cy * _width + cx] = velocity


## Refill the grid from a readback image, taking velocity from the red and
## green channels. Resizes to match if the image dimensions changed.
func update_from_image(image: Image) -> void:
	if image == null or image.is_empty():
		return
	var width := image.get_width()
	var height := image.get_height()
	if width != _width or height != _height:
		resize(width, height)
	var index := 0
	for y in height:
		for x in width:
			var pixel := image.get_pixel(x, y)
			_cells[index] = Vector2(pixel.r, pixel.g)
			index += 1


## Bilinearly sample the grid in UV space. Returns cells/second.
func sample_uv(uv: Vector2) -> Vector2:
	if _cells.is_empty():
		return Vector2.ZERO
	var point := Vector2(
		clampf(uv.x, 0.0, 1.0) * float(_width) - 0.5, clampf(uv.y, 0.0, 1.0) * float(_height) - 0.5
	)
	var x0 := int(floorf(point.x))
	var y0 := int(floorf(point.y))
	var weight := Vector2(point.x - float(x0), point.y - float(y0))
	var upper := get_cell_velocity(x0, y0).lerp(get_cell_velocity(x0 + 1, y0), weight.x)
	var lower := get_cell_velocity(x0, y0 + 1).lerp(get_cell_velocity(x0 + 1, y0 + 1), weight.x)
	return upper.lerp(lower, weight.y)


## Current at a world position, in pixels/second. The one call most game code
## needs.
func sample_world(world_position: Vector2) -> Vector2:
	return cell_to_world_velocity(sample_uv(world_to_uv(world_position)))


func world_to_uv(world_position: Vector2) -> Vector2:
	var size := _world_rect.size
	return Vector2(
		0.0 if is_zero_approx(size.x) else (world_position.x - _world_rect.position.x) / size.x,
		0.0 if is_zero_approx(size.y) else (world_position.y - _world_rect.position.y) / size.y
	)


func uv_to_world(uv: Vector2) -> Vector2:
	return _world_rect.position + uv * _world_rect.size


## Simulation cells/second to pixels/second.
func cell_to_world_velocity(cell_velocity: Vector2) -> Vector2:
	return cell_velocity * _pixels_per_cell


## Pixels/second to simulation cells/second, for pushing impulses back in.
func world_to_cell_velocity(world_velocity: Vector2) -> Vector2:
	return Vector2(
		0.0 if is_zero_approx(_pixels_per_cell.x) else world_velocity.x / _pixels_per_cell.x,
		0.0 if is_zero_approx(_pixels_per_cell.y) else world_velocity.y / _pixels_per_cell.y
	)
