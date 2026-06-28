# Basic Guidelines

- Proactively ask questions when something is unclear
- Always use AskUserQuestion to get answers when asking questions
- **When presenting multiple options, provide recommendation level and reasoning for each**
  - Recommendation level is a 5-point scale
  - Not required when there is a single clear answer

# Delegation & Model Selection

- Route work to subagents by role to keep expensive reasoning in the main
  session. Criteria, delegation map, and the report contract:
  @references/role-based-model-selection.md
- Agents: `code-explore` (read-only investigation, sonnet), `implementer`
  (well-specified edits, sonnet), `heavy-implementer` (multi-file / debugging,
  opus), `test-runner` (run + summarize tests, haiku).

# GitHub CLI (gh)

- **Prefer native `gh` subcommands over `gh api`** whenever an equivalent exists.
  `gh api` is the fallback for things the CLI can't yet do, not the default.
  - Sub-issues: `gh issue create --parent <n>` / `gh issue edit <n> --add-sub-issue` — not `gh api`.
  - Dependencies: `gh issue edit <n> --add-blocked-by/--add-blocking` (and `--remove-*`), `gh issue create --blocked-by/--blocking` — not `gh api .../dependencies`.
  - Inspect with `gh issue view <n> --json blockedBy,blocking,subIssues`.

# Harness Tuning

- After completing a **feature** (a coherent unit of work spanning several PRs —
  not after every individual PR, and not for trivial one-offs), proactively run
  `/suggest-harness` to capture any new rules / automation / memory worth
  configuring. Present its proposals; apply only what I approve.

# Git Commits

- One commit = one *kind* of change (feat / fix / refactor / chore / docs /
  test). Never mix categories — full rules at `@references/git-workflow.md`.
- Use `/jiska-commit` to split working-tree changes into atomic commits with
  an announced plan (no approval gate — roll back with `git reset --soft HEAD~N`
  if needed). Manual `git commit` still allowed but must follow the same
  granularity.

# Task Execution

- Full operational loop (prepare → atomic units → externalize state → verify):
  @references/task-execution.md
- **Prepare before editing.** Restate the goal + done-criteria in one line, then
  gather the context you need up front (read the code paths and rules) so you
  don't discover constraints mid-edit. For non-trivial work, run a baseline
  check (build / test) first — a pre-existing red must never be mistaken for one
  you caused.
- **Keep work atomic.** Scope each unit small; finish and verify one before
  starting the next. Don't try to do too much in a single pass.
- **Externalize progress on long tasks.** Long turns get compacted, and in-flight
  state can be lost in the summary. For multi-step work, keep state outside the
  conversation: maintain a TodoWrite list, and for genuinely long runs a
  scratchpad progress file (done / next / open questions). Auto-memory is for
  durable facts — not in-flight task state.
- **Never fake "done."** Don't delete, skip, or weaken tests to make a check
  pass, and don't report done without actually running verification. A real
  failure is a finding to surface, not an obstacle to remove.

# Plan Mode

- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- Break the plan into small, atomic units with explicit done-criteria; don't
  bundle unrelated work into one step.
- At the end of each plan, give me a list of unresolved questions to answer, if any.

# Communication Style

- **Respond to the user in Japanese.** The user writes in Japanese; user-facing
  chat replies must be Japanese, even after long English tool output or English
  code work. Keep checked-in artifacts in the repo's own language — commit
  messages, PR / issue bodies, code, and comments stay English where the repo is
  English. Split: conversation = Japanese, repository text = repo language.
- Do not use unnecessary praise or flattery such as "Great question", "Well organized", "Excellent perspective", etc.
- **Minimize output tokens. Prioritize information density over politeness**
  - No preambles, hedging, or filler ("Upon investigation", "It appears that", "I believe")
  - Use polite form but drop excessive honorifics and softeners
  - Lead with conclusion, then evidence. Never open with background
  - If one sentence suffices, stop at one sentence. Prefer bullet lists over prose
