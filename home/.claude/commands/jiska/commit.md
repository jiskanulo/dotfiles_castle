---
description: Split the current working-tree changes into atomic commits, one per kind of change (feat / fix / refactor / chore / …). Shows the proposed split and asks for approval before touching the index.
argument-hint: "[optional: hint about intended grouping, e.g. 'keep zsh and tmux separate']"
allowed-tools: Bash
---

# Atomic Commit Split

Split dirty working-tree changes into intent-separated commits. Each commit is
one kind of change; the user approves the plan before any `git add` runs.

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
categories, **stop and ask** via AskUserQuestion rather than guessing.

Preferred ordering: `refactor`/`chore` → `fix` → `feat` (preparatory commits
before the changes that depend on them). Explain any reordering in the plan.

## Step 2 — Propose to the user (STOP here for approval)

Present each proposed commit as a numbered list:

```
1. refactor(zsh): extract common path helpers
   Files: home/.config/zsh/function/cdd, home/.config/zsh/function/cdw
   Hunks: all changes in both files

2. feat(zsh): add y wrapper for yazi cwd handoff
   Files: home/.config/zsh/function/y (new)
   Hunks: entire new file
```

Then ask via AskUserQuestion: "このプランで進めますか？変更・再分割があれば教えてください。"

Do **not** touch the index until the user approves. If the user asks to re-split
or rename a commit, revise the plan and re-ask.

## Step 3 — Stage and commit one group at a time

For each approved commit in order:

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
- If a hunk mixes categories: **stop and ask**, don't guess.
- Commit message language: English. Conversation with user: Japanese.
