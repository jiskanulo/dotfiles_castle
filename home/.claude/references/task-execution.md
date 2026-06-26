# Task execution

How to run a task efficiently: prepare deliberately, keep units atomic,
externalize state, and treat verification as a gate. Loaded via
`@references/task-execution.md` from `CLAUDE.md`; it expands the `# Task
Execution` bullets there into an operational loop. Pairs with
`@references/role-based-model-selection.md` (who does the work).

## Principle

A clear small task with externalized state beats a vague large task run for a
long time. The orchestrator's leverage is in *framing* — goal, done-criteria,
decomposition — not in doing more in one pass. Long turns get compacted, so
state that lives only in the conversation can vanish; put it in durable places.

## Before starting

- **State the goal and done-criteria in one line.** Not "fix X" but "X yields △
  when …, and test △ is green." If the user's request lacks this, restate your
  understanding or ask — don't start on a guess.
- **Gather context up front.** Read the involved code paths and rules before
  editing so constraints don't surface mid-edit. For broad unknowns, delegate a
  `code-explore` pass and act on its conclusion.
- **Capture a baseline.** For non-trivial work, run the project's checks
  (build / test) once first, so a pre-existing failure is never mistaken for one
  you caused.
- **Know the verify command.** Confirm how the repo runs test / lint / build
  (wrapper, version manager, container included) before you need it.

## During — the loop

Repeat per atomic unit; don't widen scope mid-unit:

1. **Scope one small unit** with its own done-criteria.
2. **Implement** following existing conventions.
3. **Verify** — run the real checks for what you touched.
4. **Report / checkpoint**, then take the next unit.

- **Keep units atomic.** Finish and verify one before starting the next. A unit
  that balloons across many files or turns into debugging-from-symptoms is a
  signal to stop, re-plan, or escalate to `heavy-implementer`.
- **Externalize progress on long tasks.** Maintain a TodoWrite list; for
  genuinely long runs keep a scratchpad progress file (done / next / open
  questions). This survives compaction — conversation memory may not.
  Auto-memory is for durable facts, not in-flight task state.
- **Checkpoint at the seams.** Before an irreversible or outward-facing step, or
  a real design fork, pause and confirm (AskUserQuestion to choose).

## Verification is a gate

Never make a check pass by deleting, skipping, or weakening a test, loosening an
assertion, or reporting a result you didn't run. A genuine failure is a finding
to surface, not an obstacle to remove. Don't claim "done" without having run the
verification.

## Delegating well (when handing to subagents)

- Pick the role deliberately (see role-based-model-selection.md) and pass the
  initial context the agent needs — file paths, repro steps, the verify command
  — so it doesn't burn turns rediscovering them.
- Ask for the deliverable shape you want (diff only / approach only / PR) and
  rely on the standing report contract for the rest.
- After a coherent feature lands, run `/suggest-harness` to fold new lessons back
  into the harness.
