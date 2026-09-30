#!/usr/bin/env bash
# Merge a pull request, run by the in-game PR picker's hold-to-merge action.
#
#   deck-merge.sh 94 --log FILE
#
# Not meant to be typed by hand. deck-build.sh copies it into tools/ beside
# every build, and the picker runs the copy beside itself, same as
# deck-demo.sh — so it always comes from the build you launched from, not
# from whatever the PR being merged contains.
#
# Needs `gh` on the Deck, authenticated (`gh auth login`) with at least
# `repo` scope. Squash-merges, matching how PRs on this repo are merged
# elsewhere. Output goes to FILE, ending in MERGED or FAILED: the picker
# can't see a spawned process's exit code directly, so it reads that back
# instead once the process ends.

set -uo pipefail

GH="$HOME/.local/bin/gh"
command -v "$GH" >/dev/null 2>&1 || GH="gh"

pr=""
log=""
while [ $# -gt 0 ]; do
	case "$1" in
		--log) log="${2:?--log needs a file}"; shift ;;
		-*) echo "Unknown option: $1" >&2; exit 2 ;;
		*) pr="$1" ;;
	esac
	shift
done
case "$pr" in
	'' | *[!0-9]*) echo "Usage: deck-merge.sh PR_NUMBER [--log FILE]" >&2; exit 2 ;;
esac

if [ -n "$log" ]; then
	mkdir -p "$(dirname "$log")"
	exec >"$log" 2>&1
fi

"$GH" pr merge "$pr" --squash --repo Luan-vP/godot-project-1
status=$?
if [ "$status" -eq 0 ]; then
	echo "MERGED"
else
	echo "FAILED (exit $status)"
fi
exit "$status"
