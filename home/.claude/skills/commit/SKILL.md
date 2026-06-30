---
name: commit
description: This skill should be used when the user asks to "commit", "make a commit", "commit changes", "split commits", "atomic commit", or wants intent-separated commits from a dirty working tree. Splits working-tree changes into one-kind-per-commit groups (feat/fix/refactor/chore/...), announces the proposed split, then commits without further confirmation.
argument-hint: "[optional: hint about intended grouping, e.g. 'keep zsh and tmux separate']"
allowed-tools: Bash
---

# Atomic Commit Split

Split dirty working-tree changes into intent-separated commits. Each commit is
one kind of change. The proposed split is announced before staging, then
applied without further confirmation — roll back with `git reset --soft HEAD~N`
if the classification was wrong.

## Preconditions

Run `git status`, `git diff`, and `git diff --staged`. If the tree is clean
(nothing staged or unstaged), stop and say so. If there are already staged
changes mixed with unstaged, warn the user before proceeding.

## Step 1 — Classify hunks

Read the full diff (`git diff HEAD`) and group every changed file/hunk into one
of these conventional-commit types:

`refactor` / `chore` / `fix` / `feat` / `docs` / `test` / `style` / `perf` /
`build` / `ci`

Add a scope when it helps (`feat(zsh):`, `chore(tmux):`). Classification rules
live in `~/.claude/references/git-workflow.md` — read that file if it exists;
do not duplicate its rules here. If a single hunk genuinely mixes two
categories, pick the dominant one and call it out in the announcement
(Step 2) so the user can roll back with `git reset --soft HEAD~N` if the
call was wrong.

Preferred ordering: `refactor`/`chore` → `fix` → `feat` (preparatory commits
before the changes that depend on them). Explain any reordering in the plan.

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

If Step 1 picked a dominant category for a mixed hunk, note that here
(e.g. "hunk in `foo.rs` mixes fix + refactor — classified as `fix`").

## Step 3 — Stage and commit one group at a time

For each commit in order:

1. Stage with `git add -p <file>` by default. `git add <file>` is allowed
   **only** when every hunk in that file belongs to this commit's intent.
   **Never use `git add -A` or `git add .`.**
2. Verify staging: `git diff --staged` must contain **only** the intended hunks.
   If anything extra crept in, unstage (`git restore --staged <file>`) and redo.
3. Commit:
   ```
   git commit -m "$(cat <<'EOF'
   <type>(<scope>): <subject>

   Co-Authored-By: Claude <model> <noreply@anthropic.com>
   EOF
   )"
   ```
   `<model>` = the actual model name (e.g. `claude-sonnet-4-6`).
   Never use `--amend` or `--no-verify`.

4. After each commit: `git log --oneline -1` + `git show --stat HEAD` so the
   result is visible before moving to the next group.

## Step 4 — Final report

List every commit made:

```
SHA  type(scope): subject
SHA  type(scope): subject
…
Total: N commits.
To roll back all of them: git reset --soft HEAD~N
```

Report in Japanese; commit messages in English.

## Constraints (always enforce)

- `git add -A` / `git add .` — **never**.
- `--amend` — **never** (matches the standing safety protocol).
- `--no-verify` — **never**.
- Commit message language: English. Conversation with user: Japanese.
