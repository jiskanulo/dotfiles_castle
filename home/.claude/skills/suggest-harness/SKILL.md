---
name: suggest-harness
description: This skill should be used when the user asks to "suggest harness", "tune the harness", "harness tuning", "what should I configure", "update CLAUDE.md from this conversation", or wants Claude-configuration proposals routed to the right mechanism. Analyzes the recent conversation OR a best-practices URL, routes each signal to CLAUDE.md / hooks / permissions / memory / skill / subagent / path-scoped Rule, proposes additions plus removals/reconciliations. Never auto-applies.
argument-hint: "[focus: rules | automation | permissions | memory | workflow | all (default)] OR a best-practices article URL to map onto the existing harness"
allowed-tools: Read, Grep, Glob, Bash, WebFetch
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

`$ARGUMENTS`: either a **focus** (`rules` / `automation` / `permissions` /
`memory` / `workflow` / `all`; defaults to `all`) **or a URL**. Treat the
argument as a URL when it looks like one (`http(s)://…`); otherwise as a focus.

## Two input modes

- **Conversation mode** (default — no URL given): the signals come from the
  recent conversation history. Apply the detection triggers below to it.
- **Article mode** (a URL is given): WebFetch the URL and extract the
  best-practices **principles** it states. Treat each principle as a candidate
  signal — then route, compare against the existing harness, and propose exactly
  as in conversation mode. Specifics:
  - Map each principle to the mechanism the Routing table assigns it; one
    article usually spans several mechanisms.
  - **Honestly mark non-applicable principles** — guidance aimed at a different
    surface (org/SaaS/Slack-style deployment, a feature this setup lacks) gets a
    one-line "non-applicable, why" note, not a forced proposal.
  - Cross-check every proposal against what's **already configured** (see "Read
    current state") so you propose only the genuine gap, not what the harness
    already does.

## Routing — pick the right mechanism (the core of this command)

Assign each detected signal to the mechanism that fits it. **Always distinguish
"an instruction Claude should follow" from "a behavior the harness must execute
automatically"** — the latter cannot be guaranteed by CLAUDE.md or memory and
needs hooks.

| Nature of the signal | Where it belongs | Example |
|---|---|---|
| A durable, **always-relevant** rule / convention / assumption / coding preference Claude should follow project-wide | **CLAUDE.md** (project `./CLAUDE.md` or user `~/.claude/CLAUDE.md`) | "Use the existing finder, not the ORM default" |
| A constraint that applies **only to specific files / directories**, or a cross-cutting convention that recurs in particular paths | **path-scoped Rule** (`paths:` field) — not CLAUDE.md | "migrations are append-only", "in `api/` always validate with the shared schema" |
| A behavior that must happen **automatically every time** ("from now on, when X, do Y"), or an **absolute prohibition** that must be enforced ("never do X") | **settings.json hooks** (PreToolUse deny / PostToolUse / Stop, …); configure via the `update-config` skill. Org-wide guardrails → **Managed Settings** | "Always run the formatter after an edit", "block force-push to main" |
| The **same permission prompt** recurring | **permissions allowlist** (settings.json); use the `fewer-permission-prompts` skill | "Approving `gh issue …` every time" |
| A **non-obvious fact / history / preference** that's background knowledge, not an instruction | **memory** (user / feedback / project / reference) | "This person's role", "why an option was rejected" |
| A repeated **multi-step workflow** | a **skill / slash command** | "Every time: branch → verify → PR → merge" |
| A repeated **delegation pattern**, or a **side task that would clutter main context** with intermediate results (deep search, log/dep analysis) — even one-off | a **subagent** definition | "Investigate with a read-only agent, implement with another"; "isolate a noisy dependency audit" |
| Theme / model / statusline / output style | **`/config` family** | Changing the output style |

Guidance:
- **Project-specific** → that repo's `./CLAUDE.md` / `.claude/`. **User-universal**
  (across all projects) → `~/.claude/` (user CLAUDE.md / settings / memory).
  Putting it at the wrong scope pollutes other projects.
- **Keep CLAUDE.md lean** — it loads every session, so it should hold only
  always-relevant facts. Route procedures to a **skill**, path/file-specific
  constraints to a **path-scoped Rule**, and automation/prohibitions to **hooks**.
  When a CLAUDE.md grows unwieldy, split per-area rules into a subdirectory
  `CLAUDE.md` (loads on-demand) rather than piling everything into the root file.
- Writing an automatic behavior into CLAUDE.md does **not** make it run, and a
  text "never do X" is **not** enforced (it bends under pressure / injection) —
  propose hooks (PreToolUse deny) for those, Managed Settings for org-wide bans.
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
   correction toward a project-specific way after standard code. → CLAUDE.md if
   always-relevant; if it only applies to **certain files/dirs**, a path-scoped
   Rule (next item)
1b. **Path/file-specific constraints** — a rule scoped to certain files or
   directories ("migrations are append-only", "in `api/` always validate…"). →
   a **path-scoped Rule** (`paths:`), not the root CLAUDE.md, so it doesn't load
   during unrelated work
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

**Required**: start with "Analyzed the conversation history." (conversation
mode) or "Analyzed <article title / URL>." (article mode). Do not write a
completion report or a summary.

When triggers fire, for each proposal:

```markdown
Analyzed the conversation history. Proposed harness-configuration changes:

### Proposal N: [one-line title]
- **Type**: Add | Remove | Reconcile
- **What**: [Add → the draft text to add. Remove → the exact entry to delete +
  why it's dead/stale (quote it). Reconcile → the clashing entries + the single
  corrected wording that replaces them]
- **Where**: [CLAUDE.md (project|user) / path-scoped Rule / settings.json hook /
  permissions / memory (type) / skill / subagent / /config]
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

**Standing pointer** (append to either output above, on its own line): this
command analyzes one conversation, so it only flags a permission via trigger 5
when that prompt recurred *this session*. For ongoing, frequency-based pruning
across all transcripts, point the user to the `/fewer-permission-prompts` skill:

```markdown
> Tip: to prune recurring permission prompts across your whole transcript
> history (not just this conversation), run `/fewer-permission-prompts`.
```

Show this pointer once, as a final line — do not invoke the skill yourself
(it auto-applies an allowlist; this command proposes only).

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
   - skill / subagent / path-scoped Rule → create a new file
3. Project-scoped changes go in the same PR as the code change and get reviewed.
   User-scoped changes (`~/.claude`) follow the dotfiles workflow.
