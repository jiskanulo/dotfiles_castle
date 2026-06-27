---
name: jiska-verify-issues
description: Audit open GitHub Issues for implementation-readiness — spawn a fresh-eyes agent to find gaps, contradictions, hazards, and missing considerations across the issue set, synthesize findings by severity, then (after the user approves) reflect the fixes back into the issue bodies. Use when the user wants to verify, stress-test, or harden a set of GitHub Issues before starting implementation. Counterpart to `audit-issues` (which finds new problems and files issues); this skill takes existing issues and makes each one genuinely ready to pick up.
argument-hint: "[issue numbers ('3 5 6') or 'epic:<N>' to scope to an epic's sub-issues; default: all open]"
---

# Verify Issues (fresh-eyes audit → reflect)

Run the standing "issue ready-to-implement" check: have an agent with no
prior context evaluate each target issue across six lenses
(underspecified / contradictions / hazards / overlooked / unverifiable /
locked-in), synthesize findings by severity, get the user's call on
what to do, then reflect approved fixes back into the issue bodies on
GitHub.

Project-agnostic: the audit agent discovers the project's actual stack,
URL/API shape, and conventions from the repo at run time rather than
assuming.

## Trigger

User runs `/verify-issues`, or asks to verify / review / stress-test /
double-check / harden one or more GitHub Issues, or wants to make sure
an issue set has no gaps before implementation begins.

## Inputs (`$ARGUMENTS`)

- Empty (default) → every open issue in the current repo.
- One or more numbers (`3 5 6`) → exactly those issues.
- `epic:<N>` → issue `N` plus all of its sub-issues (`gh issue view <N> --json subIssues`).

If the resolved set is empty, stop and tell the user.

## Conventions

- User-global rules at `@references/git-workflow.md` and per-project rule
  files (`.claude/rules/*`, `CLAUDE.md`, `CONTRIBUTING.md`) always apply.
  Read them at run time — do not assume.
- **Write issue bodies in the repo's existing language.** Match the
  language of the existing issues (Japanese if the issues are Japanese;
  English otherwise). Your chat reply to the user stays in Japanese per
  the global communication preference.
- This skill **never auto-edits** issue bodies. It STOPS after synthesis
  and again after gap-resolution; the user explicitly approves before
  anything on GitHub changes.

## Phase 1 — Verify (fresh-eyes audit)

Spawn ONE subagent (`general-purpose` is the safe default; `code-explore`
also works). The prompt MUST:

- Tell the agent it has **no prior context** and treat the issues plus
  project docs as the only sources.
- Forbid it from validating the issues — it is looking for what the
  author missed, not confirming the work.
- Hand it the exact `gh` commands it needs:
  - `gh issue list --state open --json number,title,body --limit 100`
  - For each target: `gh issue view <n> --json number,title,body,subIssues,blockedBy,blocking`
- Point it at the repo root and any standout context files (`CLAUDE.md`,
  `README.md`, `.mise.toml`, `Cargo.toml`, `package.json`, etc. —
  whatever the repo actually has).
- Spell out the six lenses with definitions so the agent knows what
  belongs in each:

  - **Underspecified** — an implementer would need to ask a question
    before starting; the issue does not say.
  - **Contradictions** — claims that disagree within the issue, across
    issues, or with `CLAUDE.md` / spec docs.
  - **Hazards** — concrete failure modes that look reasonable on paper
    but will bite at runtime (correctness, perf, security, supply
    chain, ops, wasm size, …). Name the failure mode.
  - **Overlooked** — things a competent reviewer would expect the
    issue to address but it doesn't (observability, error format,
    edge cases of the spec, license attribution, …).
  - **Unverifiable** — acceptance criteria that can't be objectively
    checked, OR load-bearing claims (determinism, size budgets, "no
    deps" invariants) with no test or measurement step that would
    actually fail loudly. A green check that means nothing is worse
    than no check.
  - **Locked-in** — choices that become expensive to reverse once
    shipped (URL scheme, error response shape, default values users
    will rely on, cache semantics, public type names). Flag what
    becomes a backward-compatibility burden if it ships wrong.

- Demand a structured report under ~700 words in this exact shape:

  ```
  ## Per-issue findings

  ### #N <title>
  - Underspecified: ...
  - Contradictions: ...
  - Hazards: ...
  - Overlooked: ...
  - Unverifiable: ...
  - Locked-in: ...
  (omit subsections with nothing to report; do NOT write "n/a" or "none")

  ## Cross-issue findings
  - ...

  ## Top 3 risks the author should fix before starting implementation
  1. ...
  2. ...
  3. ...
  ```

- Insist findings are concrete and actionable, with the failure mode
  named ("wasm exceeds N MiB because…", "parser will accept `X` which
  the URL spec disallows because…"). Skip bikeshedding (naming,
  formatting) and skip generic advice ("add CI").
- Tell the agent to return ONLY the report — no preamble, no closing
  summary.

Do not feed the agent your own opinions about the issues. The whole
point of this phase is an unanchored perspective.

## Phase 2 — Synthesize (then STOP for approval)

Read the agent's report and rewrite it for the user in the standing
house style — conclusion first, information-dense, bullets, no filler.
Group findings into three tiers:

- **Blocking** — would break correctness, deploy, or public API once
  shipped. Must be resolved before implementation starts.
- **Design-flaw** — wouldn't break the build but would land bad
  UX / API / ops decisions that are painful to reverse post-launch.
- **Minor** — edge cases or test gaps that an implementer can fix in
  the PR without re-litigating design.

For each finding, give your own judgment alongside the agent's claim
("agent claims X; I'd verify — typical Cloudflare default is Y"). Where
you have a strong recommendation, state it plainly with a 5-point
recommendation level rather than asking; reserve `AskUserQuestion` for
real forks in the road.

Then present reflection options via `AskUserQuestion` (single question,
three or four options). Suggested defaults:
1. Update Blocking + Design-flaw issues; append Minor to the same issues.
   *(Most thorough — recommended.)*
2. Update Blocking only; record Design-flaw + Minor as "open items" notes.
3. Append "to-investigate" notes only; decide nothing now.
4. Redo verify with a different prompt / agent type (when the audit
   looks shallow or off-target).

**STOP here until the user picks an option.**

## Phase 3 — Resolve gaps (only after approval)

For each genuine decision the user must make (font choice, plan tier,
size cap, CORS policy, …), batch into one `AskUserQuestion` call
(four-question maximum per call; split into multiple rounds if needed).

Up-front in the same reply, list every decision you are NOT asking
about and the default you will use, so the user can override without
you having to enumerate everything as a question.

For each decision give a 5-point recommendation level and the reasoning.
Do NOT over-ask: settled items (HTTP semantics, license attribution,
`default-features = false`, etc.) get stated as recommendations to be
applied unless the user objects.

**STOP here until every question is answered.**

## Phase 4 — Reflect into issues (only after Phase 3 is done)

For each affected issue, write the **complete new body** to a file
under the session scratchpad (the path the harness gives you, NOT
`/tmp`):

```
<scratchpad>/verify-issues/iss<N>.md
```

Then update each issue in parallel:

```
gh issue edit <N> -F <scratchpad>/verify-issues/iss<N>.md
```

Conventions for the new body:

- Preserve the existing body's structure; integrate fixes inline
  rather than appending "## Updates from verify pass" sections that
  rot over time. (The epic / overview issue is the one exception — a
  `## Verify-pass notes (<YYYY-MM-DD>)` section there is fine because
  it captures the meta-story.)
- Use the repo's language and backtick / table conventions
  consistently with the original.
- Where a decision applies to multiple issues, mention it in each, and
  ALSO add the canonical version to the epic / overview issue's
  "Confirmed defaults" table (or the equivalent section).

After all edits, spot-check at least one issue with
`gh issue view <N> --json title,body` to confirm rendering, then
report:

- Issue numbers updated, one line each describing the main change.
- Any decisions still left open (with the issue they live in).
- Suggested next step for the user (which sub-issue is now unblocked
  for implementation).

## What this skill does NOT do

- It does NOT open PRs, scaffold code, or run the project build. Pair
  with `tackle-issues` after this skill if you want implementation to
  begin.
- It does NOT auto-resolve disagreements between the audit agent and
  the existing issue bodies — surface the disagreement to the user and
  let them decide.
- It does NOT silently demote findings. If a finding is being skipped,
  state it in chat (one line).
