---
name: orchestrate
description: Manage GitHub issue implementation by delegating to the Claude GitHub Action bot, monitoring PRs, and merging in dependency order.
---

# Orchestrate Issue Implementation

Delegate open issues to the Claude GitHub Action bot, watch the PRs that come
back, and merge them in dependency order.

Adapted for this repo from the shared orchestrate skill. Two things differ from
the version used in the web repos, and both matter:

- **This repo has no `develop` branch.** It is `main`-only, and that is
  deliberate — PRs #2 and #3 landed that way. Everywhere the shared skill says
  `dev`/`develop`, use `main`.
- **Verification needs a GPU and a display.** The fluid solve is compute
  shaders; Godot can only compile them through a real rendering device. There
  is no Tilt and no Playwright here. See "Verifying a change" below.

## Input

Optional argument. Three modes:

- **No arguments** — auto-mode: scan all open issues, find what is unblocked,
  trigger it, review blocking PRs, repeat.
- **Issue numbers** (`20 21 22`) — process a specific batch in dependency order.
- **Label** (`--label ready-to-implement`) — process all open issues so labelled.

## Workflow

### A1. Survey the landscape

```
gh issue list --state open --json number,title,body,labels
gh pr list --state open --json number,title,body,headRefName,statusCheckRollup
```

For each open issue, read the body and determine:

- What it depends on. Parse `depends on #N`, `blocked by #N`, `after #N`,
  `requires #N`, case-insensitive.
- Whether it already has an open PR (branch pattern `claude/issue-<N>-*`, or a
  PR body mentioning the issue).
- Whether it has already been triggered (an issue comment containing
  `@claude please implement`).

For each open PR, determine which issue it belongs to and its CI status.

### A2. Classify

| Bucket | Condition | Action |
|--------|-----------|--------|
| **Ready** | All dependencies closed AND no open PR AND not yet triggered | Trigger |
| **PR open** | Has an open PR | Check CI, review, merge if ready |
| **PR failing** | Open PR, failing CI | Report; offer `@claude please fix` |
| **Blocked** | Has open dependencies | Skip this cycle |
| **Triggered, waiting** | Triggered but no PR yet | Poll |
| **Human** | Has the `human` label | Never trigger. Assign to the repo owner and report. Blocks downstream until closed. |
| **Investigation needed** | Has the `investigation_needed` label | Do not trigger. Investigate on `main`, comment findings, remove the label, re-classify next cycle. |
| **Manual verification** | Has the `manual_verification` label | Trigger normally, but never auto-merge. See below. |

### A3. Execute

**Clear the path first.** For each PR blocking downstream issues:

1. Check for an existing automated review before writing your own:
   ```
   gh pr reviews <number> --json author,body,state
   ```
   `claude-code-review.yml` reviews new PRs automatically. If a review is
   already there, read and summarise it rather than duplicating the work.
2. Otherwise read `gh pr diff <number>` and check it against the issue's
   acceptance criteria.
3. If CI passes and the review is good:
   ```
   gh pr merge <number> --squash --delete-branch
   git checkout main && git pull origin main
   ```
4. Re-classify after each merge — it may unblock new issues.

**Then trigger unblocked issues**, in parallel:

```
gh issue comment <N> --body "@claude please implement this issue, then open a
pull request against main with \`gh pr create\` when the work is pushed."
```

Asking for the PR explicitly matters. Left to itself the bot pushes a
`claude/issue-<N>-*` branch and posts a *link* to open a PR, which no
unattended run will ever click — so the work lands on a branch and the
orchestrator waits forever for a PR that is never created. If you find such a
branch with no PR, open it yourself rather than re-triggering the issue.

Never trigger a `human`-labelled issue. Assign it instead:

```
gh issue edit <N> --add-assignee <repo owner>
```

**Then poll** every 60 seconds for new PRs, up to 30 minutes per issue. Repeat
until everything is closed or only blocked issues remain.

### A4. Report

Print what happened: merged, triggered, waiting, blocked, and anything needing
human action.

## Verifying a change

CI is the first gate and covers most of it: `ci.yml` runs `gdformat --check`,
`gdlint`, and the GUT suite; `build.yml` exports Linux and Windows.

What CI cannot tell you is whether the game *looks* right. A change to the
fluid, the renderer or a shader can pass every test and still render a flat
tank — that is exactly how the viewport-era solve survived as long as it did.
Issues whose effect is visual should carry the `manual_verification` label;
their PRs are implemented by the bot but merged only after a human has run the
game and looked at it.

One Godot-specific trap worth knowing when reviewing:

> `.glsl` compute shaders are compiled to SPIR-V **at import**, and that needs a
> real rendering device. A headless import silently leaves a `valid=false` stub
> with no `.res`. CI installs lavapipe and imports under `xvfb` to work around
> this, and fails the build if fewer than six shaders compiled. A PR that adds
> a compute shader must keep that count check honest.

## Important

- Run autonomously once invoked. Report progress, but do not wait for approval
  between steps.
- A PR with passing CI and an approving review can be merged without asking.
- If a review raises concerns or CI fails, report rather than merging.
- Never trigger a dependent issue before its dependencies are merged to `main`.
- Never force-push, and never force-merge past a conflict.
- This skill orchestrates; it does not implement. The GitHub Action bot does
  the implementation.
- Never run deployment scripts or release pipelines. Deployment is a human
  responsibility — note that `build.yml` deploys to itch.io on tag pushes, so
  never push a tag.
