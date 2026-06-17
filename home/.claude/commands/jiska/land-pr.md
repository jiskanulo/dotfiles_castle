---
description: Open a PR for the current branch and land it (push → gh pr create → merge commit → delete branch → sync default). The issue-less counterpart to tackle-issues, for when you already have a committed branch.
argument-hint: "[optional: PR title — defaults to the branch's latest commit subject]"
allowed-tools: Bash
---

# Land the current branch as a PR

Take the current feature branch, open a PR against the default branch, and merge
it — the standard branch+PR workflow for this kind of repo.

## Preconditions
- Must be on a **feature branch**, not the default branch. If on the default
  branch, STOP and tell the user to branch first — work shouldn't start there.
- The branch must have commits not yet on the default branch.

## Steps
1. Default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`.
   Confirm the current branch is not it.
2. Push: `git push -u origin <branch>`.
3. Create the PR: `gh pr create --base <default> --head <branch> --title "<title>"
   --body "<short body summarizing the commits>"`. Title = `$ARGUMENTS` if given,
   else the branch's latest commit subject. End the body with the Claude Code
   attribution line.
4. **CI gate**: if the repo has required status checks, wait for them to pass
   before merging. If there is no CI yet, merge immediately.
5. Merge with a **merge commit**, preserving the intent-separated commits the PR
   was split into: `gh pr merge <n> --merge --delete-branch`. Do **not** use
   `--rebase` (disabled on some repos) or `--squash` (collapses intent commits).
6. Sync: `git switch <default> && git pull --ff-only`.
7. Report the PR URL and the merge result.

## Notes
- Issue-less counterpart to `/jiska:tackle-issues` (which picks issues and runs
  branch → verify → PR → merge). Use this when a committed branch already exists.
- Don't run `rm` for cleanup; leave any temp artifacts in place.
