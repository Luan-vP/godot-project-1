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

  play       The level select every player sees (run/main_scene): pick a
             level, Backspace comes back. Press Shift to reveal the secret
             eye tank.
  menu       Click into any of the demos below; Backspace comes back.
  level1     Level 1: pure exploration. No score, no timer, no way to fail —
             just look. Mouse or right stick to look, Esc frees the cursor.
  eyes       Secret level: the eye tank. Drag to stir and paint, WASD tilts,
             Space jogs, B blinks, R empties the tank, C recalibrates.
  band       The eye tank as a band: each eye plays one part of a 70 bpm loop
             while it floats clear of the walls. WASD tilts, drag stirs.
  spout-a    Level 3, version A: the spout pours the eye tank's fluid over
             the pins; droplets riding it play the notes they strike. Stick
             or A/D aims, Q/E and Z/X move the key, Enter or Y swaps scale;
             touch aims, top-right buttons move key/scale.
  spout-b    Level 3, version B: RT fires billiard-like balls at the pins,
             faster the harder it is pressed, with a haptic tick per ball.
             Space or a click fires at full rate, 1-5 at fixed depths. Stick
             or A/D aims, Q/E move the key, Enter or Y swaps scale;
             touch aims, top-right buttons move key/scale.
  spout      Level 3's common shell: a spout over a field of pins, the eye
             band playing behind. Stick or A/D aims, Space plucks the pin
             aimed at, Q/E and Z/X move the key, Enter or Y swaps scale;
             touch aims, top-right buttons move key/scale.
  birds      Flocks of birds singing 3-against-4. B is a snare: tap a rhythm
             to favour its flocks; hold it and the others scatter.
  vitreous   Out-of-focus floaters drifting in a coasting gel. Drag to push,
             WASD tilts, Space jogs, +/- floaters, F toggles focus, B dark
             background, R stills.
  overcast   Panorama level: bright overcast sky, floaters unmissable. Mouse
             or right stick to look, Esc frees the cursor, click to recapture.
  interior   Panorama level: dim interior, floaters barely there. Same
             controls as overcast.
  gaze       Floaters swished by looking around. Mouse or right stick to look,
             1/2 and 3/4 tune hold and flick sensitivity, R stills, F focus.
  refraction Clear medium over a checkerboard: only the bend shows. Drag to
             stir, +/- tune strength down to zero, R stills.
  canny      CannyEdgeSource's debug overlay: traced edges over a synthetic
             panorama. Up/Down tunes blur, [/] and +/- tune thresholds,
             Left/Right tunes minimum run length.
  eye-gaze   Eye tracking debug: tracking state, raw gaze, the gaze point and
             the turn it makes. Calibrate, then look. Without the device
             plugin the pointer stands in: C calibrates, Space blinks, F hides
             the face, M switches backend.
  synth      Synth voices. A-K hold notes, Up/Down glide, 1/2/3 waveform,
             R plays a phrase, Space holds a high note.
  groove     Floaty synthwave loop at 70 bpm: rendered drums plus live bass and
             pads on the step grid. Space plays, 1/2 drum layers, B bass, P pads.
  audio      Audio foundation: bus sliders and mutes, loop layers, the
             smoothed effect fader.
  motion     Device tilt readout: the live source, its raw gravity, and the
             scene leaning with it. Tilt a Deck or a phone, or arrows on a
             desktop; C or the right stick click recentres.
  comfort    Comfort options (#17): distortion strength, look sensitivity,
             floater overshoot reduction. Open a panorama level afterwards to
             feel a change take effect.
  arrangement Scoring drives the layer stack (#34): drums join in stages as a
             soft pad bed. +/- simulated floaters, C toggles clustered vs
             scattered scoring.
  contacts   Scoring contact sound. 1-6 hold a simulated floater's contact,
             Space fires a flickering burst.
  prs        Open pull requests on GitHub. Picking one builds and swaps to it
             only on the Deck (scripts/deck-demo.sh); elsewhere it just lists.

Everywhere: Up/Down nudge the tempo 2 bpm, Left/Right 10 bpm (d-pad on a pad).

Options:
  --fresh    Delete compiled compute shaders and reimport before running.
  -h, --help Show this help.
USAGE
}

# Keep in step with DemoMenu.DEMOS in features/ui/demo_menu/demo_menu.gd.
scene_for() {
	case "$1" in
		play | menu | levels) echo "res://features/ui/demo_menu/demo_menu.tscn" ;;
		level1 | level-one) echo "res://features/levels/panorama/level_one.tscn" ;;
		eyes | secret-eyes | fluid) echo "res://features/levels/secret_eyes/fluid_demo.tscn" ;;
		band | eye-band) echo "res://features/levels/secret_eyes/eye_band_demo.tscn" ;;
		spout-a | level3a) echo "res://features/levels/spout/a_fluid/level_three_a.tscn" ;;
		spout-b | level3b) echo "res://features/levels/spout/b_balls/level_three_b.tscn" ;;
		spout | level3) echo "res://features/levels/spout/spout_level.tscn" ;;
		birds | boids) echo "res://features/levels/boids/boids_level.tscn" ;;
		vitreous | floaters) echo "res://features/levels/vitreous/vitreous_tank.tscn" ;;
		gaze) echo "res://features/levels/gaze/gaze_demo.tscn" ;;
		refraction) echo "res://features/fluid/refraction_demo.tscn" ;;
		canny | edges) echo "res://features/edges/canny_edge_debug.tscn" ;;
		eye-gaze | eye-tracking) echo "res://core/look/gaze/gaze_debug_demo.tscn" ;;
		synth) echo "res://core/audio/synth_demo.tscn" ;;
		groove) echo "res://core/audio/groove_demo.tscn" ;;
		audio) echo "res://core/audio/audio_demo.tscn" ;;
		motion | tilt) echo "res://core/motion/motion_demo.tscn" ;;
		comfort) echo "res://features/ui/comfort_settings/comfort_settings_demo.tscn" ;;
		arrangement) echo "res://core/audio/arrangement_demo.tscn" ;;
		contacts) echo "res://features/scoring_sound/contact_sound_demo.tscn" ;;
		prs | pulls) echo "res://features/ui/pr_picker/pr_picker.tscn" ;;
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
