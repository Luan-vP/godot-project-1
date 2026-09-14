extends PanoramaLevel
## Example level: bright overcast sky, floaters unmissable. See [method
## Level.overcast_sky] for the numbers and the panorama README for why two
## examples exist.


func _ready() -> void:
	level = Level.overcast_sky()
	super._ready()
