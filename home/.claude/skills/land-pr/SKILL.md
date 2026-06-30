---
name: land-pr
description: This skill should be used when the user asks to "open a PR", "land PR", "ship this branch", "land this branch", "create and merge PR", or wants to push the current feature branch and merge it via PR (or resume an existing open PR for the branch). Pushes the branch, opens a PR against the default branch, waits for any CI gate, merges with --merge (preserving intent-separated commits), deletes the branch, and syncs the default. Issue-less counterpart to tackle-issues.
---

# Land the current branch as a PR

Push the current feature branch, open (or resume) a PR against the default
branch, wait for any CI to go green, and merge with a merge commit.

**Concatenate every fenced Bash block below into a single Bash tool call** —
shell variables (`default`, `branch`, `n`, etc.) don't persist across calls.
If you need to drop out for `AskUserQuestion` (title resolution), the
Preconditions and Existing-PR check blocks must be re-run on re-entry; the
checks are idempotent.

## Preconditions

```bash
set -e
default=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
branch=$(git symbolic-ref --short HEAD)
[ "$branch" = "$default" ] && { echo "on $default; branch first"; exit 1; }
[ "$(git rev-list --count "$default..HEAD")" -gt 0 ] || { echo "no commits ahead of $default"; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "tracked changes uncommitted; commit or stash"; exit 1; }
```

## Existing-PR check (resume if OPEN, stop if not)

```bash
set -e
existing=$(gh pr list --head "$branch" --state all --json state,number)
existing_state=$(jq -r '.[0].state // empty' <<<"$existing")
existing_n=$(jq -r '.[0].number // empty' <<<"$existing")
case "$existing_state" in
  OPEN)     n="$existing_n"; resume=1 ;;
  MERGED|CLOSED) echo "PR #$existing_n is $existing_state; surface to user"; exit 1 ;;
  "")       resume=0 ;;
esac
```

## Title and test-plan resolution (decide before creating)

Resolve both **before** the next Bash block so the placeholders don't leak
into the PR body:

- **Title**. If the user gave a title in their request, use it. Otherwise,
  when the branch has exactly one commit ahead of `$default`, use that
  commit subject: `title=$(git log "$default..HEAD" -1 --format=%s)`. With
  two or more commits and no user-given title, STOP and ask the user for
  one via `AskUserQuestion` before re-entering the Bash flow (re-run the
  Preconditions and Existing-PR check blocks on re-entry).
- **Test plan step(s)**. Use the verification command(s) the user named, or
  the repo's documented verify command(s) (`pnpm test`, `cargo test`, the
  CI script — whatever the project actually uses). If the answer is genuinely
  unknown, ask the user via `AskUserQuestion` before continuing.

Both must be resolved to concrete strings before the create-PR block runs.

## Steps

```bash
set -e
# title and testplan must be set by Title-resolution / Test-plan-resolution
# above (concrete strings, not placeholders). Fail fast if missing:
: "${title:?title required (see Title resolution)}"
: "${testplan:?testplan required (see Test plan resolution)}"

git push -u origin "$branch"           # 1. push (fails on non-fast-forward;
                                        #    do not auto --force)

if [ "$resume" -eq 0 ]; then           # 2. create PR (skip on resume)
  summary=$(git log "$default..HEAD" --format='- %s')
  url=$(gh pr create --base "$default" --head "$branch" --title "$title" \
    --body "$(printf '## Summary\n%s\n\n## Test plan\n%s\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n' "$summary" "$testplan")")
  n="${url##*/}"
fi

# 3. CI gate. gh pr checks --watch exits 0 immediately when no checks are
#    registered, which doubles as the "no CI configured" path.
for _ in 1 2 3 4 5 6; do
  [ "$(gh pr checks "$n" --json state --jq 'length')" -gt 0 ] && break
  sleep 5
done
gh pr checks "$n" --watch --fail-fast || { echo "CI failed; do not merge"; exit 1; }

# 4. Merge with merge commit; --delete-branch removes remote + local.
gh pr merge "$n" --merge --delete-branch

# 5. Sync the default.
git switch "$default" && git pull --ff-only && git fetch --prune
echo "Merged: $(gh pr view "$n" --json url -q .url)"
```

## Notes

- Issue-less counterpart to `tackle-issues` (which selects issues and runs
  branch → verify → PR → merge). Use this when a committed branch already
  exists.
- Do **not** use `--rebase` (disabled on some repos) or `--squash`
  (collapses intent-separated commits).
- For fork PRs, `gh pr list --head` may need `owner:branch`; not handled here.
