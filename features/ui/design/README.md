# Menu design system

One place decides how every menu looks. The look is arcane-digital: a
near-black violet void, hairline plates the colour of a dim screen, a teal
"rune" glow on whatever is selected, violet "sigil" ornament, and titles cut in
an inscription face over a terminal face for everything else.

| File | What it is |
| --- | --- |
| `ui_tokens.gd` (`UiTokens`) | Every colour, font, size, spacing and timing. **Change the look here.** |
| `ui_theme.gd` (`UiTheme`) | Builds the one shared `Theme` from the tokens, names the roles in it, and makes headers, labels and rules in those roles. |
| `arcane_card.gd` (`ArcaneCard`) | The one way to make a card: a `Button` with a name, a blurb, an index and corner brackets that light with focus. |
| `arcane_backdrop.gd` (`ArcaneBackdrop`) | The drawn ground: gradient, lattice, a turning sigil, a scan line. |
| `fonts/` | Cinzel (titles) and Share Tech Mono (everything else), both under the SIL Open Font License; the licences sit beside them. |

## Using it in a menu

```gdscript
func _ready() -> void:
	UiTheme.apply(self)                     # the theme, for everything below
	add_child(ArcaneBackdrop.new())         # the ground
	column.add_child(UiTheme.header("KICKER", "Title", "A line of help."))
	column.add_child(UiTheme.label("Ready.", UiTheme.STATUS))
	var card := ArcaneCard.make("Synth", "Synth", "Voices.", ArcaneCard.index_for(9))
	card.pressed.connect(_open_synth)
```

Plain `Button`, `HSlider`, `ProgressBar`, `ScrollContainer`, `PanelContainer`
and tooltips are styled by type, so they need nothing. A Label or Button in a
particular role sets `theme_type_variation` to one of `UiTheme`'s names:

| Role | Base | Use |
| --- | --- | --- |
| `TITLE` | Label | A page's name: inscription face, faint rune glow. |
| `KICKER` | Label | The small tracked line above a title. |
| `HINT` | Label | Instructions and secondary lines. |
| `STATUS` | Label | A line that changes as things happen. |
| `LOG` | Label | Monospaced output, like a build log. |
| `CARD_TITLE`, `CARD_BLURB`, `CARD_INDEX` | Label | The three lines of a card. |
| `CARD` | Button | A card in a list or grid. |
| `GHOST` | Button | A button that sits back: text only, lit on hover. |
| `HOLD_BAR` | ProgressBar | A hold that will do something irreversible (ember). |

## Rules

- Menus set no colours, fonts or font sizes of their own; `test_ui_theme.gd`
  checks the menu scripts for `Color(` and theme overrides. Layout (margins,
  separations, minimum sizes) is fine, using `UiTokens` sizes where one fits.
- A `CanvasLayer` is not a `Control`, so the theme does not reach through
  one: call `UiTheme.apply` on the first Control under it (the demo menu's
  corner button does).
- A menu opened as its own scene (the picker, comfort) is not under the demo
  menu, so it applies the theme itself.
- To add a role, add its name to `UiTheme`, give it a look in `_build`, and
  add it to the table above.

## Fonts and glyphs

Neither face has geometric symbols (◆, ▸, ⌫ ...), and a Deck may have no
system font to fall back on, so ornament is drawn (`ArcaneCard`, `rule()`,
`diamond()`), never typed. Their punctuation covers `· ‹ › — … #`.
