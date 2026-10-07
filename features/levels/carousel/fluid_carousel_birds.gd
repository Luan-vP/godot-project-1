extends "res://features/levels/carousel/fluid_carousel.gd"
## The fluid carousel with the original flying birds in place of the
## waterboatmen: the eye band, spout A and the birds.
##
## Only the list of levels differs. It is set in [method Object._init], before
## the base's [method Node._ready] reads it, and can still be swapped after
## construction as with the base.

const BIRD_LEVELS: Array[String] = [
	"res://features/levels/secret_eyes/eye_band_demo.tscn",
	"res://features/levels/spout/a_fluid/level_three_a.tscn",
	"res://features/levels/boids/birds_level.tscn",
]


func _init() -> void:
	level_paths = BIRD_LEVELS.duplicate()
