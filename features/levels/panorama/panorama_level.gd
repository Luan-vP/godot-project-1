class_name PanoramaLevel
extends Node3D
## A level that is just a sphere of look-around: a [PanoramaLookCamera] at the
## centre of an equirectangular panorama, and nothing else in the 3D scene.
##
## The floaters and the fluid are screen-space overlays, added later as a
## sibling [CanvasLayer] — they live in the player's eye, travelling with the
## gaze rather than staying pinned to the background, so they do not belong in
## this scene at all.

## Equirectangular image the player looks around inside. Not baked into the
## scene, so a level can supply its own; see the level-definition work for how
## a level picks this.
@export var panorama_texture: Texture2D:
	set(value):
		panorama_texture = value
		_apply_panorama()

@onready var _world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	_apply_panorama()


func _apply_panorama() -> void:
	# The export setter can run before @onready vars resolve, e.g. while the
	# editor is populating the scene. _ready applies it again once we are
	# actually in the tree.
	if _world_environment == null:
		return
	var sky_material := _world_environment.environment.sky.sky_material as PanoramaSkyMaterial
	sky_material.panorama = panorama_texture
