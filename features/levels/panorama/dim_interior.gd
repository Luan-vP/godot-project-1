extends PanoramaLevel
## Example level: dim interior, floaters barely there. See [method
## Level.dim_interior] for the numbers and the panorama README for why two
## examples exist.


func _ready() -> void:
	level = Level.dim_interior()
	super._ready()
