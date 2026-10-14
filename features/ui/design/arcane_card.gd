class_name ArcaneCard
extends Control
## A card's ornament, and the one way menus make a card.
##
## [method make] returns a plain [Button] in the [constant UiTheme.CARD] role
## carrying a name, a line of description and an index, with one of these
## drawn over it: corner brackets in the sigil colour that turn rune-bright,
## and a lit edge, while the card is hovered or focused.

const GLOW_WIDTH := 3.0


## A card [Button] named [param node_name], showing [param title] over
## [param blurb] with [param index] in its corner. Wire its
## [signal BaseButton.pressed] yourself.
static func make(
	node_name: String,
	title: String,
	blurb: String,
	index: String,
	height: float = UiTokens.CARD_HEIGHT
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.theme_type_variation = UiTheme.CARD
	button.custom_minimum_size = Vector2(0.0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.name = "Text"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(UiTokens.PAD))
	margin.add_theme_constant_override("margin_right", int(UiTokens.PAD))
	button.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(head)
	var name_label := UiTheme.label(title, UiTheme.CARD_TITLE)
	name_label.name = "Title"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	if not index.is_empty():
		var index_label := UiTheme.label(index, UiTheme.CARD_INDEX)
		index_label.name = "Index"
		head.add_child(index_label)

	if not blurb.is_empty():
		var blurb_label := UiTheme.label(blurb, UiTheme.CARD_BLURB)
		blurb_label.name = "Blurb"
		blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(blurb_label)

	var ornament := ArcaneCard.new()
	ornament.name = "Ornament"
	button.add_child(ornament)
	return button


## [param number] as a card index: two hex digits, the way a register reads.
static func index_for(number: int) -> String:
	return "0x%02X" % number


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := get_parent() as BaseButton
	if card == null:
		return
	for change in [
		card.focus_entered,
		card.focus_exited,
		card.mouse_entered,
		card.mouse_exited,
		card.button_down,
		card.button_up,
	]:
		change.connect(queue_redraw)


func _draw() -> void:
	var card := get_parent() as BaseButton
	var lit := card != null and (card.has_focus() or card.is_hovered())
	var colour := UiTokens.RUNE if lit else Color(UiTokens.SIGIL, 0.45)
	var arm := UiTokens.BRACKET
	var inset := 3.0
	var corners := [
		[Vector2(inset, inset), Vector2(1, 0), Vector2(0, 1)],
		[Vector2(size.x - inset, inset), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(inset, size.y - inset), Vector2(1, 0), Vector2(0, -1)],
		[Vector2(size.x - inset, size.y - inset), Vector2(-1, 0), Vector2(0, -1)],
	]
	for corner in corners:
		var at: Vector2 = corner[0]
		draw_line(at, at + corner[1] * arm, colour, 1.0)
		draw_line(at, at + corner[2] * arm, colour, 1.0)
	if lit:
		var edge := Rect2(0.0, size.y * 0.2, GLOW_WIDTH, size.y * 0.6)
		draw_rect(edge, UiTokens.RUNE)
		draw_rect(edge.grow_individual(0, 0, 6.0, 0), Color(UiTokens.RUNE, 0.15))
