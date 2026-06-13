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
