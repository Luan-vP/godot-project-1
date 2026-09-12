class_name FloaterDepth
extends Resource
## One depth band of a [FloaterField]: how many floaters sit at it, and how far
## out of focus they are.
##
## Real floaters are shadows cast onto the retina from slightly different
## distances in front of it, so each one is blurred by a different amount. A
## handful of bands is enough to read as depth; each band is drawn into its
## own layer and shown through a bokeh blur, so this is the whole description
## of a band — there is nothing else to configure per depth.

## Relative share of the population in this band. Normalised against the
## other bands, so these need not sum to 1.
@export_range(0.0, 1.0, 0.01) var share: float = 1.0

## Radius of the bokeh disc, in pixels. Below about a pixel the band is drawn
## sharp.
@export_range(0.0, 64.0, 0.1) var blur_px: float = 0.0

## Coverage multiplier after blurring. Spreading a one-pixel speck over a
## ten-pixel disc leaves almost nothing of it; this puts some back. Too high and
## the blurred shape clips into a flat, opaque slab.
@export_range(0.1, 16.0, 0.1) var gain: float = 1.0

## Size multiplier for floaters in this band. Defocus spreads a shadow wider,
## so nearer, blurrier bands read larger.
@export_range(0.1, 4.0, 0.05) var magnify: float = 1.0

## Opacity multiplier. A shadow spread over a wider disc is fainter.
@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0


static func make(
	band_share: float, blur: float, coverage_gain: float, size: float, alpha: float
) -> FloaterDepth:
	var depth := FloaterDepth.new()
	depth.share = band_share
	depth.blur_px = blur
	depth.gain = coverage_gain
	depth.magnify = size
	depth.opacity = alpha
	return depth


## Far, middle and near bands tuned against a pale background: a nearly sharp
## back layer, a soft middle, and a ghostly near layer that is mostly smear.
static func vitreous_bands() -> Array[FloaterDepth]:
	return [
		make(0.35, 1.5, 1.2, 1.0, 1.0),
		make(0.40, 5.0, 2.0, 1.3, 0.8),
		make(0.25, 14.0, 2.2, 1.8, 0.6),
	]
