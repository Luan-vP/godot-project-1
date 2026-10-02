extends GutTest
## Covers #115: version A's droplets — the pool, a droplet bouncing off a pin
## and playing it, and the contact maths — without a GPU tank.

var _pins: PinField
var _emitter: FluidEmitter


func before_each() -> void:
	_pins = PinField.new()
	_pins.area = Rect2(100, 300, 600, 200)
	_pins.rows = 3
	_pins.pins_per_row = 4
	add_child_autofree(_pins)
	var scale := PegScale.new()
	_pins.bind_scale(scale)
	scale.set_key(0, false)
	scale.snap()
	_emitter = FluidEmitter.new()
	add_child_autofree(_emitter)
	_emitter.pins = _pins
	_emitter.make_pool(4)


func test_contact_bounces_a_droplet_closing_on_a_pin() -> void:
	var contact := FluidEmitter.resolve_contact(
		Vector2(100, 92), Vector2(0, 300), Vector2(100, 100), 15.0
	)
	assert_false(contact.is_empty(), "Falling onto the pin's top")
	assert_almost_eq(contact["normal"], Vector2.UP, Vector2(0.001, 0.001))
	assert_lt(contact["velocity"].y, 0.0, "Bounced back up")
	assert_almost_eq(contact["velocity"].length(), 300.0 * FluidEmitter.RESTITUTION, 0.01)
	assert_almost_eq(contact["position"], Vector2(100, 85), Vector2(0.001, 0.001), "Pushed clear")


func test_a_droplet_leaving_a_pin_does_not_hit_it_again() -> void:
	var contact := FluidEmitter.resolve_contact(
		Vector2(100, 92), Vector2(0, -300), Vector2(100, 100), 15.0
	)
	assert_true(contact.is_empty())


func test_strength_follows_closing_speed() -> void:
	var soft := FluidEmitter.resolve_contact(
		Vector2(100, 92), Vector2(0, 60), Vector2(100, 100), 15.0
	)
	var hard := FluidEmitter.resolve_contact(
		Vector2(100, 92), Vector2(0, 900), Vector2(100, 100), 15.0
	)
	assert_lt(soft["strength"], hard["strength"])
	assert_eq(hard["strength"], 1.0, "Capped")
	assert_gte(soft["strength"], 0.15, "Never silent")


func test_the_pool_recycles_the_oldest_when_spent() -> void:
	var first := _emitter.spawn_droplet(Vector2.ZERO, Vector2.ZERO, Color.RED)
	first.age = 5.0
	for i in 3:
		_emitter.spawn_droplet(Vector2.ZERO, Vector2.ZERO, Color.RED)
	assert_eq(_emitter.active_count(), 4, "Pool full")
	var fifth := _emitter.spawn_droplet(Vector2.ZERO, Vector2.ZERO, Color.RED)
	assert_eq(fifth, first, "The oldest is recycled")
	assert_eq(_emitter.active_count(), 4)


func test_a_droplet_striking_a_pin_plays_it() -> void:
	watch_signals(_pins)
	var pin_at := _pins.to_global(_pins.pin_position(3))
	_emitter.spawn_droplet(pin_at + Vector2(0, -8), Vector2(0, 320), Color.RED)
	_emitter.collide_droplets()
	assert_signal_emitted(_pins, "pin_hit")
	assert_eq(_emitter.hit_count(), 1)


func test_droplets_below_the_field_are_retired() -> void:
	_emitter.spawn_droplet(Vector2(300, 900), Vector2(0, 100), Color.RED)
	_emitter.collide_droplets()
	assert_eq(_emitter.active_count(), 0)


func test_stream_colour_drifts_through_the_palette() -> void:
	assert_eq(FluidEmitter.stream_color(0.0), FluidEmitter.PALETTE[0])
	var halfway := FluidEmitter.stream_color(FluidEmitter.PALETTE_SECONDS * 0.5)
	assert_ne(halfway, FluidEmitter.PALETTE[0], "Moving on")
	assert_ne(halfway, FluidEmitter.PALETTE[1], "Not there yet")


func test_version_a_scene_loads() -> void:
	var level: SpoutLevel = (
		load("res://features/levels/spout/a_fluid/level_three_a.tscn").instantiate()
	)
	add_child_autofree(level)
	assert_true(level.emitter is FluidEmitter)
	assert_true(level.pins.on_dark, "Light labels over the dark tank")
	AudioManager.set_tempo(120.0, 4)
