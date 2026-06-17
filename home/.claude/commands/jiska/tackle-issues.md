---
description: Pick minor, actionable open issues and implement them end-to-end (branch → verify → PR → auto-merge). Parallelize independent issues with git worktrees.
argument-hint: "[optional: issue numbers to target, e.g. 247 238 — default: auto-pick minor ones]"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# Tackle Minor Issues (parallel via worktrees)

Reproduce the standing flow: judge which open issues are **minor and actionable**,
implement them, and — when verification is green — open PRs and **auto-merge**.
Run **independent** issues in parallel using git worktrees.

This command is project-agnostic: discover each repo's actual architecture,
conventions, and toolchain at run time rather than assuming any specific stack,
files, or tools exist. The examples below (Rust/cargo, JS/pnpm) are illustrative
— substitute whatever this repo actually uses.

`$ARGUMENTS`: optional explicit issue numbers. If empty, auto-pick minor ones.

## Conventions to follow

- Read the project's workflow rules before starting — at minimum
  `.claude/rules/git-workflow.md` if present (branch-from-main, individual
  `git add`, commit granularity/format, `Closes #N`). Also read **any other
  convention docs the repo ships** (e.g. under `.claude/rules/`, or a
  `CONTRIBUTING.md` / `CLAUDE.md`): coding standards, framework patterns, etc.,
  and honor them. Do not assume a doc exists — check first.
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

- `gh issue list --state open` and read candidates (`gh issue view <n>`).
- **Minor & actionable** = no design decisions left, narrow scope, behavior-
  preserving or well-bounded, clear acceptance criteria. Good: doc/config dead
  refs, single-function hardening, small fixes. Skip: epics, broad mechanical
  renames, anything still marked 要検討 / TBD without a chosen approach.
- If nothing qualifies, say so and stop — do not force trivial busywork.

## Step 2 — Plan parallelism (worktrees)

- **Two issues can run in parallel only if their file sets are disjoint.**
  Issues touching the same source file must be **sequential** — do the second
  only after the first merges. Call this out.
- Create one worktree per parallel track from the latest `main`. Use a
  repo-scoped temp dir so parallel runs across different projects don't collide:
  ```bash
  REPO=$(git rev-parse --show-toplevel); SLUG=$(basename "$REPO")
  WT=/tmp/wt-$SLUG-<n>
  git checkout main && git pull
  git worktree add -b <branch> "$WT" main      # <branch> per git-workflow.md naming
  # If a fresh checkout needs toolchain activation, do the project's equivalent
  # in "$WT" (e.g. `mise trust`, `direnv allow`, entering a devcontainer). Skip
  # if the repo needs none.
  ```
- **Share heavy, regenerable build artifacts** with the main checkout so you
  don't reinstall deps or recompile from scratch — whatever this project's stack
  uses: a dependency dir (`node_modules`, `vendor/`, a virtualenv, …) and/or a
  build cache (a Rust `target/`, Go build cache, etc.). Link or point each at the
  primary checkout's copy. Examples (use only what the repo actually has):
  - JS deps: `ln -s "$REPO/node_modules" "$WT/node_modules"`
  - Rust build cache: `CARGO_TARGET_DIR=<the repo's actual target dir>`

  Commands run sequentially, so there's no cache-lock contention.
  (`$REPO` = the primary working directory.)
- **Claim each issue when you start it.** As you begin a track (create its
  branch/worktree), assign the issue to yourself so the in-progress owner is
  visible: `gh issue edit <n> --add-assignee @me`. Do this for every issue you
  start — sequential or parallel — before implementing.

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

For each track:

```bash
git add <files...>                 # individual files, never -A/.
git commit -m "<type>: ... (Issue #<n>)"   # footer per git-workflow.md
git push -u origin <branch>
gh pr create --title "..." --body "... Closes #<n> ..."
```

Then confirm mergeable and **auto-merge** (verification already green this run):

```bash
gh pr view <pr> --json mergeable,mergeStateStatus   # expect MERGEABLE/CLEAN
gh pr merge <pr> --merge --delete-branch
```

If a PR is not CLEAN (conflict/checks), stop on that one and report — do not
force.

## Step 5 — Clean up

```bash
git worktree remove "$WT" --force    # removes the dir incl. any symlinked
                                     # shared cache dir, not its target
git worktree prune
git branch -D <branch>                # local branch (remote auto-deleted)
git checkout main && git pull          # sync
```

If you symlinked a shared dependency/cache dir into the worktree, verify the
real one survived removal (e.g. `[ -d node_modules ] && [ ! -L node_modules ]`).

## Step 6 — Report

Table of issue → PR → state, the parallel layout used, and any issues
**deferred** (e.g. same-file conflicts that should wait for a merge). Offer the
next safe candidate.
