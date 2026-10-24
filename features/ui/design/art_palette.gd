class_name ArtPalette
extends RefCounted
## The game art's colours: the dyes poured into the tank, the paper they wash
## over, the eyes, pins, balls, birds and spout. The counterpart of [UiTokens]
## for everything that is not text or a control.
##
## The look is the tank's original one: a slate-blue paper that a thin wash
## lightens rather than darkens, five soft pigments (teal, coral, violet,
## gold, blue), ivory eyes and balls, white highlights. It stands apart from
## [UiTokens] on purpose, so the menus can be restyled without touching the
## water, and the water without touching the menus.
##
## Change a colour here and every level follows. Nothing under features/levels
## or features/fluid sets a colour of its own except as a share of these
## (lightened, faded, mixed).

## The five dyes, in the order parts and seeds take them. Five, so the
## five-voice band and the five seed blobs each get one of their own.
const DYES: Array[Color] = [
	Color(0.36, 0.70, 0.68),
	Color(0.85, 0.45, 0.38),
	Color(0.53, 0.44, 0.76),
	Color(0.93, 0.74, 0.36),
	Color(0.30, 0.55, 0.80),
]

# --- The tank -------------------------------------------------------------

## The unpainted ground the fluid washes over, and where pigment piles up.
const PAPER := Color(0.129, 0.156, 0.219)
const DEEP := Color(0.043, 0.055, 0.098)
## How thick pigment darkens: blue survives longest, so depth reads cool.
const ABSORPTION := Vector3(1.15, 1.45, 1.75)
## Floaters in the tank: soft dark motes.
const FLOATER := Color(0.13, 0.14, 0.17, 0.5)
## What the tilt and bodies paint with when nothing else says.
const MOTION_WASH := Color(0.62, 0.70, 0.88)
const BODY_PAINT := Color(0.42, 0.68, 0.66)

# --- Things in it ---------------------------------------------------------

## Pure white: highlights, glows, the flash of a struck pin.
const LIGHT := Color.WHITE
## A warm white for a whole-screen flash, softer than [constant LIGHT].
const FLASH := Color(1.0, 0.96, 0.9)
## The pale sky an eye's own colour is lifted towards as it paints the water.
const WASH := Color(0.9, 0.95, 1.0)

const SCLERA := Color(0.937, 0.918, 0.859)
const PUPIL := Color(0.078, 0.086, 0.129)
const EYE_RIM := Color(0.235, 0.243, 0.353)

## Billiard balls, ivory cue ball first.
const BALLS: Array[Color] = [
	Color(0.94, 0.91, 0.82),
	Color(0.89, 0.72, 0.26),
	Color(0.27, 0.42, 0.72),
	Color(0.78, 0.3, 0.26),
	Color(0.45, 0.32, 0.55),
	Color(0.88, 0.5, 0.25),
	Color(0.3, 0.55, 0.38),
	Color(0.5, 0.25, 0.22),
]
## A ball's shadow on the water.
const SHADOW := Color.BLACK
## A droplet before the stream gives it a colour.
const DROPLET := Color(0.3, 0.45, 0.7)

## Pins: a hue per pitch class, at this saturation, darkened as they dim.
const PIN_SATURATION := 0.55
## A pin with no note yet.
const PIN_BLANK := Color(0.8, 0.8, 0.8)

## Rhythms in the birds and boatmen levels, by pulses: 3 orange, 4 sky, 6
## lilac.
const RHYTHM_3 := Color(0.98, 0.62, 0.36)
const RHYTHM_4 := Color(0.42, 0.78, 0.96)
const RHYTHM_6 := Color(0.80, 0.56, 0.96)
## A bird in no flock.
const LONER := Color(0.86, 0.87, 0.93, 0.42)


## The dye for slot [param index], wrapping.
static func dye(index: int) -> Color:
	return DYES[posmod(index, DYES.size())]


## A pin's colour for pitch class [param pitch_class] (0 = C) at
## [param brightness] (0 to 1): its hue round the wheel, nudged off red.
static func pin(pitch_class: int, brightness: float = 1.0) -> Color:
	var hue := fposmod(posmod(pitch_class, 12) / 12.0 + 0.02, 1.0)
	return Color.from_hsv(hue, PIN_SATURATION, clampf(0.45 + 0.4 * brightness, 0.0, 1.0))
