#!/usr/bin/env bash
# Swap the running game for a build of an open pull request, on the Deck.
#
#   deck-demo.sh 94 --launcher-pid PID --log FILE
#
# The in-game pull request picker (features/ui/pr_picker) runs this; it is not
# meant to be typed. deck-build.sh copies it into tools/ beside every build,
# and the picker runs the copy beside itself, so the swap logic always comes
# from the build you launched from Game Mode, whatever the PR contains.
#
# Each PR gets a git worktree of the Deck's checkout, and a build beside the
# main one:
#
#   ~/dev/godot-project-1/                 the checkout scripts/deck.sh pushes to;
#                                          the one repository, with a GitHub
#                                          `origin` remote added for PR refs
#   ~/dev/godot-project-1-prs/pr-94/       PR #94's worktree, detached at its head
#   ~/Games/godot-project-1/               the main build (this picker)
#   ~/Games/godot-project-1-prs/pr-94/     PR #94's build
#
# It fetches the PR, updates its worktree, builds it with the same tools'
# deck-build.sh (skipped when that commit is already built), then ends the
# picker's process and runs the PR build in the foreground. When the PR build
# quits — Select on its demo menu, when it has this code — the launcher is
# started again straight into the picker, so pressing back in one PR and
# picking another is the whole loop.
#
# Progress goes to FILE, which the picker shows while the build runs. If the
# build fails this exits non-zero and leaves the picker running, so the error
# can be read and another PR picked.

set -euo pipefail

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER_DIR="$(dirname "$TOOLS")"
NAME="godot-project-1"
REPO_URL="${DEMO_REPO_URL:-https://github.com/Luan-vP/godot-project-1.git}"
REPO="${DEMO_REPO:-$HOME/dev/$NAME}"
WORKTREES="${DEMO_WORKTREES:-$HOME/dev/$NAME-prs}"
BUILDS="$NAME-prs"
SHADER_DIR="features/fluid/shaders/compute"

pr=""
launcher_pid=""
log=""
while [ $# -gt 0 ]; do
	case "$1" in
		--launcher-pid) launcher_pid="${2:?--launcher-pid needs a pid}"; shift ;;
		--log) log="${2:?--log needs a file}"; shift ;;
		-*) echo "Unknown option: $1" >&2; exit 2 ;;
		*) pr="$1" ;;
	esac
	shift
done
case "$pr" in
	'' | *[!0-9]*) echo "Usage: deck-demo.sh PR_NUMBER [--launcher-pid PID] [--log FILE]" >&2; exit 2 ;;
esac

if [ -n "$log" ]; then
	mkdir -p "$(dirname "$log")"
	exec >"$log" 2>&1
fi

# The picker starts this under setsid, so this shell leads a process group of
# its own, and stopping a build from the picker signals the whole group: the
# import and export under it stop too.

if [ ! -d "$REPO/.git" ]; then
	echo "No checkout at $REPO. Run 'scripts/deck.sh setup' from your dev machine." >&2
	exit 1
fi
if git -C "$REPO" remote get-url origin >/dev/null 2>&1; then
	git -C "$REPO" remote set-url origin "$REPO_URL"
else
	git -C "$REPO" remote add origin "$REPO_URL"
fi

echo "Fetching PR #$pr..."
ref="refs/remotes/origin/pr/$pr"
git -C "$REPO" fetch -q origin "+pull/$pr/head:$ref"

worktree="$WORKTREES/pr-$pr"
# Forget worktrees whose directories were deleted by hand, and clear out a
# directory here that git no longer knows as one, so `worktree add` can use it.
git -C "$REPO" worktree prune
if [ -e "$worktree" ] && [ ! -f "$worktree/.git" ]; then
	rm -rf "$worktree"
fi
if [ -f "$worktree/.git" ]; then
	# What the shaders were last compiled from, in this worktree.
	previous="$(git -C "$worktree" rev-parse HEAD)"
	# A build copy: import rewrites files, so drop whatever the last build
	# left (.godot/ is ignored and survives, keeping imports cached).
	git -C "$worktree" checkout -q -f --detach "$ref"
	git -C "$worktree" clean -qfd
else
	mkdir -p "$WORKTREES"
	git -C "$REPO" worktree add -q --detach "$worktree" "$ref"
	previous=""
	# Start from the main checkout's import cache rather than importing the
	# whole project from nothing; its shaders were compiled from its HEAD.
	if [ -d "$REPO/.godot" ]; then
		cp -a "$REPO/.godot" "$worktree/.godot"
		previous="$(git -C "$REPO" rev-parse -q --verify HEAD || true)"
	fi
fi
head="$(git -C "$worktree" log -1 --format='%h %s')"
echo "PR #$pr is at $head"

build_name="$BUILDS/pr-$pr"
install_dir="$HOME/Games/$build_name"
if [ "$(cat "$install_dir/BUILD" 2>/dev/null)" = "$head" ] && [ -x "$install_dir/$NAME.x86_64" ]; then
	echo "Already built; skipping the build."
else
	build_args=(--root "$worktree" --as "$build_name")
	# Godot only reimports a shader when its own file changes, not the
	# parameter block they all include, so recompile whenever the shaders
	# differ from what the cached ones were compiled from.
	if [ -n "$previous" ] && ! git -C "$worktree" diff --quiet "$previous" HEAD -- "$SHADER_DIR"; then
		build_args+=(--fresh)
	fi
	"$TOOLS/deck-build.sh" "${build_args[@]}"
fi

if [ -n "$launcher_pid" ]; then
	echo "Handing over to PR #$pr..."
	kill "$launcher_pid" 2>/dev/null || true
	# Let it release the GPU and the audio device before the next one wants them.
	for _ in $(seq 50); do
		kill -0 "$launcher_pid" 2>/dev/null || break
		sleep 0.1
	done
	kill -9 "$launcher_pid" 2>/dev/null || true
fi

# Not exec: when the PR build quits, come back to the picker.
(cd "$install_dir" && "./$NAME.x86_64" -- --from-picker) || true

cd "$LAUNCHER_DIR"
exec "./$NAME.x86_64" -- --prs
