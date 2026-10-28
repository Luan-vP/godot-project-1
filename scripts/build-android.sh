#!/usr/bin/env bash
# Build the game for Android: a debug APK on a connected phone, or a release
# bundle up to Google Play's internal testing track.
#
#   scripts/build-android.sh                  export a debug APK, install and launch it
#                                             on the connected phone (adb)
#   scripts/build-android.sh --device <id>    a specific phone (adb devices, or set
#                                             ANDROID_SERIAL)
#   scripts/build-android.sh --export-only    just write the APK
#   scripts/build-android.sh --release        signed release bundle (.aab), uploaded to
#                                             the internal testing track
#   scripts/build-android.sh --release --no-upload
#   scripts/build-android.sh --make-upload-key
#                                             create the upload key, once per machine
#
# Output goes under builds/ (ignored by git): builds/android has the debug APK,
# builds/android-release the bundle. The Gradle project a release builds with
# goes in android/ (ignored too); it is installed from the export templates
# whenever it is missing or from another Godot version.
#
# A release is signed with the upload key in $ANDROID_UPLOAD_KEYSTORE (default
# ~/.android/eyemusic-upload.keystore, alias "upload"). Its password comes from
# $ANDROID_UPLOAD_KEYSTORE_PASSWORD, or else the login keychain, where
# --make-upload-key puts it. Back the keystore up; Play re-signs the app with
# its own key, so a lost upload key can be reset in Play Console, but it takes
# days. The upload uses the Play service account key in $PLAY_SERVICE_ACCOUNT
# (default ~/.config/eyemusic/play-service-account.json). The version code is
# the minutes since 1970, so every upload gets a new, higher one. The app must
# already exist in Play Console, and its first bundle has to be uploaded there
# by hand; Play's API only takes bundles for an app it has seen one for.
#
# The fluid's compute solve needs Vulkan. A phone without it falls back to the
# Compatibility renderer, and the tank sits still.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILDS="$ROOT/builds"
PRESET="Android"
RELEASE_PRESET="Android Play"
PACKAGE="com.goldenruleengineering.eyemusic"
ACTIVITY="com.godot.game.GodotApp"
KEYSTORE="${ANDROID_UPLOAD_KEYSTORE:-$HOME/.android/eyemusic-upload.keystore}"
KEY_ALIAS="upload"
KEYCHAIN_SERVICE="eyemusic-android-upload-key"
SERVICE_ACCOUNT="${PLAY_SERVICE_ACCOUNT:-$HOME/.config/eyemusic/play-service-account.json}"
IMPORTED="$ROOT/.godot/imported"
SHADER_DIR="$ROOT/features/fluid/shaders/compute"

usage() {
	sed -n '2,35p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

target="device"
launch=1
upload=1
while [ $# -gt 0 ]; do
	case "$1" in
		-h | --help) usage; exit 0 ;;
		--device)
			[ $# -ge 2 ] || { echo "--device needs a serial" >&2; exit 2; }
			export ANDROID_SERIAL="$2"; shift ;;
		--export-only) target="none" ;;
		--release) target="release" ;;
		--no-upload) upload=0 ;;
		--no-launch) launch=0 ;;
		--make-upload-key) target="key" ;;
		*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

keystore_password() {
	if [ -n "${ANDROID_UPLOAD_KEYSTORE_PASSWORD:-}" ]; then
		echo "$ANDROID_UPLOAD_KEYSTORE_PASSWORD"
		return
	fi
	security find-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null
}

if [ "$target" = "key" ]; then
	if [ -f "$KEYSTORE" ]; then
		echo "$KEYSTORE already exists; not replacing an upload key." >&2
		exit 1
	fi
	mkdir -p "$(dirname "$KEYSTORE")"
	password="$(openssl rand -base64 24 | tr -d '/+=')"
	# PKCS12 keystores take one password for the store and the key.
	keytool -genkeypair -keystore "$KEYSTORE" -storetype PKCS12 -alias "$KEY_ALIAS" \
		-keyalg RSA -keysize 4096 -validity 10000 -storepass "$password" \
		-dname "CN=eyeMusic upload key, O=Golden Rule Engineering" >/dev/null
	security add-generic-password -a "$USER" -s "$KEYCHAIN_SERVICE" -w "$password" -U
	echo "Upload key: $KEYSTORE (alias $KEY_ALIAS)"
	echo "Its password is in the login keychain as '$KEYCHAIN_SERVICE'. Back both up."
	exit 0
fi

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

# "4.4.1.stable.official.49a5bc7b6" -> "4.4.1.stable", the templates' folder.
godot_version="$("$GODOT_BIN" --version | cut -d. -f1-4 | sed -E 's/\.(stable|rc[0-9]*|beta[0-9]*|dev[0-9]*)\..*$/.\1/')"
if [ "$(uname)" = "Darwin" ]; then
	TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$godot_version"
else
	TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$godot_version"
fi
if [ ! -f "$TEMPLATES/android_source.zip" ]; then
	echo "Godot $godot_version's Android export templates are missing ($TEMPLATES)." >&2
	echo "Install them from the editor: Editor > Manage Export Templates." >&2
	exit 1
fi

if [ "$target" = "release" ]; then
	if [ ! -f "$KEYSTORE" ]; then
		echo "No upload key at $KEYSTORE. Make one with --make-upload-key." >&2
		exit 1
	fi
	if ! password="$(keystore_password)"; then
		echo "No password for $KEYSTORE: set ANDROID_UPLOAD_KEYSTORE_PASSWORD." >&2
		exit 1
	fi
	if [ "$upload" -eq 1 ] && [ ! -f "$SERVICE_ACCOUNT" ]; then
		echo "No Play service account key at $SERVICE_ACCOUNT (or pass --no-upload)." >&2
		exit 1
	fi
	export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
	export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEY_ALIAS"
	export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$password"
fi

mkdir -p "$BUILDS"
# builds/ sits inside res://; see build-ios.sh.
touch "$BUILDS/.gdignore"

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

# Godot's exit code is not reliable; judge an export by what it wrote. The
# leak reports at exit are noise.
export_failed() {
	local log="$1" output="$2"
	if grep "ERROR" "$log" | grep -qv "leaked\|still in use" || [ ! -s "$output" ]; then
		grep -A1 "ERROR" "$log" >&2 || true
		echo "Export failed; full log in ${log#"$ROOT"/}" >&2
		return 0
	fi
	return 1
}

if [ "$target" = "release" ]; then
	EXPORT_DIR="$BUILDS/android-release"
	bundle="$EXPORT_DIR/eyeMusic.aab"
	export_log="$BUILDS/android-release-export.log"
	rm -rf "$EXPORT_DIR"
	mkdir -p "$EXPORT_DIR"

	# The flag only works alongside an export; on its own Godot never quits.
	install_template=()
	if [ "$(cat "$ROOT/android/.build_version" 2>/dev/null)" != "$godot_version" ]; then
		echo "Installing Godot $godot_version's Android build template into android/"
		rm -rf "$ROOT/android"
		install_template=(--install-android-build-template)
	fi

	version_code="$(($(date +%s) / 60))"
	presets="$ROOT/export_presets.cfg"
	cp "$presets" "$BUILDS/export_presets.cfg.bak"
	trap 'mv "$BUILDS/export_presets.cfg.bak" "$presets"' EXIT
	# Only the release preset's version code; Godot reads it from this file.
	/usr/bin/python3 - "$presets" "$RELEASE_PRESET" "$version_code" <<'PY'
import re, sys
path, preset, code = sys.argv[1:]
text = open(path).read()
number = re.search(r'\[preset\.(\d+)\]\n\nname="%s"' % re.escape(preset), text).group(1)
section = re.compile(r'(\[preset\.%s\.options\]\n(?:(?!\[preset).*\n)*?)version/code=\d+' % number)
text, n = section.subn(r'\g<1>version/code=' + code, text)
assert n == 1, "no version/code in the %s preset" % preset
open(path, "w").write(text)
PY

	echo "Exporting release bundle, version code $version_code (Gradle; the first build is slow)"
	"$GODOT_BIN" --headless --path "$ROOT" ${install_template[@]+"${install_template[@]}"} \
		--export-release "$RELEASE_PRESET" "$bundle" >"$export_log" 2>&1 || true
	if export_failed "$export_log" "$bundle"; then
		exit 1
	fi
	echo "Bundle: ${bundle#"$ROOT"/}"
	[ "$upload" -eq 1 ] || exit 0
	/usr/bin/python3 "$ROOT/scripts/play-upload.py" "$SERVICE_ACCOUNT" "$PACKAGE" "$bundle" internal
	exit 0
fi

EXPORT_DIR="$BUILDS/android"
apk="$EXPORT_DIR/eyeMusic.apk"
export_log="$BUILDS/android-export.log"
mkdir -p "$EXPORT_DIR"
rm -f "$apk"
echo "Exporting the debug APK to ${apk#"$ROOT"/}"
"$GODOT_BIN" --headless --path "$ROOT" --export-debug "$PRESET" "$apk" >"$export_log" 2>&1 || true
if export_failed "$export_log" "$apk"; then
	exit 1
fi

[ "$target" = "none" ] && exit 0

ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
command -v adb >/dev/null 2>&1 && ADB="$(command -v adb)"
if [ -z "${ANDROID_SERIAL:-}" ] && [ "$("$ADB" devices | grep -c 'device$' || true)" -eq 0 ]; then
	echo "No phone found. Connect one with USB debugging on (Settings > Developer options)," >&2
	echo "and accept the computer's key on the phone." >&2
	exit 1
fi
echo "Installing"
# A phone holding a Play build has it signed with another key, and refuses
# this one on top; uninstall that first (adb uninstall $PACKAGE).
"$ADB" install -r "$apk"
if [ "$launch" -eq 1 ]; then
	"$ADB" shell am start -S -n "$PACKAGE/$ACTIVITY" >/dev/null
	echo "Launched"
fi
