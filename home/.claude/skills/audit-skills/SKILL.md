---
name: jiska-audit-skills
description: Audit Agent Skills against the official best-practices spec — frontmatter validation (name regex, description length, third-person), body length, progressive disclosure, time-sensitive content, path conventions. Classifies findings by severity (spec violation / best-practice deviation / improvement) and applies fixes only after per-tier approval. Use to verify a skill set is publish-ready or spec-compliant, or before sharing skills via the API/SDK.
argument-hint: "[scope: paths/globs to SKILL.md files; default: all under .claude/skills/ in the repo and ~/.claude/skills/]"
allowed-tools: Read, Grep, Glob, Bash, WebFetch, Edit
---

# Audit Skills against Best Practices

Verify Agent Skills follow the official spec. Report violations and improvements
grouped by severity; apply fixes only after the user explicitly approves each
tier. Pair with `/jiska-commit` afterward for the atomic commit split.

## Preconditions

Resolve scope from `$ARGUMENTS`:

- Empty (default) → every `**/SKILL.md` under `.claude/skills/` in the current
  repo **and** `~/.claude/skills/`. De-duplicate when this repo IS the dotfiles
  source for `~/.claude/`.
- One or more paths/globs → exactly those SKILL.md files.

If the resolved set is empty, stop and say so. Include this skill itself in
the default scope — no special-casing.

## Step 1 — Fetch the current spec

WebFetch each run (the spec evolves):

```
https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
```

Extract the checklist at the bottom plus the frontmatter validation rules.
The 15-minute WebFetch cache covers repeat runs in the same session.

**Backstop rules** (apply even if the fetch fails or omits them):

- `name`: max 64 chars, **only lowercase letters, digits, and hyphens** —
  no colon, underscore, uppercase, or any other character; no XML tags;
  cannot contain reserved words `anthropic` or `claude`.
- `description`: 1–1024 chars, third-person ("Extracts X"; not "I extract" or
  "You can extract"), describes both what + when, no XML tags.
- Body: ≤500 lines recommended; >1000 lines is a hard usability problem.
- Forward slashes only in paths.
- File references one level deep from SKILL.md.

## Step 2 — Audit each skill

Read every SKILL.md in scope. Classify each finding into one tier. Record
`file:line` (or `file`), the rule, the violation, and the concrete fix.

### Tier A — Spec violation (MUST fix)

- `name` regex mismatch (most common: `:` from a namespace prefix, or
  underscore / uppercase)
- `name` >64 chars
- `name` contains `anthropic` or `claude`
- `description` empty, >1024 chars, or in first/second person ("I can…",
  "You can use this…")
- XML tags in `name` or `description`
- Body >1000 lines
- Windows-style paths (`scripts\foo.py`) in instructions

### Tier B — Best-practice deviation (SHOULD fix)

- Body 500–1000 lines without progressive disclosure
- Time-sensitive content (hard-coded "after August 2025…", absolute dates
  outside an "old patterns" section)
- Inconsistent terminology (mixing "field" / "box" / "element" for the same
  concept)
- File references nested more than one level deep (SKILL.md → A.md → B.md)
- Bundled scripts with magic numbers (Ousterhout's "voodoo constants") or
  scripts that punt to Claude on errors with no handling
- Required packages used in scripts but not listed in SKILL.md

### Tier C — Improvement opportunity (MAY fix)

- Naming not in gerund form (`commit` vs. `committing`) — gerund is *preferred*
  but action-oriented forms (`commit`, `audit-issues`) are explicitly acceptable;
  flag only when the collection is otherwise gerund and this one breaks pattern
- Reference files >100 lines without a table of contents
- `description` lacks specific trigger keywords ("Use when …")
- Same guidance duplicated across reachable files

## Step 3 — Report (then STOP for approval)

Write per the standing house style — conclusion first, info-dense, bullets,
no filler:

```
Audited N skills against <spec source + fetch timestamp>.

## Tier A — Spec violations (must fix)
- skills/<name>/SKILL.md:<line> — <rule>. Fix: <concrete edit>.

## Tier B — Best-practice deviations (should fix)
…

## Tier C — Improvement opportunities (may fix)
…

## Clean
- skills/<name> — no findings
```

If every skill is clean, say "All N skills pass." and stop here.

Otherwise present **one** `AskUserQuestion` call (multiSelect: true) with the
tiers that have findings as options. Suggested defaults: recommend Tier A,
recommend Tier B when ≤5 deviations, leave Tier C unrecommended.

**Do not touch any SKILL.md until the user explicitly picks tier(s) to apply.**

## Step 4 — Apply approved fixes

For each approved finding:

1. `Edit` the SKILL.md with the proposed change. Use `replace_all` only when the
   old string appears multiple times intentionally.
2. **If a `name` rename happens**, scan the whole repo for downstream slash-
   command references to the old name and update them too:
   ```
   grep -rn "/<old-name>" .
   ```
   Renaming a skill silently breaks invocations otherwise.
3. After all edits, re-grep to confirm each violation pattern is gone (e.g.
   `grep -nE '^name: .*[^a-z0-9-]' <files>` after a regex-violation fix).

Do not commit. Hand off to `/jiska-commit` so the rename + reference updates
land as one intent-coherent commit.

## Step 5 — Final report

List per-skill: what changed (or "no change"), which Tier finding it
addressed, and any open items the user declined to fix. End with the suggested
next step (`/jiska-commit` if anything was edited).

Report in Japanese; SKILL.md content stays in the repo's language.

## Constraints (always enforce)

- Never auto-apply Tier B or Tier C without explicit per-tier approval.
- Never rename a skill `name` without updating downstream `/skill-name`
  references in the same edit batch.
- Never invent rules not present in the fetched spec or the backstop list.
- Never weaken or skip the checklist to make a skill "pass" — a real
  violation is a finding to surface, not an obstacle to remove.
- If WebFetch fails, say so explicitly and audit against the backstop rules
  only; do not silently pretend the full spec was checked.
