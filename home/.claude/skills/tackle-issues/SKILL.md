---
name: tackle-issues
description: This skill should be used when the user asks to "tackle issues", "pick up open issues", "implement these issues", "knock out these tickets", "work through the issue backlog", or wants to implement minor actionable GitHub Issues end-to-end (optionally narrowed to specific issue numbers). Selects minor actionable issues, parallelizes disjoint-file issues via git worktrees, implements + verifies + opens PRs, and auto-merges when checks are green.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent
---

# Tackle Minor Issues (parallel via worktrees)

Judge which open issues are **minor and actionable**, implement them, and —
when verification is green — open PRs and **auto-merge**. Run **independent**
issues in parallel using git worktrees.

This skill is project-agnostic: discover each repo's actual architecture,
conventions, and toolchain at run time rather than assuming any specific stack,
files, or tools exist. The examples below (Rust/cargo, JS/pnpm) are illustrative
— substitute whatever this repo actually uses.

If the user names specific issue numbers in their request, target only those.
Otherwise auto-pick minor ones per Step 1.

## Conventions to follow

- User-global commit rules at `@references/git-workflow.md` always apply
  (one-intent-per-commit, `git add -p`, footer format).
- Read the project's workflow rules before starting — at minimum
  `.claude/rules/git-workflow.md` if present (branch-from-main, `Closes #N`,
  project-specific naming). Also read **any other convention docs the repo
  ships** (e.g. under `.claude/rules/`, or a `CONTRIBUTING.md` / `CLAUDE.md`):
  coding standards, framework patterns, etc., and honor them. Do not assume a
  doc exists — check first.
- **Use the repo's own way of running commands.** How tools are invoked is an
  environment concern that varies per project — a version manager (mise / asdf /
  anyenv), `direnv`/`nix`, a container (`docker compose exec …`), or just
  binaries already on `PATH`. Don't assume any particular one. Take the exact
  commands from the repo's docs (`CLAUDE.md` / README / CONTRIBUTING), its
  `package.json` scripts, or its CI config — **including any wrapper or prefix
  they show** — and run them verbatim. If the docs show a bare `cargo test`, run
  it directly; if they show `mise exec -- cargo test` or
  `docker compose exec app pnpm test`, use that. When unsure, prefer the command
  CI runs.

## Step 1 — Select issues

- `gh issue list --state open --json number,title,labels,assignees --limit 100`
  and read candidates (`gh issue view <n>`). For backlogs > 100, either
  raise `--limit` (e.g. `--limit 1000`), window by `--search
  "created:<YYYY-MM-DD"`, or run again with a label filter — do not
  silently truncate. (`gh issue list` has no cursor; iterating without a
  window just returns the same first page.)
- Skip candidates that already have:
  - another user assigned (don't co-assign onto someone else's work),
  - an **open** PR attached. The precise check is
    `gh issue view <n> --json closedByPullRequestsReferences --jq
    '[.closedByPullRequestsReferences[] | select(.state=="OPEN")] | length'`
    — non-zero means an open PR is already in flight. Issues whose only
    linked PR was closed without merging stay eligible. Fall back to
    `gh pr list --search "<n> in:body"` only when the field is
    unavailable (substring-matches; false-positives on overlapping numbers
    like `#123` matching `1234`).
  - any of these labels: `wontfix`, `duplicate`, `blocked`.

- **Capture a baseline** before delegating tracks. Run the project's verify
  command once on `$DEFAULT` (or read CI's last-green status) so a
  pre-existing red is not misattributed to a track. Per
  `@references/task-execution.md`: "a pre-existing red must never be
  mistaken for one you caused."
- **Minor & actionable** = no design decisions left, narrow scope, behavior-
  preserving or well-bounded, clear acceptance criteria. Good: doc/config dead
  refs, single-function hardening, small fixes. Skip: epics, broad mechanical
  renames, anything still marked 要検討 / TBD without a chosen approach.
- If nothing qualifies, say so and stop — do not force trivial busywork.

## Step 2 — Plan parallelism (worktrees)

- **Determine each candidate issue's likely file set before grouping.** For
  small batches (≤5 candidates), run a single batched `code-explore` pass
  ("for each of these N issues return the affected paths"). For larger or
  non-trivial-per-issue batches, delegate one `code-explore` per issue.
  Use the resulting sets to compute the disjoint groups. Do not guess.
- **Two issues can run in parallel only if their file sets are disjoint.**
  Issues touching the same source file must be **sequential** — defer the
  later track to a follow-up run. Do not poll-then-resume in the same run;
  re-orchestrating after an arbitrary wait re-enters the Step-1 selection
  flow cleanly.
- Resolve the repo's default branch (`master`, `main`, or other) before
  branching — do not hardcode `main`. If `gh` is unauthenticated or the
  remote is non-GitHub, fall back to `origin/HEAD`:
  ```bash
  DEFAULT=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null \
    || git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')
  ```
- Create one worktree per parallel track from the latest `$DEFAULT`. Use a
  repo-scoped temp dir keyed by issue number so parallel runs and reruns don't
  collide:
  ```bash
  REPO=$(git rev-parse --show-toplevel); SLUG=$(basename "$REPO")
  WT="${TMPDIR:-/tmp}/wt-$SLUG-issue-<n>"
  ```

  **Once-per-run pre-flight (BEFORE any parallel fan-out).** Check the
  primary checkout. If dirty (`[ -n "$(git -C "$REPO" status
  --porcelain)" ]`), surface via `AskUserQuestion`:
  - `abort` → stop the run.
  - `stash and continue` → run, *exactly one time* for the whole run:
    ```bash
    RUN_ENV="<scratchpad>/tackle-issues/run.env"
    mkdir -p "$(dirname "$RUN_ENV")"
    STASH_ID="tackle-issues-$(git -C "$REPO" rev-parse --short HEAD)-run"
    git -C "$REPO" stash push -u -m "$STASH_ID"
    printf 'STASH_ID=%q\n' "$STASH_ID" > "$RUN_ENV"
    ```
    Persisting to the scratchpad state file (not just a bash variable) is
    required — Step 5 may execute many turns later, after compaction.
    Per-track blocks below MUST NOT re-stash.

  Also once-per-run: update the local remote-tracking ref for the default
  (refspec-style fetch would fail when `$DEFAULT` is currently checked out
  in the primary — the common case; this leaves the primary's HEAD alone):

  ```bash
  git -C "$REPO" fetch origin "$DEFAULT"
  ```

  Do NOT call `exit` (the skill body runs in the main bash session).

  **Per-track block (runs once per parallel/sequential track).** Create the
  worktree directly from the remote ref. Do not re-fetch — the once-per-run
  fetch above already updated `refs/remotes/origin/$DEFAULT`.

  ```bash
  # Check for collisions on both the worktree path and the branch name —
  # a prior aborted run can leave either. Surface to the user via
  # AskUserQuestion with these concrete behaviors:
  #   - refuse  : stop the run; user resolves manually
  #   - replace : git worktree remove --force "$WT" && git branch -D <branch>
  #               (only when MERGED upstream or user confirms loss)
  #   - suffix  : RUNID=$(date +%s); WT="${WT}-${RUNID}"; <branch>="<branch>-${RUNID}"
  branch_exists=$(git -C "$REPO" show-ref --quiet "refs/heads/<branch>" && echo 1 || echo 0)
  if [ -e "$WT" ] || [ "$branch_exists" = "1" ]; then
    : # AskUserQuestion with the three concrete behaviors above
  fi
  git worktree add -b <branch> "$WT" "origin/$DEFAULT"
  # If a fresh checkout needs toolchain activation, do the project's
  # equivalent in "$WT" (e.g. `mise trust`, `direnv allow`, entering a
  # devcontainer). Skip if the repo needs none.
  ```
- **Share heavy, regenerable build artifacts** with the main checkout so deps
  don't need reinstalling and the build doesn't restart from scratch — whatever
  this project's stack uses: a dependency dir (`node_modules`, `vendor/`, a
  virtualenv, …) and/or a build cache (a Rust `target/`, Go build cache, etc.).
  Link or point each at the primary checkout's copy. Examples (use only what
  the repo actually has):
  - npm/yarn deps: `ln -s "$REPO/node_modules" "$WT/node_modules"`
    (workspaces also need their per-package `node_modules` linked, or use
    a shared store)
  - pnpm: the symlink trick is fragile (the store is a tree of relative
    symlinks into `.pnpm/`); prefer `PNPM_STORE_PATH` pointing at a shared
    store and re-run `pnpm install --prefer-offline` in the worktree.
  - Rust build cache: `CARGO_TARGET_DIR=<the repo's actual target dir>`

  Concurrency is safe per-stack because each tool locks its own cache
  (Cargo flocks `target/`, pnpm locks the store) and minor-issue tracks
  rarely run `install`. (`$REPO` = the primary working directory.)
- **Claim each issue when starting.** As a track begins (create its
  branch/worktree), assign the issue to yourself so the in-progress owner is
  visible: `gh issue edit <n> --add-assignee @me`. Do this for every issue —
  sequential or parallel — before implementing.
- **Each parallel track runs in its own subagent.** Hand one issue per worktree
  to `implementer` (clear, localized) or `heavy-implementer` (multi-file /
  debug-from-symptoms), passing the worktree path, the issue number, the verify
  commands, the commit policy ("if your diff spans more than one intent, the
  orchestrator will route it through `/commit`; otherwise stop after verify
  green and the orchestrator will one-shot-commit with the `Closes #<n>`
  trailer"), and the report contract (files changed + verification results,
  no diffs). Send all parallel tracks in a single message so they run
  concurrently. Same-file overlaps are deferred to a follow-up run (see
  above) — they are not queued in this run.

### Track verify-failure handling

If a track reports verify red, the orchestrator does **not** open a PR for
it. Default behavior: leave the worktree and branch in place for triage,
and **unassign the issue** so the claim doesn't dangle:

```bash
gh issue edit <n> --remove-assignee @me
```

Surface the failure to the user with the worktree path. Same policy applies
to any failure that exits before merge (`gh pr create` errors, conflict
detection, etc.). The MERGED path is the only one that completes the
implicit assignment.

## Step 3 — Implement + verify (per worktree)

- Make the change; match surrounding style; add/adjust tests.
- Verify only the stack the change touches, using **that stack's** standard
  format / lint / typecheck / test commands as the project defines them, invoked
  the repo's own way (see "Use the repo's own way of running commands" above —
  wrapper/prefix and all). The set depends on the architecture — figure out what
  this repo actually uses; don't assume. For orientation only:
  - Rust crate: `cargo fmt --check` / `cargo clippy -- -D warnings` / `cargo test`
  - JS/TS package: the `package.json` scripts (often `typecheck` / `lint` / `test`)
  - Go module: `gofmt -l` / `go vet` / `go test`
  - Python: the configured formatter + linter + `pytest`
- The green bar is **this repo's own** format/lint/test config. If the project
  documents a known pre-existing warning, don't block on that one — but don't
  assume one exists; verify against this repo and treat a clean run as required.

## Step 4 — PR + auto-merge (only when green)

For each track, anchor every git/gh call to the worktree via `git -C "$WT"`
(or `cd "$WT"` first):

```bash
cd "$WT"                              # or anchor every call with `git -C "$WT"`
git -C "$WT" add <files...>          # individual files, never -A/.
# Prefer `/commit` when the working tree spans more than one intent.
# For a single-intent change, use a one-shot commit with `Closes #<n>`
# as a trailer (per @references/git-workflow.md), not in the subject:
git -C "$WT" commit -m "$(cat <<'EOF'
<type>(<scope>): <subject>

Closes #<n>

Co-Authored-By: Claude MODEL <noreply@anthropic.com>
EOF
)"
# Substitute MODEL with the executing model's human-readable name (e.g.
# `Opus 4.7`, `Sonnet 4.6`) per git-workflow.md. Do not leave brackets
# around it — `<model>` confuses git's trailer parser.
git -C "$WT" push -u origin <branch>
gh pr create --base "$DEFAULT" --head <branch> --title "..." --body "$(cat <<'EOF'
... Closes #<n> ...

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Then merge via GitHub's auto-merge so it lands once required checks pass
(verification already green locally; CI may still be running):

```bash
gh pr merge <pr> --merge --delete-branch --auto
```

Fallback ladder if `gh pr merge --auto` errors:
- auto-merge disabled on the repo → drop `--auto` and merge synchronously
  after `gh pr checks <pr> --watch --fail-fast` reports green.
- merge commits disabled too → use `--rebase` (preserves each
  intent-separated commit). If `--rebase` is also disabled and the PR is a
  single atomic commit, use `--squash`. If the PR is multi-commit AND only
  `--squash` is allowed, STOP and report — squashing would collapse
  intent-separated commits.
- PR blocked by conflict or a failing check → STOP on that one and report.
  Do not force.

## Step 5 — Clean up (only after the PR's merge actually fires)

`gh pr merge --auto` queues the merge until checks pass; do **not** delete
the local branch/worktree until the PR has actually merged. Branch on the
state:

```bash
STATE=$(gh pr view <pr> --json state -q .state)    # MERGED | OPEN | CLOSED
```

- **MERGED** → run the cleanup block below.
- **OPEN** → defer cleanup and **end this run** with the worktree
  preserved. Report the deferred state to the user (PR number, worktree
  path, stash id if any) AND the exact cleanup commands to run once the
  PR finally merges:
  ```
  git -C "$REPO" worktree remove "$WT"
  git -C "$REPO" worktree prune
  git -C "$REPO" branch -D <branch>
  git -C "$REPO" fetch origin "$DEFAULT"
  # If stashed: STASH_REF=$(git -C "$REPO" stash list | grep -F "<stash-id>" | head -1 | cut -d: -f1) && git -C "$REPO" stash pop "$STASH_REF"
  ```
  The worktree and branch are the recovery path if CI later fails
  (`gh pr checkout <pr>` after the fact loses the local cache). Do not
  poll-then-resume in the same run.
- **CLOSED** (closed without merging) → STOP and surface to the user
  immediately. Do not loop. The worktree and branch are preserved for
  manual triage.

When MERGED, primary HEAD was not switched — no restore needed. Run:

```bash
git -C "$REPO" worktree remove "$WT"  # plain remove; --force only as fallback
                                      # for incomplete cleanup
git -C "$REPO" worktree prune
git -C "$REPO" branch -D <branch>     # local branch (remote was auto-deleted
                                      # by --delete-branch when the merge fired)
git -C "$REPO" fetch origin "$DEFAULT"   # update refs/remotes/origin/$DEFAULT
                                          # without disturbing primary HEAD
# Source the persisted STASH_ID (Step 2's pre-flight wrote it; bash
# variables don't survive across Bash tool calls / compaction):
RUN_ENV="<scratchpad>/tackle-issues/run.env"
[ -f "$RUN_ENV" ] && . "$RUN_ENV"

# Pop the run-level stash at most once. The popped-flag lives in run.env
# itself (NOT a fixed-name sentinel) so it dies with this run and never
# blocks a later session-scoped run with the same scratchpad:
if [ -n "${STASH_ID:-}" ] && [ -z "${POPPED:-}" ]; then
  STASH_REF=$(git -C "$REPO" stash list | grep -F "$STASH_ID" | head -1 | cut -d: -f1)
  if [ -n "$STASH_REF" ]; then
    git -C "$REPO" stash pop "$STASH_REF"
    printf 'POPPED=1\n' >> "$RUN_ENV"
  fi
  # If no STASH_REF and POPPED is unset, surface "stash $STASH_ID missing".
fi
```

If shared dependency/cache dirs were symlinked into the worktree, verify
each one in the primary checkout survived removal. Check whichever dirs
were wired up, e.g.:
`[ -d "$REPO/node_modules" ] && [ ! -L "$REPO/node_modules" ]` for
npm/yarn deps,
`[ -d "$REPO/vendor" ] && [ ! -L "$REPO/vendor" ]` for `vendor/`,
`[ -d "$REPO/target" ] && [ ! -L "$REPO/target" ]` for the Rust target
dir, etc.

## Step 6 — Report

Table of issue → PR → state, the parallel layout used, and any issues
**deferred** (e.g. same-file conflicts that should wait for a merge). Offer the
next safe candidate.

If this run happened to land thematically related PRs (rare for a backlog
burndown), suggest running `/suggest-harness` to fold lessons back in.
Otherwise skip.
