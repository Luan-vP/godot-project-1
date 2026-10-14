extends Node
## Autoload: makes [UiTheme] the look of every Control and every drawn line of
## text in the game, before the first scene is built. See [method UiTheme.install].


func _init() -> void:
	UiTheme.install()
