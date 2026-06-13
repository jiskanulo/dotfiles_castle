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

## Delegation map

| Task                                                            | Agent              | Model  |
| --------------------------------------------------------------- | ------------------ | ------ |
| Broad code investigation, symbol/reference tracking, structure  | `code-explore`     | sonnet |
| Well-specified implementation, mechanical edits, adding tests   | `implementer`      | sonnet |
| Multi-file changes, root-cause debugging, cross-cutting work    | `heavy-implementer`| opus   |
| Running tests / builds and summarizing pass-fail                | `test-runner`      | haiku  |

Rules of thumb:

- **Spec is clear and change is localized** → `implementer`.
- **Spec is unclear, spans many files, or needs debugging from symptoms** →
  `heavy-implementer` (or do the design yourself first, then delegate the now-
  clear pieces to `implementer`).
- **You just need to know where/how something works** → `code-explore`
  (read-only; never let it edit).
- **You just need a pass/fail signal** → `test-runner` (don't burn a smart
  model on running a test command).

## Plan-file owner annotations

When writing a multi-step plan, tag each step with its owner so delegation is
explicit and reviewable:

```
1. [owner: code-explore] Map how settings persistence flows through config.rs
2. [owner: implementer]  Add the `ffmpegBitrate` field + its test
3. [owner: heavy-implementer] Wire the new field through the download pipeline
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
