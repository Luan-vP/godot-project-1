#!/usr/bin/env bash
# Drive builds on a Steam Deck from your dev machine, over ssh (Tailscale).
#
#   scripts/deck.sh setup     install Godot + export templates on the Deck,
#                             create its checkout, add the `deck` git remote
#   scripts/deck.sh build     push HEAD to the Deck and build there
#                             (--as NAME installs it to ~/Games/NAME, so
#                             builds can sit side by side to compare)
#   scripts/deck.sh run       launch the installed build on the Deck's screen
#   scripts/deck.sh stop      quit it
#   scripts/deck.sh logs      show its recent output
#                             (run/stop/logs take a NAME from build --as)
#   scripts/deck.sh ssh       open a shell on the Deck
#
# Host defaults to deck@steamdeck; override with DECK_HOST. Tailscale SSH in
# "check" mode asks for a browser approval on the first connection; later
# commands reuse that connection for four hours, so it is asked once.
#
# `build` pushes committed work only: commit (or stash-commit) first.

set -euo pipefail

HOST="${DECK_HOST:-deck@steamdeck}"
GODOT_VERSION="4.4.1"
REPO_DIR="dev/godot-project-1"
NAME="godot-project-1"

# A short control path: macOS caps unix socket paths at 104 bytes.
SSH=(ssh -o ControlMaster=auto -o "ControlPath=/tmp/deck-%C" -o ControlPersist=4h -o ServerAliveInterval=30)
export GIT_SSH_COMMAND="${SSH[*]}"

remote() { "${SSH[@]}" "$HOST" "$@"; }

setup() {
	remote bash -s -- "$GODOT_VERSION" "$REPO_DIR" <<'REMOTE'
set -euo pipefail
V="$1"; REPO="$HOME/$2"
OPT="$HOME/.local/opt/godot/$V"
TEMPLATES="$HOME/.local/share/godot/export_templates/$V.stable"
BASE="https://github.com/godotengine/godot/releases/download/$V-stable"
mkdir -p "$OPT" "$HOME/.local/bin" "$(dirname "$TEMPLATES")"
if [ ! -x "$OPT/Godot_v$V-stable_linux.x86_64" ]; then
	echo "Downloading Godot $V..."
	curl -fsSL -o "$OPT/godot.zip" "$BASE/Godot_v$V-stable_linux.x86_64.zip"
	unzip -o -q "$OPT/godot.zip" -d "$OPT" && rm "$OPT/godot.zip"
fi
ln -sf "$OPT/Godot_v$V-stable_linux.x86_64" "$HOME/.local/bin/godot4"
if [ ! -f "$TEMPLATES/linux_release.x86_64" ]; then
	echo "Downloading export templates $V..."
	curl -fsSL -o "$OPT/templates.tpz" "$BASE/Godot_v${V}-stable_export_templates.tpz"
	unzip -o -q "$OPT/templates.tpz" -d "$OPT"
	rm -rf "$TEMPLATES" && mv "$OPT/templates" "$TEMPLATES" && rm "$OPT/templates.tpz"
fi
if [ ! -d "$REPO/.git" ]; then
	mkdir -p "$REPO"
	git -C "$REPO" init -q -b main
fi
# Lets a push update the checked-out tree directly.
git -C "$REPO" config receive.denyCurrentBranch updateInstead
grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
echo "Godot: $("$HOME/.local/bin/godot4" --version)"
REMOTE
	if git remote get-url deck >/dev/null 2>&1; then
		git remote set-url deck "$HOST:$REPO_DIR"
	else
		git remote add deck "$HOST:$REPO_DIR"
	fi
	echo "Added git remote 'deck' -> $HOST:$REPO_DIR"
}

build() {
	if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
		echo "Note: uncommitted changes are not sent; building $(git rev-parse --short HEAD)." >&2
	fi
	# Importing rewrites project.godot and generates missing .uid files, and a
	# push refuses to update a dirty checkout. The Deck's tree is a build copy,
	# so drop them (.godot/ is ignored and survives, keeping imports cached).
	remote "git -C ~/$REPO_DIR reset -q --hard && git -C ~/$REPO_DIR clean -qfd"
	git push --force deck HEAD:main
	remote "cd ~/$REPO_DIR && scripts/deck-build.sh $*"
}

run() {
	local build="${1:-$NAME}"
	# gamescope (Game Mode) and Plasma (Desktop Mode) both serve :0, with the
	# cookie in a randomly named xauth_* file. A transient user unit outlives
	# the ssh session, which would otherwise take the game down with it.
	remote "systemctl --user stop $build 2>/dev/null; systemctl --user reset-failed $build 2>/dev/null
		systemd-run --user --quiet --unit=$build --working-directory=\$HOME/Games/$build \
			--setenv=DISPLAY=:0 --setenv=XAUTHORITY=\$(ls -t /run/user/\$(id -u)/xauth_* | head -n 1) \
			\$HOME/Games/$build/$NAME.x86_64"
	echo "Launched $build on the Deck. Logs: scripts/deck.sh logs $build"
}

stop() {
	local build="${1:-$NAME}"
	remote "systemctl --user stop $build 2>/dev/null && echo Stopped. || echo Not running."
}

logs() {
	local build="${1:-$NAME}"
	remote "journalctl --user -u $build -n 50 --no-pager"
}

case "${1:-}" in
	setup) setup ;;
	build) shift; build "$@" ;;
	run) run "${2:-}" ;;
	stop) stop "${2:-}" ;;
	logs) logs "${2:-}" ;;
	ssh) "${SSH[@]}" "$HOST" ;;
	*) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
