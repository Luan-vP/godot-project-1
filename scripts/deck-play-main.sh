#!/usr/bin/env bash
# Double-click target for the Desktop Mode "Play main" icon: always builds
# and runs whatever is currently on origin/main, so playing from the icon is
# never a stale build left over from testing some other branch or PR merge.
#
# Runs entirely on the Deck, in its own graphical session — unlike
# scripts/deck-build.sh over ssh, DISPLAY and XAUTHORITY are already correct
# here, so nothing has to guess at them.
#
# Installed as ~/Desktop/godot-project-1-play-main.desktop by
# `scripts/deck.sh setup`; see that for the icon itself.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="godot-project-1"
REPO_URL="${DEMO_REPO_URL:-https://github.com/Luan-vP/godot-project-1.git}"

# A build failure would otherwise close the terminal before the error is
# readable, since Terminal=true closes its window when the command exits.
trap 'echo; echo "Failed. Press Enter to close."; read -r _' ERR

# `scripts/deck.sh setup` only runs `git init` here; it never gives this
# checkout an `origin` remote to fetch main from. Configure it every run, the
# same way deck-demo.sh does for PR fetches, so this works from a checkout
# that has never played a PR either.
if git -C "$ROOT" remote get-url origin >/dev/null 2>&1; then
	git -C "$ROOT" remote set-url origin "$REPO_URL"
else
	git -C "$ROOT" remote add origin "$REPO_URL"
fi

echo "Updating to the latest main..."
git -C "$ROOT" fetch -q origin main
git -C "$ROOT" reset -q --hard origin/main
git -C "$ROOT" clean -qfd

"$ROOT/scripts/deck-build.sh"

echo "Launching..."
exec "$HOME/Games/$NAME/$NAME.x86_64"
