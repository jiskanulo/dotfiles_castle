---
name: verify-issues
description: This skill should be used when the user asks to "verify issues", "stress-test issues", "harden GitHub issues", "double-check these tickets", "are these issues ready to implement", or wants to audit a set of existing GitHub Issues for implementation-readiness. Spawns a fresh-eyes audit agent across six lenses (underspecified/contradictions/hazards/overlooked/unverifiable/locked-in), tiers findings (Blocking/Design-flaw/Minor), then — after approval — reflects fixes back into the issue bodies. Counterpart to `audit-issues` which files new problems. Optionally narrows to specific issue numbers or an epic's sub-issues.
allowed-tools: Read, Bash, Agent, AskUserQuestion, Write
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

## Inputs (orchestrator resolves these before Phase 1)

Inspect the user's request for a target spec:

- Empty (default) → run `gh issue list --state open --limit 13 --json number`
  and take the issue numbers. The 13 cap lets the next paragraph's refusal
  trigger without pulling 100 just to throw them away.
- Numeric list (e.g. `3 5 6`) → use those numbers verbatim.
- `epic:<N>` → run
  `gh issue view <N> --json subIssues -q '.subIssues[].number'` and take
  `<N>` plus every sub-issue number.

If the resolved set is empty, stop and tell the user. If the resolved set
exceeds ~12 issues, surface and ask the user to narrow before continuing —
per-issue depth stops being digestible past that point.

Pass the **resolved list of numbers** into Phase 1's agent prompt.

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

Spawn ONE subagent — `code-explore` (read-only investigation, the default
per role-based-model-selection in user-global CLAUDE.md). The audit is
read-only by design; no escape hatch to a write-capable agent. The prompt
MUST:

- Tell the agent it has **no prior context** and treat the issues plus
  project docs as the only sources.
- **Forbid state-mutating `gh` commands** in the prompt explicitly: no
  `gh issue edit / create / comment / close / reopen`, no `gh pr ...`,
  no label changes. The audit is read-only by spec.
- Forbid it from validating the issues — it is looking for what the
  author missed, not confirming the work.
- Pass the resolved list of issue numbers. The agent runs:
  - `gh issue view <n> --json number,title,body,subIssues,blockedBy,blocking`
    per target (note: `subIssues` / `blockedBy` / `blocking` may be empty on
    repos without Issues v2 features — not a finding by itself), plus
  - Read access to the project context files listed below.
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
    shipped: externally-visible names (public API, URL paths, env-var
    keys), default values users will rely on, cache semantics, error
    response shapes, public type names. Internal field/variable naming
    is bikeshedding, not locked-in. Flag what becomes a backward-
    compatibility burden if it ships wrong.

- Demand a structured report, sized in proportion to the number of
  targets: a 1-issue run stays compact and unpadded; per-issue sections
  stay substantive as the set grows. Shape the report like this (omit
  subsections with nothing to report; do not write "n/a" or "none"):

  ```
  ## Per-issue findings

  ### #N <title>
  - Underspecified: ...
  - Contradictions: ...
  - Hazards: ...
  - Overlooked: ...
  - Unverifiable: ...
  - Locked-in: ...

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
three or four options). Each option carries a 5-point recommendation and
names the destination for any notes:
1. Update Blocking + Design-flaw issues; append Minor to the same issues.
   *(★★★★★ — most thorough, the standing default. Destination: the
   affected issues themselves.)*
2. Update Blocking issues only; record Design-flaw + Minor as "open items"
   notes in the chat reply (not in the issues).
   *(★★★☆☆ — when Design-flaw items still need user judgment.)*
3. Append "to-investigate" notes to the chat reply only; decide nothing
   now.
   *(★★☆☆☆ — when even the Blocking findings need more evidence.)*
4. Redo verify with a different prompt / agent type.
   *(★☆☆☆☆ — only when the audit looks shallow or off-target.)*

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

Let `<affected ids>` = the set of issues whose bodies will be edited:
- **Option 1**: every issue that has at least one Blocking or Design-flaw
  finding. Minor findings on those same issues are folded in. Minor
  findings on issues with no Blocking/Design-flaw finding stay surfaced
  in the chat reply only.
- **Option 2**: every issue with at least one Blocking finding only.
  Design-flaw and Minor findings stay in the chat reply.
- **Options 3/4**: empty — skip Phase 4 entirely.

Add the epic / overview issue to `<affected ids>` whenever canonical
defaults need to land in its body (lines below), even if the epic itself
has no findings.

First, refetch each affected issue's current body to the scratchpad —
the audit agent returned only summary findings, not full bodies, and
the Phase 2/3 user decisions may have come hours apart from the audit.
Create the subdir before redirecting; the harness gives you the flat
scratchpad path and shell `>` does not auto-mkdir:

```
SCRATCHPAD="<scratchpad>"   # quote-friendly; covers paths with spaces
mkdir -p "$SCRATCHPAD/verify-issues"
set -euo pipefail
for N in <affected ids>; do
  gh issue view "$N" --json body -q .body \
    > "$SCRATCHPAD/verify-issues/iss${N}.orig.md" \
    || { echo "refetch failed for #$N"; exit 1; }
done
```

Then, for each affected issue, write the **complete new body** to a
file under the session scratchpad (the path the harness gives you, NOT
`/tmp`), starting from `iss<N>.orig.md` and integrating the approved
fixes:

```
<scratchpad>/verify-issues/iss<N>.md
```

Then update each affected issue. Issue the `gh issue edit` calls as
parallel Bash tool calls in a single message — latency only, no
semantic difference vs. sequential:

```
gh issue edit <N> -F "$SCRATCHPAD"/verify-issues/iss<N>.md
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
  "Confirmed defaults" table (or the equivalent section). If no epic /
  overview issue exists, surface the canonical defaults in the chat reply
  only — do not invent a parent issue.

After all edits, confirm each updated body landed intact. GitHub
normalizes line endings and may strip trailing whitespace, so compare
with those ignored:

```
set -euo pipefail
for N in <affected ids>; do
  echo "=== #$N ==="
  diff -B -w \
    <(gh issue view "$N" --json body -q .body) \
    "$SCRATCHPAD"/verify-issues/iss"$N".md \
    || true   # diff exits non-zero on differences; capture, do not abort
done
```

Empty diff = intact. If any issue shows real differences, surface the
offending hunks with the issue number and STOP — do not silently retry
or assume success. Once all diffs are empty, spot-check markdown
rendering on the issue with
the densest markup (`gh issue view <N>` without `--json`, so the
terminal renderer surfaces breakage — broken table pipes, unrendered
code fences, collapsed nesting); widen the check to every updated issue
if anything looks off, and STOP with the list if breakage remains.
Otherwise report:

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
