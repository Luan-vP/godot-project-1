#!/usr/bin/env bash
# Build the EyeGaze iOS plugin into ios/plugins/eye_gaze/.
#
#   native/ios/eye_gaze/build.sh            build if sources are newer
#   native/ios/eye_gaze/build.sh --force    rebuild regardless
#
# A .gdip plugin is a static library linked into the Godot iOS template at
# Xcode time, so it compiles against the engine's own headers and must match
# the engine version exactly (4.4-stable). Those headers come from a shallow
# clone of Godot kept outside the repo ($GODOT_SOURCE, default
# ~/Library/Caches/godot-project-1/godot-4.4-stable), with the handful of
# generated headers produced by a short, interrupted SCons run. That is a
# one-off few minutes; afterwards a build is seconds.
#
# The .a outputs are gitignored: they are build products, rebuilt by this
# script (scripts/build-ios.sh calls it before exporting).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC="$ROOT/native/ios/eye_gaze"
OUT="$ROOT/ios/plugins/eye_gaze"
GODOT_TAG="4.4-stable"
GODOT_SOURCE="${GODOT_SOURCE:-$HOME/Library/Caches/godot-project-1/godot-$GODOT_TAG}"
MIN_IOS="14.1"

force=0
[ "${1:-}" = "--force" ] && force=1

up_to_date() {
	local lib
	for lib in "$OUT/eye_gaze.debug.a" "$OUT/eye_gaze.release.a"; do
		[ -f "$lib" ] || return 1
		for source in "$SRC"/*.mm "$SRC"/*.h "$SRC/build.sh"; do
			[ "$source" -nt "$lib" ] && return 1
		done
	done
	return 0
}

if [ "$force" -eq 0 ] && up_to_date; then
	echo "EyeGaze iOS plugin is up to date."
	exit 0
fi

if [ ! -f "$GODOT_SOURCE/core/object/object.h" ]; then
	echo "Fetching Godot $GODOT_TAG headers into $GODOT_SOURCE..."
	mkdir -p "$(dirname "$GODOT_SOURCE")"
	git clone --depth 1 --branch "$GODOT_TAG" https://github.com/godotengine/godot.git "$GODOT_SOURCE"
fi

if [ ! -f "$GODOT_SOURCE/core/version_generated.gen.h" ] \
	|| [ ! -f "$GODOT_SOURCE/core/disabled_classes.gen.h" ]; then
	echo "Generating Godot's build-time headers (an interrupted SCons run)..."
	scons_cmd=(scons)
	command -v scons >/dev/null 2>&1 || scons_cmd=(uvx scons)
	(cd "$GODOT_SOURCE" && "${scons_cmd[@]}" platform=ios target=template_debug arch=arm64 -j8 >/dev/null 2>&1) &
	scons_pid=$!
	for _ in $(seq 1 300); do
		if [ -f "$GODOT_SOURCE/core/version_generated.gen.h" ] \
			&& [ -f "$GODOT_SOURCE/core/disabled_classes.gen.h" ] \
			&& [ -f "$GODOT_SOURCE/core/object/gdvirtual.gen.inc" ]; then
			sleep 5
			break
		fi
		sleep 1
	done
	pkill -P "$scons_pid" >/dev/null 2>&1 || true
	kill "$scons_pid" >/dev/null 2>&1 || true
	wait "$scons_pid" 2>/dev/null || true
fi

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CXX="$(xcrun --sdk iphoneos --find clang++)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$OUT"

# The defines the official iOS export template is built with. Several change
# the layout of engine classes the plugin subclasses, so they must match.
COMMON_DEFINES=(
	-DIOS_ENABLED -DUNIX_ENABLED -DCOREAUDIO_ENABLED -DTHREADS_ENABLED
	-DMETAL_ENABLED -DVULKAN_ENABLED -DRD_ENABLED -DGLES3_ENABLED
	-DMINIZIP_ENABLED -DBROTLI_ENABLED -DNDEBUG
)

build_variant() {
	local variant="$1"
	shift
	"$CXX" -c "$SRC/eye_gaze.mm" -o "$BUILD/eye_gaze.$variant.o" \
		-arch arm64 -isysroot "$SDK" -miphoneos-version-min="$MIN_IOS" \
		-std=gnu++17 -fobjc-arc -fblocks -fvisibility=hidden -O2 -g0 \
		-Wno-ambiguous-macro -Wno-module-import-in-extern-c \
		-I"$GODOT_SOURCE" -I"$GODOT_SOURCE/platform/ios" \
		"${COMMON_DEFINES[@]}" "$@"
	rm -f "$OUT/eye_gaze.$variant.a"
	xcrun --sdk iphoneos libtool -static -o "$OUT/eye_gaze.$variant.a" "$BUILD/eye_gaze.$variant.o"
	echo "Built $OUT/eye_gaze.$variant.a"
}

build_variant debug -DDEBUG_ENABLED
build_variant release
