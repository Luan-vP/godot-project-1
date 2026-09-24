extends PanoramaLevel
## Level 1: pure exploration. See [method Level.pure_exploration] for the
## numbers and issue #22 for why — the mechanic taught with nothing to do but
## use it: no score, no timer, no end condition. Leaving is via the menu.


func _ready() -> void:
	level = Level.pure_exploration()
	super._ready()
