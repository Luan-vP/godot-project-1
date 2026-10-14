class_name ArtPalette
extends RefCounted
## The game art's colours: the dyes poured into the tank, the paper they wash
## over, the eyes, pins, balls, birds and spout. The counterpart of [UiTokens]
## for everything that is not text or a control, and built on it: the dyes are
## the UI's rune, sigil, ember and alert, so a part's colour on screen is the
## same colour in the menus.
##
## Change a colour here and every level follows. Nothing under features/levels
## or features/fluid sets a colour of its own except as a share of these
## (lightened, faded, mixed).

## A blue the UI does not use, to make the fifth dye.
const AZURE := Color("4f8cff")

## The five dyes, in the order parts and seeds take them: teal, rose, violet,
## amber, azure. Five, so the five-voice band and the five seed blobs each get
## one of their own.
const DYES: Array[Color] = [
	UiTokens.RUNE,
	UiTokens.ALERT,
	UiTokens.SIGIL,
	UiTokens.EMBER,
	AZURE,
]

## The same five round the colour wheel (teal, azure, violet, rose, amber), so
## [method wheel] blends between neighbours.
const WHEEL: Array[Color] = [
	UiTokens.RUNE,
	AZURE,
	UiTokens.SIGIL,
	UiTokens.ALERT,
	UiTokens.EMBER,
]

# --- The tank -------------------------------------------------------------

## The unpainted ground the fluid washes over, and where pigment piles up.
const PAPER := Color("17122e")
const DEEP := Color("05040b")
## How thick pigment darkens: red and blue survive longest, so depth reads
## violet rather than grey.
const ABSORPTION := Vector3(1.2, 1.65, 1.15)
## Floaters in the tank: void-dark motes.
const FLOATER := Color(0.06, 0.05, 0.13, 0.55)

# --- Things in it ---------------------------------------------------------

## Pale, faintly violet white: an eye's white, a cue ball, a highlight.
const MOON := Color("ece6fa")
const PUPIL := UiTokens.VOID
const EYE_RIM := UiTokens.LINE
## The spout: an obsidian body with a moonlit lip.
const SPOUT_BODY := Color("1d1736")
const SPOUT_RIM := MOON

## Billiard balls, cue ball first: moon, then the dyes and two deeper ones.
const BALLS: Array[Color] = [
	MOON,
	UiTokens.EMBER,
	AZURE,
	UiTokens.ALERT,
	UiTokens.SIGIL,
	UiTokens.RUNE,
	Color("b8406a"),
	Color("5a3fb0"),
]

## Rhythms in the birds and boatmen levels, by pulses: 3 amber, 4 teal, 6
## violet.
const RHYTHM_3 := UiTokens.EMBER
const RHYTHM_4 := UiTokens.RUNE
const RHYTHM_6 := UiTokens.SIGIL
## A bird in no flock.
const LONER := Color(MOON, 0.42)


## A colour [param t] of the way round [constant WHEEL], wrapping at 1.
static func wheel(t: float) -> Color:
	var at := fposmod(t, 1.0) * WHEEL.size()
	var from := int(at)
	return WHEEL[from].lerp(WHEEL[(from + 1) % WHEEL.size()], at - from)


## The dye for slot [param index], wrapping.
static func dye(index: int) -> Color:
	return DYES[posmod(index, DYES.size())]
