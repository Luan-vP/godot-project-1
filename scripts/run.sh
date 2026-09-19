#!/usr/bin/env bash
# Run a level or demo straight from the command line.
#
#   scripts/run.sh                 list what can be run
#   scripts/run.sh vitreous        run the vitreous tank
#   scripts/run.sh eyes --fresh    clear compiled shaders first, then run
#   scripts/run.sh synth -- --resolution 1280x720
#                                  anything after -- is passed to Godot
#
# Godot is found from $GODOT, then godot4 / godot on PATH, then the usual
# macOS app locations. The project is imported on first run, and compute
# shaders are recompiled automatically when the shared fluid parameter block
# has changed since they were built (Godot does not notice that on its own).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMPORTED="$ROOT/.godot/imported"
SHADER_DIR="$ROOT/features/fluid/shaders/compute"
EXPECTED_GODOT="4.4"

usage() {
	cat <<'USAGE'
Usage: scripts/run.sh <name> [--fresh] [-- <godot args>]

  menu       Click into any of the demos below; Backspace comes back.
  eyes       Secret level: the eye tank. Drag to stir and paint, WASD tilts,
             Space jogs, B blinks, R empties the tank, C recalibrates.
  band       The eye tank as a band: each eye plays one part of a 70 bpm loop
             while it floats clear of the walls. WASD tilts, drag stirs,
             arrows nudge the tempo (Up/Down ±2 bpm, Left/Right ±10 bpm).
  vitreous   Out-of-focus floaters drifting in a coasting gel. Drag to push,
             WASD tilts, Space jogs, +/- floaters, F toggles focus, R stills.
  overcast   Panorama level: bright overcast sky, floaters unmissable. Mouse
             or right stick to look, Esc frees the cursor, click to recapture.
  interior   Panorama level: dim interior, floaters barely there. Same
             controls as overcast.
  refraction Clear medium over a checkerboard: only the bend shows. Drag to
             stir, +/- tune strength down to zero, R stills.
  synth      Synth voices. A-K hold notes, Up/Down glide, 1/2/3 waveform,
             R plays a phrase, Space holds a high note.
  groove     Floaty synthwave loop at 70 bpm: rendered drums plus live bass and
             pads on the step grid. Space plays, 1/2 drum layers, B bass, P pads.
  audio      Audio foundation: bus sliders and mutes, loop layers, the
             smoothed effect fader.
  comfort    Comfort options (#17): distortion strength, look sensitivity,
             floater overshoot reduction. Open a panorama level afterwards to
             feel a change take effect.

Options:
  --fresh    Delete compiled compute shaders and reimport before running.
  -h, --help Show this help.
USAGE
}

# Keep in step with DemoMenu.DEMOS in features/ui/demo_menu/demo_menu.gd.
scene_for() {
	case "$1" in
		menu) echo "res://features/ui/demo_menu/demo_menu.tscn" ;;
		eyes | secret-eyes | fluid) echo "res://features/levels/secret_eyes/fluid_demo.tscn" ;;
		band | eye-band) echo "res://features/levels/secret_eyes/eye_band_demo.tscn" ;;
		vitreous | floaters) echo "res://features/levels/vitreous/vitreous_tank.tscn" ;;
		overcast | panorama) echo "res://features/levels/panorama/overcast_sky.tscn" ;;
		interior) echo "res://features/levels/panorama/dim_interior.tscn" ;;
		refraction) echo "res://features/fluid/refraction_demo.tscn" ;;
		synth) echo "res://core/audio/synth_demo.tscn" ;;
		groove) echo "res://core/audio/groove_demo.tscn" ;;
		audio) echo "res://core/audio/audio_demo.tscn" ;;
		comfort) echo "res://features/ui/comfort_settings/comfort_settings_demo.tscn" ;;
		*) return 1 ;;
	esac
}

find_godot() {
	if [ -n "${GODOT:-}" ]; then
		if [ ! -x "$GODOT" ]; then
			echo "GODOT is set to '$GODOT', which is not an executable file." >&2
			return 1
		fi
		echo "$GODOT"
		return
	fi
	local candidate
	for candidate in godot4 godot; do
		if command -v "$candidate" >/dev/null 2>&1; then
			command -v "$candidate"
			return
		fi
	done
	for candidate in \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
		if [ -x "$candidate" ]; then
			echo "$candidate"
			return
		fi
	done
	return 1
}

count_compiled_shaders() {
	ls "$IMPORTED" 2>/dev/null | grep -c '\.glsl-.*\.res$' || true
}

count_shader_sources() {
	ls "$SHADER_DIR"/*.glsl 2>/dev/null | wc -l | tr -d ' '
}

# True when a compute shader or the parameter block they all #include is newer
# than the oldest compiled shader. Godot keys reimport on each .glsl file's own
# content, so an edit to the shared include leaves every pass compiled against
# the old layout and the fluid silently stops moving.
shaders_are_stale() {
	local oldest
	oldest="$(ls -tr "$IMPORTED"/*.glsl-*.res 2>/dev/null | head -n 1)"
	[ -z "$oldest" ] && return 0
	local source
	for source in "$SHADER_DIR"/*.glsl "$SHADER_DIR"/*.glslinc; do
		[ "$source" -nt "$oldest" ] && return 0
	done
	return 1
}

clear_compiled_shaders() {
	rm -f "$IMPORTED"/*.glsl-*
}

import_project() {
	echo "Importing the project (compiling compute shaders needs a window, not --headless)..."
	# Import exits non-zero on harmless warnings, so judge it by what it produced.
	"$GODOT_BIN" --path "$ROOT" --import >/dev/null 2>&1 || true
	local compiled expected
	compiled="$(count_compiled_shaders)"
	expected="$(count_shader_sources)"
	if [ "$compiled" -lt "$expected" ]; then
		echo "Import compiled $compiled of $expected compute shaders; the fluid will not run." >&2
		echo "Run '$GODOT_BIN --path $ROOT --import' to see why." >&2
		exit 1
	fi
}

name=""
fresh=0
godot_args=()
while [ $# -gt 0 ]; do
	case "$1" in
		-h | --help) usage; exit 0 ;;
		--fresh) fresh=1 ;;
		--) shift; godot_args=("$@"); break ;;
		-*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
		*)
			if [ -n "$name" ]; then
				echo "Only one level at a time: got '$name' and '$1'." >&2
				exit 2
			fi
			name="$1"
			;;
	esac
	shift
done

if [ -z "$name" ]; then
	usage
	exit 0
fi

if ! scene="$(scene_for "$name")"; then
	echo "Unknown level '$name'." >&2
	usage >&2
	exit 2
fi

if ! GODOT_BIN="$(find_godot)"; then
	echo "Godot not found. Install Godot $EXPECTED_GODOT, or point GODOT at the binary:" >&2
	echo "  GODOT=/path/to/Godot scripts/run.sh $name" >&2
	exit 1
fi

version="$("$GODOT_BIN" --version 2>/dev/null | head -n 1 || true)"
case "$version" in
	"$EXPECTED_GODOT"*) ;;
	*) echo "Warning: this project targets Godot $EXPECTED_GODOT, found '${version:-unknown}'." >&2 ;;
esac

if [ "$fresh" -eq 1 ]; then
	echo "Clearing compiled compute shaders."
	clear_compiled_shaders
elif [ -d "$IMPORTED" ] && shaders_are_stale; then
	echo "Compute shaders are older than their sources; recompiling."
	clear_compiled_shaders
fi

if [ ! -f "$ROOT/.godot/global_script_class_cache.cfg" ] \
	|| [ "$(count_compiled_shaders)" -lt "$(count_shader_sources)" ]; then
	import_project
fi

echo "Running $name ($scene) with $GODOT_BIN"
exec "$GODOT_BIN" --path "$ROOT" "$scene" ${godot_args[@]+"${godot_args[@]}"}
