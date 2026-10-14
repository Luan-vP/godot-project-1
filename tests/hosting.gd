extends RefCounted
## Hosts a level the way the game does: under a [SharedLayers], which every
## level needs for its tank and its band. Not a test file itself (no test_
## prefix); test files preload it.


## Put [param level] on the stage of a fresh [SharedLayers] owned by [param
## test], which frees it after the test. Returns the host.
static func host(test: GutTest, level: Node) -> SharedLayers:
	var shared := SharedLayers.new()
	test.add_child_autofree(shared)
	shared.stage.add_child(level)
	return shared
