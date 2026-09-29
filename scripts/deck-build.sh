#!/usr/bin/env bash
# Build a playable Linux export on the Steam Deck itself.
#
#   scripts/deck-build.sh            import, export, install
#   scripts/deck-build.sh --fresh    recompile the compute shaders first
#   scripts/deck-build.sh --as NAME  install to ~/Games/NAME instead, so
#                                    builds can sit side by side to compare
#   scripts/deck-build.sh --root DIR build the project checked out at DIR
#                                    with these scripts (the in-game PR
#                                    picker builds PRs this way)
#
# Runs on the Deck, from its checkout (see scripts/deck.sh for driving it from
# another machine). Expects Godot 4.4.1 at ~/.local/bin/godot4 with matching
# export templates; `scripts/deck.sh setup` installs both.
#
# The build lands in ~/Games/godot-project-1, with a desktop entry so it shows
# up in Desktop Mode's launcher and can be added to Steam as a non-Steam game.

set -euo pipefail

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPTS")"
NAME="godot-project-1"
GODOT_BIN="${GODOT:-$HOME/.local/bin/godot4}"

if [ ! -x "$GODOT_BIN" ]; then
	echo "Godot not found at $GODOT_BIN. Run 'scripts/deck.sh setup' from your dev machine." >&2
	exit 1
fi

# The compute shaders compile to SPIR-V through a real rendering device, which
# --headless does not have. Over ssh there is no display in the environment,
# so borrow the session's: gamescope's Xwayland in Game Mode, Plasma's in
# Desktop Mode. Both are :0, sometimes with the cookie in a randomly named
# xauth_* file in the runtime dir and sometimes with none.
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [ -z "${XAUTHORITY:-}" ]; then
	auth="$(ls -t "$XDG_RUNTIME_DIR"/xauth_* 2>/dev/null | head -n 1 || true)"
	[ -n "$auth" ] && export XAUTHORITY="$auth"
fi

build_name="$NAME"
fresh=0
other_root=0
while [ $# -gt 0 ]; do
	case "$1" in
		--fresh) fresh=1 ;;
		--as) build_name="${2:?--as needs a name}"; shift ;;
		--root) ROOT="$(cd "${2:?--root needs a directory}" && pwd)"; other_root=1; shift ;;
		*) echo "Unknown option: $1" >&2; exit 2 ;;
	esac
	shift
done
INSTALL_DIR="$HOME/Games/$build_name"
IMPORTED="$ROOT/.godot/imported"
SHADER_DIR="$ROOT/features/fluid/shaders/compute"

if [ "$fresh" -eq 1 ]; then
	echo "Clearing compiled compute shaders."
	rm -f "$IMPORTED"/*.glsl-*
fi

echo "Importing the project..."
# Import exits non-zero on harmless warnings, so judge it by what it produced.
"$GODOT_BIN" --path "$ROOT" --import >/dev/null 2>&1 || true

expected="$(ls "$SHADER_DIR"/*.glsl | wc -l | tr -d ' ')"
compiled="$(ls "$IMPORTED" 2>/dev/null | grep -c '\.glsl-.*\.res$' || true)"
if [ "$compiled" -lt "$expected" ]; then
	echo "Import compiled $compiled of $expected compute shaders; the fluid would not run." >&2
	echo "Run 'DISPLAY=:0 $GODOT_BIN --path $ROOT --import' to see why." >&2
	exit 1
fi
echo "Compiled $compiled compute shaders."

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
echo "Exporting..."
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Linux/X11" "$stage/$NAME.x86_64" >"$stage/export.log" 2>&1 || {
	tail -n 30 "$stage/export.log" >&2
	exit 1
}
if [ ! -f "$stage/$NAME.x86_64" ] || [ ! -f "$stage/$NAME.pck" ]; then
	tail -n 30 "$stage/export.log" >&2
	echo "Export produced no executable and .pck." >&2
	exit 1
fi
rm -f "$stage/export.log"

mkdir -p "$INSTALL_DIR"
rm -rf "${INSTALL_DIR:?}"/*
cp -a "$stage"/. "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$NAME.x86_64"
git -C "$ROOT" log -1 --format='%h %s' >"$INSTALL_DIR/BUILD" 2>/dev/null || true

# Game Mode's "Add a Non-Steam Game" file picker only lists .application,
# .exe, .sh and .AppImage — a bare extensionless binary like $NAME.x86_64
# never shows up in it. A .sh wrapper does, and Steam Input only attributes a
# controller to a process it launched itself, so this wrapper is the actual
# way to add and run a build from Game Mode.
cat >"$INSTALL_DIR/launch.sh" <<LAUNCH
#!/usr/bin/env bash
cd "\$(dirname "\$0")"
exec ./$NAME.x86_64 "\$@"
LAUNCH
chmod +x "$INSTALL_DIR/launch.sh"

# The PR picker swaps the running build for another with tools/deck-demo.sh,
# which builds with tools/deck-build.sh, and merges one with tools/deck-merge.sh.
# They are copied from these scripts, not from the project being built, so a
# PR older than any of them still builds, swaps and merges the same way.
mkdir -p "$INSTALL_DIR/tools"
cp "$SCRIPTS/deck-demo.sh" "$SCRIPTS/deck-build.sh" "$SCRIPTS/deck-merge.sh" "$INSTALL_DIR/tools/"
chmod +x "$INSTALL_DIR/tools/"*.sh

# PR builds are reached through the picker; a launcher entry each would pile up.
if [ "$other_root" -eq 1 ]; then
	echo "Installed $(cat "$INSTALL_DIR/BUILD" 2>/dev/null || echo build) to $INSTALL_DIR"
	exit 0
fi

mkdir -p "$HOME/.local/share/applications"
cat >"$HOME/.local/share/applications/$build_name.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$build_name
Exec=$INSTALL_DIR/$NAME.x86_64
Path=$INSTALL_DIR
Terminal=false
Categories=Game;
DESKTOP

echo "Installed $(cat "$INSTALL_DIR/BUILD" 2>/dev/null || echo build) to $INSTALL_DIR"
