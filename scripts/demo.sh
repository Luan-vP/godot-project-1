#!/usr/bin/env bash
# Fetch, build and launch a PR on the Steam Deck in one shot.
#
#   scripts/demo.sh <N>    fetch PR #N, merge it onto this branch's Deck
#                          tooling in a scratch worktree, build it as pr-N,
#                          and launch it on the Deck's screen
#
# Reuses a scratch worktree (../godot-project-1-deck-pr) across runs so
# repeat calls are fast. If the merge conflicts only on Deck tooling files
# (README.md, scripts/deck.sh, scripts/deck-build.sh) this branch's version
# wins automatically, since those are what actually build and run it. Any
# other conflict stops the script for you to resolve by hand in the
# worktree.

set -euo pipefail

N="${1:?usage: scripts/demo.sh <PR number>}"
TOOLING_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
WORKTREE="$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-deck-pr"
BRANCH="deck-pr-scratch"
DECK_FILES=(README.md scripts/deck.sh scripts/deck-build.sh)
SRC_BRANCH="pr-$N-src"

cd "$REPO_ROOT"
git fetch origin "pull/$N/head:$SRC_BRANCH" --force

if [ -d "$WORKTREE" ]; then
	git -C "$WORKTREE" merge --abort 2>/dev/null || true
	git -C "$WORKTREE" checkout -B "$BRANCH" "$TOOLING_BRANCH"
else
	git worktree add -b "$BRANCH" "$WORKTREE" "$TOOLING_BRANCH"
fi

if ! git -C "$WORKTREE" merge --no-edit "$SRC_BRANCH"; then
	unexpected=()
	while IFS= read -r f; do
		known=0
		for d in "${DECK_FILES[@]}"; do [ "$f" = "$d" ] && known=1; done
		[ "$known" -eq 0 ] && unexpected+=("$f")
	done < <(git -C "$WORKTREE" diff --name-only --diff-filter=U)
	if [ "${#unexpected[@]}" -gt 0 ]; then
		echo "Merge conflicts outside Deck tooling files, resolve by hand in $WORKTREE:" >&2
		printf '  %s\n' "${unexpected[@]}" >&2
		exit 1
	fi
	git -C "$WORKTREE" checkout --ours -- "${DECK_FILES[@]}"
	git -C "$WORKTREE" add "${DECK_FILES[@]}"
	git -C "$WORKTREE" commit --no-edit
fi

git -C "$WORKTREE" clean -qfd
(cd "$WORKTREE" && scripts/deck.sh build --as "pr-$N")
scripts/deck.sh run "pr-$N"
