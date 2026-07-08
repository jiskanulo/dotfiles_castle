# Role-based model selection

How the main session delegates work to subagents so that high-cost reasoning
stays in the orchestrator and cheaper models do the bulk work. Keep this loaded
via `@references/role-based-model-selection.md` from `CLAUDE.md`.

## Principle

The **main session is the orchestrator**. It owns the expensive, irreversible
thinking and hands mechanical / high-volume work to subagents that run in their
own context windows and report back only summaries.

Keep in the main session:

- Planning, architecture, and design trade-offs
- Resolving ambiguity / deciding what "done" means
- Choosing what to delegate and reviewing what comes back
- Final user-facing answers

Delegate everything that would flood the main context with search results,
logs, or file contents you won't reference again.

Subagents cannot reach the user: AskUserQuestion does not surface from a
subagent, and they cannot consult the main session mid-task. Resolve ambiguity
**before** delegating; agents report open questions back instead of asking.

## Delegation map

| Task                                                            | Agent                  | Model  |
| --------------------------------------------------------------- | ---------------------- | ------ |
| Broad code investigation, symbol/reference tracking, structure  | `code-explore`         | sonnet |
| Implementation: specified edits, tests, multi-file changes      | `implementer`          | sonnet |
| Symptom-driven debugging, or retry after a sonnet failure       | `implementer`          | opus (spawn with `model: opus`) |
| Running tests / builds and summarizing pass-fail                | `test-runner`          | haiku  |
| Creating/updating GitHub Issues from refined requirements       | `issue-manager`        | sonnet |
| Opening a PR once the branch is verified                        | `pr-creator`           | sonnet |
| Project health check: TODOs, tech debt, unimplemented items     | `project-investigator` | sonnet |

The Agent tool's `model` parameter overrides the agent definition's frontmatter
— that is how one `implementer` definition serves both tiers.

Rules of thumb:

- **Spec is clear** → `implementer` (default sonnet), even for multi-file work.
- **Debugging from symptoms, or a sonnet attempt failed** → re-delegate to
  `implementer` with `model: opus`. If the spec itself is unclear, do the
  design yourself first, then delegate the now-clear pieces.
- **You just need to know where/how something works** → `code-explore`
  (read-only; never let it edit).
- **You just need a pass/fail signal** → `test-runner` (don't burn a smart
  model on running a test command).
- **Requirements already refined and need Issues** → `issue-manager`
  (non-interactive: hearing happens in the main session first).
- **Branch verified and ready for review** → `pr-creator` (it stops and
  reports on red checks; it does not fix).

## Delegating: pass the whole spec up front

Delegation is ~one consultation, not a conversation. Give the agent everything
it needs in the first message — the spec, file paths, repro steps, the verify
command, and explicit done-criteria — instead of drip-feeding context across
follow-up turns. Each round trip costs latency and loses context fidelity.

## Parallel fan-out and continuation

- **Independent subtasks** → spawn their agents in a single message so they run
  concurrently.
- **Follow-up work for an agent you already spawned** → continue it with
  SendMessage (keeps its accumulated context and cache) rather than re-spawning
  a fresh agent that must rediscover everything.

## Plan-file owner annotations

When writing a multi-step plan, tag each step with its owner so delegation is
explicit and reviewable:

```
1. [owner: code-explore] Map how settings persistence flows through config.rs
2. [owner: implementer]  Add the `ffmpegBitrate` field + its test
3. [owner: implementer (model: opus)] Debug the flaky retry failure from symptoms
4. [owner: test-runner]  Run `pnpm test` + `cargo test`, report failures
```

## Report contract (applies to every agent)

Subagents must return **only**:

- The list of files changed (with one-line reasons)
- Key decisions / assumptions made
- Verification results (what was run, pass/fail, failing names)

They must **not** paste full file contents, large diffs, or the bodies of files
they merely read. The whole point is to keep the main context small — a summary
that re-dumps everything defeats it.

## Verification discipline (applies to every agent)

Verification is a gate, not a formality. No agent may make a check pass by
deleting, skipping, or weakening a test, loosening an assertion, or reporting a
result it did not actually run. A genuine failure is a finding to report, not an
obstacle to remove — stop and surface it to the caller.
