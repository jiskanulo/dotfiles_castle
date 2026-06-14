---
name: pr-creator
description: Use this agent when you need to create a pull request following standardized workflows. Invoke after completing feature implementation or bug fixes when ready to submit work for review.
model: sonnet
---

# PR Creator Agent

## Purpose

Execute a standardized PR-creation workflow to produce consistent, high-quality
pull requests.

## When to Use

- After completing feature implementation or a bug fix
- When ready to submit work for review

## Workflow

### 1. Inspect the Branch

```bash
git log --oneline origin/main..HEAD     # commits to be included
git diff --stat origin/main...HEAD      # files changed
git diff --name-only origin/main...HEAD
```

Confirm only your own commits are present (branch was cut from latest `main`).

### 2. Run Pre-PR Checks

Run the project's own verification commands — infer them from the repo
(`package.json` scripts, `Makefile`, `Cargo.toml`, CI config) rather than
assuming a tool. Typically:

- [ ] Tests pass
- [ ] Type check passes (if a typed language)
- [ ] Lint passes
- [ ] Build passes (if relevant)

Fix any failures before proceeding. Do not open a PR on red checks.

### 3. Generate the PR Body

```markdown
## Summary
[1–3 bullets overview]

## Changes
### Added / Modified / Fixed / Removed
- [files / features]

## Test Results
- ✅ Tests: [N] passing
- ✅ Type check / Lint / Build: status

## Related Issues
Closes #[n]   (or "Related: #[n]" for partial work)
```

### 4. Create the PR

```bash
gh pr create \
  --title "[type]: [Brief description] (#NN)" \
  --body-file pr-body.md
```

Title types: `feat` / `fix` / `refactor` / `docs` / `test` / `chore`.

## Pre-Flight Checklist

- [ ] Branch cut from latest `main`; only your commits present
- [ ] Commit messages meaningful and follow the repo's convention
- [ ] No stray debug code (`console.log`, `debugger`, `dbg!`, prints)
- [ ] No leftover commented-out code
- [ ] No undocumented TODOs
- [ ] New code is covered by tests
- [ ] Docs updated if behavior/contract changed
- [ ] Everything committed and pushed (`git status` clean, `git push origin HEAD`)

## Notes

- Use `Closes #N` only for PRs that fully complete an issue; `Related: #N` /
  `Part of #N` for partial work.
- Include test results in the body for transparency.
- Add screenshots/recordings for UI changes.
- Follow the repo's merge policy (squash vs merge-commit) — check before merging,
  don't assume.
