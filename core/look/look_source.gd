class_name LookSource
extends RefCounted
## Port: somewhere a look rotation comes from.
##
## The contract mirrors [MotionSource]: one poll per frame, yielding radians to
## rotate the camera by, already scaled by whatever sensitivity the adapter
## owns. A port this narrow is what makes a fake source trivial to write.


## Radians to rotate the camera this frame, x = yaw, y = pitch. [param _delta]
## is the time since the last poll, which a rate-based adapter — a stick held
## over at an angle, say — needs to turn a deflection into an amount.
func poll(_delta: float) -> Vector2:
	return Vector2.ZERO


## Open whatever the source reads from. [LookInput] calls this when the
## source joins a mix that is in the tree. Most sources read [Input], which is
## always open; one backed by a camera must not hold it open while nothing is
## looking, so the lifecycle is part of the port rather than a side effect of
## the first poll.
func start() -> void:
	pass


## Release whatever [method start] opened. Called when the source leaves the
## mix or its [LookInput] leaves the tree.
func stop() -> void:
	pass


## Whether this source is actually producing input. Adapters should answer
## from something observed where they can, not from a platform name.
func is_available() -> bool:
	return false


## Short human-readable name, for debug overlays and logs.
func describe() -> String:
	return "none"
