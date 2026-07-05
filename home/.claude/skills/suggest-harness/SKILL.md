---
name: suggest-harness
description: This skill should be used when the user asks to "suggest harness", "tune the harness", "harness tuning", "what should I configure", "update CLAUDE.md from this conversation", or wants Claude-configuration proposals routed to the right mechanism. Analyzes the recent conversation OR a best-practices URL, routes each signal to CLAUDE.md / hooks / permissions / memory / skill / subagent / path-scoped Rule, proposes additions plus removals/reconciliations. Never auto-applies. Optionally narrows by focus (rules / automation / permissions / memory / workflow) or maps a URL to the existing harness.
allowed-tools: Read, Grep, Glob, WebFetch
---

# Harness Tuning — Proposal Skill

**Role**: Analyze the recent conversation history and propose how to configure
the harness so Claude works better for this user / project. **Not limited to
appending to CLAUDE.md** — route each signal to the configuration mechanism that
actually fits its nature. Proposals are not only **additions**: also propose
**removing** dead/redundant config and **reconciling** entries that contradict
each other or current reality. The goal is a harness that stays lean, not one
that only grows.

**Important**: this skill **proposes only**. Any file write / setting change
happens later, after the user approves. Before proposing, **read the existing
harness** (see "Read current state") so add / remove / reconcile decisions are
grounded in what is already configured.

Input: inspect the user's invocation for a URL or a focus token. If a URL
(`http(s)://…`) is present, enter Article mode. Otherwise, if a focus token
is named, narrow Conversation mode to the subset of triggers and routing
rows the token maps to; if none, default to `all`.

Focus → trigger / routing-row subset:

| Focus | Keep triggers | Keep routing rows |
|---|---|---|
| `rules` | 1, 2, 3, 4, 9, 10, 11 | CLAUDE.md, path-scoped Rule |
| `automation` | 3, 5, 9, 10, 11 | settings.json hooks, `/config` |
| `permissions` | 6, 9, 10, 11 | permissions allowlist |
| `memory` | 7, 9, 10, 11 | memory |
| `workflow` | 3, 8, 9, 10, 11 | skill / slash command, subagent |
| `all` (default) | 1–11 | every row |

Cleanup triggers 9–11 stay active under every focus — stale / contradictory
entries should be surfaced regardless of the lens. The kept-rows gate
applies to **addition triggers (1–8)** only; cleanup proposals follow the
existing entry's mechanism, not the focus's kept rows. If an addition
trigger's natural routing target is not in the kept rows for the current
focus, mark that proposal **non-applicable, why** (the same shape as the
article-mode rule below in "Two input modes").

If both a URL and a focus token are supplied, article mode wins — the focus
token is ignored.

## Two input modes

- **Conversation mode** (default — no URL given): the signals come from the
  recent conversation history. Apply the detection triggers below to it.
- **Article mode** (a URL is given): WebFetch the URL and extract the
  best-practices **principles** it states. Treat each principle as a candidate
  signal — then route, compare against the existing harness, and propose exactly
  as in conversation mode. Specifics:
  - Map each principle to the mechanism the Routing section assigns it; one
    article usually spans several mechanisms.
  - **Honestly mark non-applicable principles** — guidance aimed at a different
    surface (org/SaaS/Slack-style deployment, a feature this setup lacks) gets a
    one-line "non-applicable, why" note, not a forced proposal.
  - Cross-check every proposal against what's **already configured** (see "Read
    current state") to propose only the genuine gap, not what the harness
    already does.

## Routing — pick the right mechanism (the core of this skill)

Assign each detected signal to the mechanism that fits it. **Always distinguish
"an instruction Claude should follow" from "a behavior the harness must execute
automatically"** — the latter cannot be guaranteed by CLAUDE.md or memory and
needs hooks.

| Nature of the signal | Where it belongs | Example |
|---|---|---|
| A durable, **always-relevant** rule / convention / assumption / coding preference Claude should follow project-wide | **CLAUDE.md** (project `./CLAUDE.md` or user `~/.claude/CLAUDE.md`) | "Use the existing finder, not the ORM default" |
| A constraint that applies **only to specific files / directories**, or a cross-cutting convention that recurs in particular paths | **path-scoped Rule** — a file under `.claude/rules/` with `paths:` glob frontmatter — not CLAUDE.md | "migrations are append-only", "in `api/` always validate with the shared schema" |
| A behavior that must happen **automatically every time** ("from now on, when X, do Y"), or an **absolute prohibition** that must be enforced ("never do X") | **settings.json hooks** (PreToolUse deny / PostToolUse / Stop, …); configure via the `update-config` skill. Org-wide guardrails → **Managed Settings** | "Always run the formatter after an edit", "block force-push to main" |
| The **same permission prompt** recurring | **permissions allowlist** (settings.json); apply via the `update-config` skill | "Approving `gh issue …` every time" |
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

Before scanning for new signals, **read the harness that already exists** to
surface redundancy / contradiction / staleness and avoid re-proposing what's
configured. Read what's relevant to the focus and the conversation:

- Project `./CLAUDE.md` and `.claude/` (settings.json, skills, subagents,
  commands, rules).
- User `~/.claude/CLAUDE.md`, `~/.claude/settings.json`,
  `~/.claude/references/*`, `~/.claude/skills/`, `~/.claude/agents/`, and
  `~/.claude/commands/` (if present).
- Memory: `MEMORY.md` index + the individual memory files it points to.

Keep this in context while applying both trigger sets below.

## Detection triggers — additions

Scan the recent conversation for these, then route each via the table above:

1. **Project-specific rules** — "use X not Y", "in this project we…", or a
   correction toward a project-specific way after standard code. → CLAUDE.md if
   always-relevant; if it only applies to certain files/dirs, see trigger 2
2. **Path/file-specific constraints** — a rule scoped to certain files or
   directories ("migrations are append-only", "in `api/` always validate…"). →
   a **path-scoped Rule** (`paths:`), not the root CLAUDE.md, so it doesn't load
   during unrelated work
3. **Repeated correction of the same kind** (≥ 2 times, or the same pattern
   across files). → a hook/skill if mechanical, CLAUDE.md if it needs judgment
4. **Patterns that must stay in sync** — "keep these two aligned", "match the web
   and API sides". → CLAUDE.md
5. **Requests for automation** — "from now on / every time / whenever X". →
   hooks (`update-config`), or `/config` for theme / model / statusline /
   output-style preferences.
6. **Recurring permission prompts** — approving the same read-only command/tool
   repeatedly. → permissions allowlist (apply via `update-config`).
   `/fewer-permission-prompts` exists as a separate transcript-wide pruning
   skill — do not invoke it as the applier for one approved item.
7. **Non-obvious background / preferences** (facts, not instructions). → memory
8. **A repeated multi-step procedure** → a skill/command; **a repeated
   delegation** → a subagent

## Detection triggers — cleanup (remove / reconcile)

Compare the existing harness (from "Read current state") against this session's
reality. Propose subtractions and fixes, not just additions:

9. **Contradiction** — an existing rule/memory conflicts with another existing
   entry, or with how the user actually had Claude work this session. → propose
   `Reconcile`: which entries clash, and the single corrected wording.
10. **Stale / falsified** — an entry references a file, flag, command, path, or
    agent that no longer exists, or a decision the conversation has overturned.
    → propose `Remove` if the entry has no remaining truth, or `Update` to the
    new reality. Verify existence (Grep / Glob / Read) before claiming something
    is gone.
11. **Redundant / dead** — the same guidance appears in multiple places, or a
    rule so vague/generic it never changes behavior (dead text). → propose
    `Remove` the duplicate (name which copy to keep) or `Reconcile` for
    consolidation.

Be conservative on cleanup: only propose removing/rewriting when the evidence is
concrete (a contradiction observed this session, a confirmed-missing path).
Do **not** remove an entry merely because it didn't come up this session —
absence of use is not evidence it's wrong.

## Output format

Open with one line stating what was analyzed (the conversation, or the
article title / URL), then go straight into the proposals. Do not write a
completion report or a summary.

When triggers fire, for each proposal:

```markdown
Analyzed the conversation history. Proposed harness-configuration changes:

### Proposal N: [one-line title]
- **Type**: Add | Remove | Reconcile | Update
- **What**: [Add → the draft text to add. Remove → the exact entry to delete +
  why it's dead/stale (quote it). Reconcile → the clashing entries + the single
  corrected wording that replaces them. Update → the single entry to edit + the
  before/after wording (use for stale single entries where there is nothing to
  reconcile against)]
- **Where**: [CLAUDE.md (project|user) / path-scoped Rule / settings.json hook /
  permissions / memory (type) / skill / subagent / /config]
- **Why**: [which trigger, repeat count, or other evidence; for Remove/Reconcile,
  the concrete proof — contradiction observed, path confirmed missing, duplicate
  location]
- **How to apply**: [which file, how. Hooks / permissions / settings via the
  `update-config` skill; CLAUDE.md / memory edited directly; skill /
  subagent / path-scoped Rule as a new file; `/config` via the `/config`
  command]

To apply any of these, say "apply proposal N".
```

When nothing qualifies:

```markdown
Analyzed the conversation history. No harness-configuration changes to propose.
```

**Standing pointer**: this skill analyzes one conversation, so it only flags
a permission via trigger 6 when that prompt recurred *this session*. When at
least one Trigger 6 proposal was made, append this tip once as a final line:

```markdown
> Tip: to prune recurring permission prompts across your whole transcript
> history (not just this conversation), run `/fewer-permission-prompts`.
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
   - hooks / permissions / settings → the `update-config` skill
     (`/fewer-permission-prompts` is a separate transcript-wide pruning
     skill, not the applier for one approved item)
   - CLAUDE.md / memory → edit directly
   - skill / subagent / path-scoped Rule → create a new file
   - theme / model / statusline / output style → the `/config` command
3. Project-scoped changes go in the same PR as the code change and get reviewed.
   User-scoped changes (`~/.claude`) follow the dotfiles workflow.
