# Git workflow — commit granularity

How to stage and commit changes so each commit is reviewable, bisectable, and
revertible. Loaded via `@references/git-workflow.md` from `CLAUDE.md`; it
expands the `# Git Commits` section there. Pairs with
`@references/task-execution.md` (atomic units of work).

## Principle

One commit = one *kind* of change. Mixed commits destroy reviewability,
bisectability, and safe revert. The discipline to split is the discipline to
think — if you can't name one category, the commit isn't ready.

## Atomic unit definition

A commit's category is its *intent*: `feat`, `fix`, `refactor`, `chore`,
`docs`, `test`. One commit, one intent.

Violations — split these into separate commits:

| Scenario | Right split |
| -------- | ----------- |
| New Rust dotfile + edit `.claude/settings.json` | `feat(rust)` then `chore(claude)` |
| Rename variable (refactor) + add new method (feat) in same file | `refactor:` then `feat:` |
| Fix a bug while adding a feature | `fix:` then `feat:` |
| Update deps + change behavior | `chore(deps)` then `feat:` / `fix:` |

Same file is not the same commit if the intents differ.

## Workflow

1. **Default to `git add -p`** — patch-select hunks, never `git add -A` or
   `git add .`. Blanket staging encourages mixing.
2. **Inspect before committing** — run `git diff --staged` to confirm the
   staged set matches exactly one intent. If it doesn't, unstage and re-split.
3. **Order: refactor → feat.** Land preparatory / rename commits first so the
   feat commit's diff is minimal and review-friendly. Never let a feat commit
   carry along refactor noise.
4. **Verify after each commit** — run the project's check (build / lint /
   test) so a bad commit is caught immediately, not buried.

## Message conventions

```
<type>(<scope>): <imperative summary, ≤72 chars>

[optional body: why, not what]

Co-Authored-By: Claude <model> <noreply@anthropic.com>
```

- Types: `feat` `fix` `refactor` `chore` `docs` `test` `perf` `ci`
- Scope: optional, lowercase, matches affected path/module
- Summary: imperative mood ("add", "fix", "remove" — not "added", "fixes")
- Language: English (see Communication Style in CLAUDE.md — don't duplicate here)
- Footer: always include the `Co-Authored-By` line for Claude-assisted commits.
  `<model>` is the current model id (e.g. `Opus 4.7`, `Sonnet 4.6`) — never hard-code

## When to pause / escalate

- A single hunk genuinely mixes categories (e.g., a bug fix is inseparable
  from a refactor) → surface to user via AskUserQuestion rather than guessing
  which category wins.
- Unsure whether two changes belong to the same `feat` or are two separate
  `feat` → err toward splitting; ask if the boundary isn't obvious.
- Never invent a catch-all commit to batch unrelated work under "misc" or
  "chore" — that is the violation, not a workaround.
