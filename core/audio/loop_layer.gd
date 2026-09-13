class_name LoopLayer
extends Resource
## Data describing one layer of a synchronised loop stack: a name to address
## it by, the stream it plays, and the volume it plays at when active.
##
## Deliberately just data. What the loop stream actually is — a shipped file,
## or a procedurally generated buffer if #28 lands on procedural audio — is
## none of this resource's or [AudioManager]'s concern; only [member stream]
## matters, not where it came from. A set of these is assigned to
## [method AudioManager.configure_loop_layers] rather than paths being
## hardcoded into a script.

## Name callers use to address this layer, e.g. via
## [method AudioManager.set_layer_active]. Must be unique within a set of
## layers configured together.
@export var layer_name: String = ""

## The loop's audio stream. Expected to already be set up to loop (e.g.
## [member AudioStreamWAV.loop_mode]) and to be the same length, or a clean
## divisor/multiple of the same length, as the other layers it plays with —
## staying in sync depends on the streams themselves lining up.
@export var stream: AudioStream

## Volume this layer plays at once active, in decibels.
@export var volume_db: float = 0.0
