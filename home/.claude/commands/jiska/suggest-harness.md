---
description: Analyze the recent conversation and propose harness-configuration changes that make Claude work better — not limited to CLAUDE.md, but routed to the best mechanism (hooks / permissions / memory / skill / subagent, …). Proposes only; never auto-applies.
argument-hint: "[optional focus: rules | automation | permissions | memory | workflow | all (default)]"
allowed-tools: Read, Grep, Glob, Bash
---

# Harness Tuning — Proposal Command

**Role**: Analyze the recent conversation history and propose how to configure
the harness so Claude works better for this user / project. **Not limited to
appending to CLAUDE.md** — route each signal to the configuration mechanism that
actually fits its nature. Proposals are not only **additions**: also propose
**removing** dead/redundant config and **reconciling** entries that contradict
each other or current reality. The goal is a harness that stays lean, not one
that only grows.

**Important**:
- Output **proposals** (where + what to change), not a summary or a completion
  report.
- This command **proposes only**. Any file write / setting change happens later,
  after the user approves.
- Before proposing, **read the existing harness** so add / remove / reconcile
  decisions are grounded in what is already configured (see "Read current
  state").

`$ARGUMENTS`: optional focus (`rules` / `automation` / `permissions` / `memory`
/ `workflow` / `all`; defaults to `all`).

## Routing — pick the right mechanism (the core of this command)

Assign each detected signal to the mechanism that fits it. **Always distinguish
"an instruction Claude should follow" from "a behavior the harness must execute
automatically"** — the latter cannot be guaranteed by CLAUDE.md or memory and
needs hooks.

| Nature of the signal | Where it belongs | Example |
|---|---|---|
| A durable rule / convention / assumption / coding preference Claude should always follow | **CLAUDE.md** (project `./CLAUDE.md` or user `~/.claude/CLAUDE.md`) | "Use the existing finder, not the ORM default" |
| A behavior that must happen **automatically every time** ("from now on, when X, do Y") | **settings.json hooks** (PreToolUse / PostToolUse / Stop, …); configure via the `update-config` skill | "Always run the formatter after an edit", "lint before commit" |
| The **same permission prompt** recurring | **permissions allowlist** (settings.json); use the `fewer-permission-prompts` skill | "Approving `gh issue …` every time" |
| A **non-obvious fact / history / preference** that's background knowledge, not an instruction | **memory** (user / feedback / project / reference) | "This person's role", "why an option was rejected" |
| A repeated **multi-step workflow** | a **skill / slash command** | "Every time: branch → verify → PR → merge" |
| A repeated **delegation pattern** | a **subagent** definition | "Investigate with a read-only agent, implement with another" |
| Theme / model / statusline / output style | **`/config` family** | Changing the output style |

Guidance:
- **Project-specific** → that repo's `./CLAUDE.md` / `.claude/`. **User-universal**
  (across all projects) → `~/.claude/` (user CLAUDE.md / settings / memory).
  Putting it at the wrong scope pollutes other projects.
- Writing an automatic behavior into CLAUDE.md does **not** make it run (Claude's
  memory doesn't guarantee behavior) — propose hooks for those.
- One signal can span mechanisms (e.g. "always test" → the policy goes in
  CLAUDE.md, the enforcement in a hook). Propose both when so.

## Read current state

Before scanning for new signals, **read the harness that already exists** so you
can detect redundancy / contradiction / staleness and avoid re-proposing what's
configured. Read what's relevant to the focus and the conversation:

- Project `./CLAUDE.md` and `.claude/` (settings.json, skills, subagents).
- User `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, and `references/*`.
- Memory: `MEMORY.md` index + the individual memory files it points to.

Keep this in context while applying both trigger sets below.

## Detection triggers — additions

Scan the recent conversation for these, then route each via the table above:

1. **Project-specific rules** — "use X not Y", "in this project we…", or a
   correction toward a project-specific way after standard code. → CLAUDE.md
2. **Repeated correction of the same kind** (≥ 2 times, or the same pattern
   across files). → a hook/skill if mechanical, CLAUDE.md if it needs judgment
3. **Patterns that must stay in sync** — "keep these two aligned", "match the web
   and API sides". → CLAUDE.md
4. **Requests for automation** — "from now on / every time / whenever X". →
   hooks (`update-config`)
5. **Recurring permission prompts** — approving the same read-only command/tool
   repeatedly. → permissions (`fewer-permission-prompts`)
6. **Non-obvious background / preferences** (facts, not instructions). → memory
7. **A repeated multi-step procedure** → a skill/command; **a repeated
   delegation** → a subagent

## Detection triggers — cleanup (remove / reconcile)

Compare the existing harness (from "Read current state") against this session's
reality. Propose subtractions and fixes, not just additions:

8. **Contradiction** — an existing rule/memory conflicts with another existing
   entry, or with how the user actually had Claude work this session. → propose
   `Edit (reconcile)`: which entries clash, and the single corrected wording.
9. **Stale / falsified** — an entry references a file, flag, command, path, or
   agent that no longer exists, or a decision the conversation has overturned.
   → propose `Remove`, or `Edit` to the new reality. Verify existence (Grep /
   Glob / Read) before claiming something is gone.
10. **Redundant / dead** — the same guidance appears in multiple places, or a
    rule so vague/generic it never changes behavior (dead text). → propose
    `Remove` the duplicate (name which copy to keep) or consolidation.

Be conservative on cleanup: only propose removing/rewriting when the evidence is
concrete (a contradiction observed this session, a path you confirmed missing).
Do **not** remove an entry merely because it didn't come up this session —
absence of use is not evidence it's wrong.

## Output format

**Required**: start with "Analyzed the conversation history." Do not write a
completion report or a summary.

When triggers fire, for each proposal:

```markdown
Analyzed the conversation history. Proposed harness-configuration changes:

### Proposal N: [one-line title]
- **Type**: Add | Remove | Reconcile
- **What**: [Add → the draft text to add. Remove → the exact entry to delete +
  why it's dead/stale (quote it). Reconcile → the clashing entries + the single
  corrected wording that replaces them]
- **Where**: [CLAUDE.md (project|user) / settings.json hook / permissions /
  memory (type) / skill / subagent / /config]
- **Why**: [which trigger, repeat count, or other evidence; for Remove/Reconcile,
  the concrete proof — contradiction observed, path confirmed missing, duplicate
  location]
- **How to apply**: [which file, how. Hooks / permissions / settings via the
  `update-config` / `fewer-permission-prompts` skills; CLAUDE.md / memory edited
  directly; skill / subagent as a new file]

To apply any of these, say "apply proposal N".
```

When nothing qualifies:

```markdown
Analyzed the conversation history. No harness-configuration changes to propose.
```

**Do not**:
- Write in a completion-report voice ("configured X") — this is a proposal, not
  an action.
- Output a summary or explanation of the conversation.
- Drop the leading "Analyzed the conversation history." line.

## What to propose

### Propose (✓)
- Universal rules / behaviors worth sharing across the project (or all projects).
- Technically accurate, clearly configurable items.
- Patterns newly established or repeatedly confirmed this session.
- Automation that would reliably cut rework or prompts.
- **Removal / reconciliation** of existing entries that are contradictory,
  stale, falsified, or duplicated — with concrete evidence.

### Don't propose (✗)
- One-off judgments or single-case handling.
- Re-adding anything already in CLAUDE.md / settings / memory.
- Vague / unclear instructions, or a single experiment.
- Removing an entry only because it was unused this session (absence of use ≠
  wrong); cleanup needs concrete proof, not a hunch.

## After running

1. The user reviews the proposals.
2. Apply the approved ones to the **right mechanism**:
   - hooks / permissions / settings → the `update-config` (or
     `fewer-permission-prompts`) skill
   - CLAUDE.md / memory → edit directly
   - skill / subagent → create a new file
3. Project-scoped changes go in the same PR as the code change and get reviewed.
   User-scoped changes (`~/.claude`) follow the dotfiles workflow.
