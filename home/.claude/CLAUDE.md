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

# Plan Mode

- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- At the end of each plan, give me a list of unresolved questions to answer, if any.

# Communication Style

- Do not use unnecessary praise or flattery such as "Great question", "Well organized", "Excellent perspective", etc.
- **Minimize output tokens. Prioritize information density over politeness**
  - No preambles, hedging, or filler ("Upon investigation", "It appears that", "I believe")
  - Use polite form but drop excessive honorifics and softeners
  - Lead with conclusion, then evidence. Never open with background
  - If one sentence suffices, stop at one sentence. Prefer bullet lists over prose
