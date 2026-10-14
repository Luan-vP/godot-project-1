class_name UiTokens
extends RefCounted
## The menus' design tokens: every colour, size, font and timing the menu
## look is made of. Change a value here and [UiTheme] carries it to every menu,
## card, button and backdrop; nothing under features/ui hard-codes its own.
##
## The look is arcane-digital: a near-black violet void, hairline borders the
## colour of a dim screen, a teal "rune" glow for whatever is selected, and a
## violet "sigil" for ornament. Titles are set in Cinzel, an inscription face;
## everything else in Share Tech Mono, a terminal face.

# --- Colour ---------------------------------------------------------------

## The ground, top to bottom of the backdrop's gradient.
const VOID := Color("07060d")
const VOID_DEEP := Color("120d24")
## Card and panel fill, over the backdrop.
const PANEL := Color(0.075, 0.06, 0.14, 0.86)
const PANEL_HOVER := Color(0.1, 0.085, 0.2, 0.92)
const PANEL_PRESSED := Color(0.05, 0.16, 0.17, 0.95)
## Hairline borders at rest.
const LINE := Color("2c2950")
## The selected thing: focus, hover, the live part of a bar.
const RUNE := Color("5ef2d6")
## Ornament: sigils, brackets, the backdrop's rings.
const SIGIL := Color("9d7bff")
## Something about to happen that cannot be undone, like a merge; running hot.
const EMBER := Color("ffb35c")
## Gone wrong: a clip, a part about to be cut.
const ALERT := Color("ff5c7a")

const TEXT := Color("e8e4ff")
const MUTED := Color("8d89b3")
const FAINT := Color("4b4774")

## Heads-up text over a level, which has to read over bright fluid as well as
## the void, so it carries a shadow.
const HUD_TEXT := Color(0.91, 0.89, 1.0, 0.86)
const HUD_FAINT := Color(0.71, 0.69, 0.86, 0.62)
const HUD_SHADOW := Color(0.027, 0.024, 0.05, 0.7)
## The plate behind a readout drawn over a level.
const OVERLAY := Color(0.027, 0.024, 0.05, 0.62)

# --- Type -----------------------------------------------------------------

const DISPLAY_FONT_PATH := "res://features/ui/design/fonts/Cinzel-Variable.ttf"
const MONO_FONT_PATH := "res://features/ui/design/fonts/ShareTechMono-Regular.ttf"
## Symbols neither face has (arrows, notes, dots), so they never fall through
## to a system font a Deck may not have.
const SYMBOL_FONT_PATH := "res://features/ui/design/fonts/NotoSansMath-Symbols.ttf"
## Cinzel is a variable font; this is its weight axis.
const DISPLAY_WEIGHT := 600
## Extra pixels between letters, for the carved look of the titles.
const DISPLAY_TRACKING := 3
const LABEL_TRACKING := 2

const SIZE_TITLE := 46
const SIZE_HEADING := 22
const SIZE_BODY := 16
const SIZE_SMALL := 14
const SIZE_TINY := 12
const SIZE_HUD := 14
const SIZE_TOAST := 22

# --- Shape and space ------------------------------------------------------

const BORDER := 1
const BORDER_FOCUS := 2
## Small, so panels read as cut plates rather than soft cards.
const RADIUS := 2
## Inside a card, between its edge and its text.
const PAD := 18.0
## Between cards, and between rows of a page.
const GAP := 14
## Between the screen's safe area and a page's content.
const MARGIN := 48.0
const MARGIN_NARROW := 24.0
## Length of a card's corner brackets.
const BRACKET := 12.0

const CARD_HEIGHT := 100.0
const ROW_HEIGHT := 76.0
const BUTTON_HEIGHT := 56.0

# --- Motion ---------------------------------------------------------------

## Turns a minute for the backdrop's slowest ring; the others run off it.
const SIGIL_RPM := 0.6
## Seconds per sweep of the scan line down the backdrop.
const SCAN_SECONDS := 9.0
