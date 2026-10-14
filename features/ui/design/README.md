# Design system

One place decides how every menu, HUD and readout looks. The look is arcane-digital: a
near-black violet void, hairline plates the colour of a dim screen, a teal
"rune" glow on whatever is selected, violet "sigil" ornament, and titles cut in
an inscription face over a terminal face for everything else.

| File | What it is |
| --- | --- |
| `ui_tokens.gd` (`UiTokens`) | Every colour, font, size, spacing and timing. **Change the look here.** |
| `ui_theme.gd` (`UiTheme`) | Builds the one shared `Theme` from the tokens, names the roles in it, and makes headers, labels and rules in those roles. |
| `arcane_card.gd` (`ArcaneCard`) | The one way to make a card: a `Button` with a name, a blurb, an index and corner brackets that light with focus. |
| `arcane_backdrop.gd` (`ArcaneBackdrop`) | The drawn ground: gradient, lattice, a turning sigil, a scan line. |
| `art_palette.gd` (`ArtPalette`) | The game art's colours: the five dyes, the tank's paper and depth, moon-white, eyes, pins, balls, rhythms, spout. Built on `UiTokens`, so a part's colour in the tank is the same colour in the menus. **Change the art here.** |
| `ui_look.gd` | The `UiLook` autoload: calls `UiTheme.install()` before the first scene. |
| `fonts/` | Cinzel (titles), Share Tech Mono (everything else) and a symbol subset of Noto Sans Math (arrows, notes, dots), all under the SIL Open Font License; the licences sit beside them. |

## Installed everywhere

`UiTheme.install()` folds the theme into Godot's default theme and makes the
terminal face the fallback font. So every Control in the game has the look
with no code of its own — under a `CanvasLayer` too, where a parent's theme
does not reach — and level text drawn with `draw_string` uses
`UiTheme.hud_font()`.

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
| `HUD`, `HUD_FAINT` | Label | Text over a level, shadowed to read over bright fluid. |
| `TOAST` | Label | A large passing readout, like the tempo after a nudge. |
| `HUD_PANEL` | PanelContainer | The plate behind a readout over a level. |

HUD colours drawn by hand (rings, dials, meters) come from `UiTokens` too:
`HUD_TEXT`, `RUNE` for live, `EMBER` for hot, `ALERT` for wrong, `OVERLAY`
for plates. Game art — eyes, parts, pins, fluid — takes its colours from
`ArtPalette` instead; `test_art_palette.gd` checks the art scripts spell out
no colours of their own.

## Rules

- Menus set no colours, fonts or font sizes of their own; `test_ui_theme.gd`
  checks the menu scripts for `Color(` and theme overrides, and the HUD
  scripts for overrides and `ThemeDB.fallback_font`. Layout (margins,
  separations, minimum sizes) is fine, using `UiTokens` sizes where one fits.
- To add a role, add its name to `UiTheme`, give it a look in `_build`, and
  add it to the table above.

## Fonts and glyphs

Neither face has symbols, and a Deck may have no system font to fall back
on, so both fall back to the bundled symbol subset: `♩ ♪ ← → ↑ ↓ ● ○ ◐ ▸ ±`
and the rest of the arrow, maths, geometric-shape and miscellaneous-symbol
blocks. A symbol outside those still needs adding to the subset (see the
`pyftsubset` line in the PR that added it). Ornament is drawn (`ArcaneCard`,
`rule()`, `diamond()`) rather than typed.
