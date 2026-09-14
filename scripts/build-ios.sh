#!/usr/bin/env bash
# Build the game for iPhone and run it, on a connected phone or a simulator.
#
#   scripts/build-ios.sh                    export, build, install, launch on the
#                                           first connected iPhone
#   scripts/build-ios.sh --device <id>      a specific device (devicectl identifier,
#                                           or set IOS_DEVICE)
#   scripts/build-ios.sh --simulator        the "iPhone 16 Pro" simulator
#   scripts/build-ios.sh --simulator "iPhone 16e"
#   scripts/build-ios.sh --export-only      just write the Xcode project
#   scripts/build-ios.sh -- --open=eyes     anything after -- is passed to the game
#
# Output goes under builds/ (ignored by git): builds/ios is the exported Xcode
# project, builds/ios-derived the device build, builds/ios-sim and
# builds/ios-derived-sim the simulator's.
#
# Signing is automatic, for team $IOS_TEAM (default BJS3Z2X97R). Xcode must be
# signed in to an Apple account on that team (Xcode > Settings > Accounts) so it
# can create the development certificate and profile; nothing is committed.
#
# The simulator is only good for layout. Godot 4.4 runs it on the OpenGL
# Compatibility renderer, which has no RenderingDevice, so the fluid's compute
# solve cannot run there. Its official simulator library is also x86_64 only
# (the build runs under Rosetta) and links a framework the simulator SDK lacks.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILDS="$ROOT/builds"
EXPORT_DIR="$BUILDS/ios"
PROJECT_NAME="godot_project_1"
PRESET="iOS"
BUNDLE_ID="com.luanvanpletsen.godotproject1"
TEAM="${IOS_TEAM:-BJS3Z2X97R}"
IMPORTED="$ROOT/.godot/imported"
SHADER_DIR="$ROOT/features/fluid/shaders/compute"
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/4.4.stable"
DEFAULT_SIMULATOR="iPhone 16 Pro"

usage() {
	sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

target="device"
device="${IOS_DEVICE:-}"
simulator="$DEFAULT_SIMULATOR"
launch=1
game_args=()
while [ $# -gt 0 ]; do
	case "$1" in
		-h | --help) usage; exit 0 ;;
		--device)
			[ $# -ge 2 ] || { echo "--device needs an identifier" >&2; exit 2; }
			device="$2"; shift ;;
		--simulator)
			target="simulator"
			if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then simulator="$2"; shift; fi ;;
		--export-only) target="none" ;;
		--no-launch) launch=0 ;;
		--) shift; game_args=("$@"); break ;;
		*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

find_godot() {
	if [ -n "${GODOT:-}" ]; then
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

if ! GODOT_BIN="$(find_godot)"; then
	echo "Godot not found. Install Godot 4.4 or set GODOT=/path/to/Godot." >&2
	exit 1
fi

if [ ! -f "$TEMPLATES/ios.zip" ]; then
	echo "Godot 4.4 export templates are missing ($TEMPLATES/ios.zip)." >&2
	echo "Download https://github.com/godotengine/godot/releases/download/4.4-stable/Godot_v4.4-stable_export_templates.tpz" >&2
	echo "and unzip its templates/ folder's contents into that directory." >&2
	exit 1
fi

# The compute shaders are compiled at import, and only with a window; a
# headless export would ship whatever stubs are there and the fluid would sit
# still on the phone. See features/fluid/README.md.
compiled="$(ls "$IMPORTED" 2>/dev/null | grep -c '\.glsl-.*\.res$' || true)"
expected="$(ls "$SHADER_DIR"/*.glsl | wc -l | tr -d ' ')"
if [ "$compiled" -lt "$expected" ]; then
	echo "Importing the project (compute shaders need a window)..."
	"$GODOT_BIN" --path "$ROOT" --import >/dev/null 2>&1 || true
	compiled="$(ls "$IMPORTED" 2>/dev/null | grep -c '\.glsl-.*\.res$' || true)"
	if [ "$compiled" -lt "$expected" ]; then
		echo "Import compiled $compiled of $expected compute shaders; not exporting a still tank." >&2
		exit 1
	fi
fi

echo "Exporting the Xcode project to $EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
"$GODOT_BIN" --headless --path "$ROOT" --export-debug "$PRESET" "$EXPORT_DIR/$PROJECT_NAME.ipa" \
	>"$BUILDS/ios-export.log" 2>&1 || true
# Godot's exit code is not reliable here; judge the export by what it wrote.
if grep -q "ERROR" "$BUILDS/ios-export.log" || [ ! -d "$EXPORT_DIR/$PROJECT_NAME.xcodeproj" ]; then
	grep -A1 "ERROR" "$BUILDS/ios-export.log" >&2 || true
	echo "Export failed; full log in builds/ios-export.log" >&2
	exit 1
fi

[ "$target" = "none" ] && exit 0

if [ "$target" = "simulator" ]; then
	SIM_DIR="$BUILDS/ios-sim"
	rm -rf "$SIM_DIR"
	cp -R "$EXPORT_DIR" "$SIM_DIR"
	# MetalFX is not in the simulator SDK, and nothing on the simulator's
	# Compatibility renderer uses it.
	sed -i '' '/MetalFX/d' "$SIM_DIR/$PROJECT_NAME.xcodeproj/project.pbxproj"
	echo "Building for the simulator"
	xcodebuild -quiet \
		-project "$SIM_DIR/$PROJECT_NAME.xcodeproj" -scheme "$PROJECT_NAME" -configuration Debug \
		-destination "generic/platform=iOS Simulator" -derivedDataPath "$BUILDS/ios-derived-sim" \
		ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
	app="$BUILDS/ios-derived-sim/Build/Products/Debug-iphonesimulator/$PROJECT_NAME.app"
	udid="$(xcrun simctl list devices available | grep -F "    $simulator (" | head -n 1 \
		| sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
	if [ -z "$udid" ]; then
		echo "No available simulator named '$simulator'. See 'xcrun simctl list devices available'." >&2
		exit 1
	fi
	xcrun simctl boot "$udid" 2>/dev/null || true
	xcrun simctl bootstatus "$udid" -b >/dev/null
	open -a Simulator --args -CurrentDeviceUDID "$udid" || true
	xcrun simctl install "$udid" "$app"
	echo "Installed on $simulator ($udid)"
	if [ "$launch" -eq 1 ]; then
		xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" \
			${game_args[@]+"${game_args[@]}"}
	fi
	exit 0
fi

if [ -z "$device" ]; then
	devices_json="$BUILDS/ios-devices.json"
	xcrun devicectl list devices --json-output "$devices_json" >/dev/null 2>&1 || true
	device="$(/usr/bin/python3 - "$devices_json" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
for d in devices:
    props = d.get("hardwareProperties", {})
    conn = d.get("connectionProperties", {})
    if props.get("platform") == "iOS" and conn.get("pairingState") == "paired":
        print(d["identifier"])
        break
PY
)"
	if [ -z "$device" ]; then
		echo "No paired iPhone found. Connect one, or pass --device <id> (xcrun devicectl list devices)." >&2
		exit 1
	fi
fi

echo "Building for device (team $TEAM)"
if ! xcodebuild -quiet \
	-project "$EXPORT_DIR/$PROJECT_NAME.xcodeproj" -scheme "$PROJECT_NAME" -configuration Debug \
	-destination "generic/platform=iOS" -derivedDataPath "$BUILDS/ios-derived" \
	-allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic build; then
	echo >&2
	echo "Device build failed. If it says 'No Accounts' or 'No profiles', sign in to Xcode" >&2
	echo "(Xcode > Settings > Accounts) with an Apple ID on team $TEAM, then run this again." >&2
	exit 1
fi
app="$BUILDS/ios-derived/Build/Products/Debug-iphoneos/$PROJECT_NAME.app"

echo "Installing on $device"
xcrun devicectl device install app --device "$device" "$app"
if [ "$launch" -eq 1 ]; then
	echo "Launching (unlock the phone if this fails; the first run may need"
	echo "Settings > General > VPN & Device Management > trust the developer)"
	xcrun devicectl device process launch --device "$device" --terminate-existing \
		"$BUNDLE_ID" ${game_args[@]+"${game_args[@]}"}
fi
