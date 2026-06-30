---
name: commit
description: This skill should be used when the user asks to "commit", "make a commit", "commit changes", "split commits", "atomic commit", or wants intent-separated commits from a dirty working tree. Splits working-tree changes into one-kind-per-commit groups (feat/fix/refactor/chore/...), announces the proposed split, then commits without further confirmation.
argument-hint: "[optional: hint about intended grouping, e.g. 'keep zsh and tmux separate']"
allowed-tools: Bash, Read, AskUserQuestion
---

# Atomic Commit Split

Split dirty working-tree changes into intent-separated commits. Each commit is
one kind of change. The proposed split is announced before staging, then
applied without further confirmation.

## Preconditions

Run `git status`, `git diff`, and `git diff --staged`. If the tree is clean
(nothing staged or unstaged), stop and say so. If there are already staged
changes, stop and use AskUserQuestion to ask the user how to handle them
(options: unstage / abort) — do not silently fold them into commit #1.

## Step 1 — Classify hunks

Classification types, ordering, and escalation rules all live in
`~/.claude/references/git-workflow.md` — read it before classifying. If that
file does not exist, stop and ask the user how to classify.

For untracked files, run `git add -N <file>` first so the new content appears
in `git diff HEAD` and can be patch-staged in Step 3.

Honor any grouping hint the user included in their request (e.g. "keep zsh
and tmux separate") when forming groups.

Read the full diff (`git diff HEAD`) and classify every changed file/hunk.
Add a scope when it helps (`feat(zsh):`, `chore(tmux):`). If a single hunk
genuinely mixes two categories, follow the escalation rule in git-workflow.md
(AskUserQuestion rather than guess). Apply the refactor→feat ordering rule
from git-workflow.md, and explain any reordering in the plan.

## Step 2 — Announce the plan

Print each proposed commit as a numbered list, then proceed straight to Step
3 — no approval gate. The user sees the plan in chat and can interrupt or
roll back if it's wrong.

```
1. refactor(zsh): extract common path helpers
   Files: home/.config/zsh/function/cdd, home/.config/zsh/function/cdw
   Hunks: all changes in both files

2. feat(zsh): add y wrapper for yazi cwd handoff
   Files: home/.config/zsh/function/y (new)
   Hunks: entire new file
```

If Step 1 escalated a mixed hunk to the user, note the resolution here
(e.g. "hunk in `foo.rs` mixes fix + refactor — user chose `fix`").

## Step 3 — Stage and commit one group at a time

For each commit in order:

1. Stage with `git add -p <file>` by default. `git add <file>` is allowed
   **only** when every hunk in that file belongs to this commit's intent.
   **Never use `git add -A` or `git add .`.**
2. Verify staging: `git diff --staged` must contain **only** the intended hunks.
   If anything extra crept in, unstage it with
   `git restore --staged --patch <file>` (hunk-level) or
   `git restore --staged <file>` (whole file) and redo.
3. Commit. Compose the message per git-workflow.md §Message conventions
   (including the Co-Authored-By trailer rules). Use this shell pattern:
   ```
   git commit -m "$(cat <<'EOF'
   ...message per git-workflow.md...
   EOF
   )"
   ```
   Never use `--amend` or `--no-verify`.

4. After each commit: `git log --oneline -1` + `git show --stat HEAD` so the
   result is visible before moving to the next group. git-workflow.md mandates
   a per-commit check; this skill intentionally defers that to the caller —
   run build/test once after the full split lands, not between each commit,
   to keep the split fast.

## Step 4 — Final report

List every commit made:

```
SHA  type(scope): subject
SHA  type(scope): subject
…
Total: N commits.
```

Do not include a rollback procedure in the final report.

Report in Japanese; commit messages in English.

## Constraints (always enforce)

- `git add -A` / `git add .` — **never**.
- `git commit -a` / `git commit --all` — **never** (defeats per-hunk staging).
- `--amend` — **never** (matches the standing safety protocol).
- `--no-verify` — **never**.
- Commit message language: English. Conversation with user: Japanese.
