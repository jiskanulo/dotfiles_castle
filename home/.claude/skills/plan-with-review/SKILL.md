---
name: plan-with-review
description: This skill should be used when the user asks to "考えを整理して", "計画を立てて", "やりたいことを相談", "ヒアリングして計画にして", "plan with review", or wants to gather multiple asks one at a time, group them, draft a solution, and have a fresh-context reviewer validate it (up to 3 rounds) before presenting the result. Intake is conversational — one ask per turn until the user signals "以上です" / "終わり" 等 — and the skill stops after presenting; downstream actions (file as issue, delegate to another agent, etc.) are left to the user.
allowed-tools: Read, Write, Edit, AskUserQuestion, Agent
---

# Plan with Review

Conduct a structured planning conversation: gather the user's asks one at
a time, group them, draft a solution, then hand the draft to a
fresh-context reviewer for OK/NG validation. Iterate up to three review
rounds. Present the final result and STOP — the user decides what to do
next (file as issue, delegate to another agent, hold).

## Inputs

If the user's request includes a seed topic / first ask, Phase 1 step 1
records it. If there is no seed, start Phase 1 cold. Phase 1 owns the
exact handling — this section is just the pointer.

## Conventions

- Honor the project rules the harness already loaded into context
  (`CLAUDE.md` plus any references). Read `CONTRIBUTING.md` on demand if a
  group's draft needs it. The key constraint from the user-global
  task-execution rules: never fake "done" — a real failure is a finding to
  surface, not an obstacle to remove.
- Chat replies to the user stay in Japanese per the global communication
  preference. The reviewer prompt and structured outputs can be English
  for precision.
- This skill **never edits files in the user's project, opens PRs, or files
  Issues** — its only writes are to the scratchpad state file at
  `<scratchpad>/plan-with-review/state.md`. It STOPS after presenting; the
  user picks the next action.

## Externalize state

The whole flow can span many turns and may survive compaction. Maintain
a progress file under the session scratchpad. Resolve `<scratchpad>` from
the path in the session's `# Scratchpad Directory` system reminder (NOT
`/tmp`):

```
<scratchpad>/plan-with-review/state.md
  ## Asks (raw, in order received)
  ## Groups (after Phase 2)
  ## Current draft (Phase 3 onward)
  ## Review round N
    - Verdict: OK / NG
    - Reviewer findings: ...
    - Revisions made: ...
  ## Open clarifying questions (still waiting on the user)
```

Update it as each phase progresses. Auto-memory is for durable facts;
this file is for in-flight state.

## Phase 1 — Intake (one ask at a time)

Goal: collect every ask the user wants on the table, **without answering
any of them yet**.

Protocol:

1. If the user's request included a seed topic, apply the bundled-asks
   check from step 2 first (numbered, bulleted, or "X and Y"
   coordination → split). Record the resulting entries verbatim and skip
   to step 3. Otherwise ask plainly (free text, NOT `AskUserQuestion`):
   「やりたいこと・相談したいことを1つ教えてください」.
2. Wait for the user's reply. If a single reply bundles multiple asks
   (numbered, bulleted, or "X and Y" coordination), split into separate
   entries and acknowledge with the count. Record each verbatim in the
   scratchpad.
3. Acknowledge in one short line (「受け取りました: <要約>」) and ask:
   「他にもありますか? なければ『以上です』『終わり』などとお伝えくだ
   さい」.
4. Repeat steps 2–3 until the user signals done. Done signals include
   「以上」「終わり」「それで全部」「以上です」「これだけ」"no more"
   "done", or any unambiguous equivalent. If a message could be either a
   done signal or another ask, disambiguate via `AskUserQuestion` (the
   free-text exception below applies only to the "next ask / done?" turn).

Hard rules for Phase 1:

- Do NOT propose solutions, ask clarifying questions about content, or
  judge the asks. Just collect.
- Do NOT use `AskUserQuestion` for the "next ask / done?" turn — Phase 1
  intake is a **deliberate, scoped exception** to the global
  `AskUserQuestion` rule, so the user can paste asks in any shape
  (multi-line, code blocks, URLs, …) without the picker UI fighting
  them. Every other prompt in this skill still uses `AskUserQuestion`.
- If the user gives zero asks (only signals done), STOP the skill and
  tell the user there is nothing to plan.

## Phase 2 — Group

Group the collected asks by **kind** and **content overlap**. Useful
patterns:

- "Same feature, multiple sub-asks" → one group.
- "Different domains" (build / docs / runtime / process) → separate
  groups.
- "Standalone one-offs" → each its own group.

Record the grouping under `## Groups (after Phase 2)` in the scratchpad
before showing it to the user, so Phase 4's reviewer prompt can read
"asks by group" even after compaction.

Show a compact list of groups to the user inline — one line per group,
no question, just a summary. If a single group covers everything, say so
explicitly. Do not over-decompose; when in doubt, keep things grouped.

## Phase 3 — Draft solutions

For each group, draft a solution: what to do, in what order, with
explicit done-criteria. Apply existing house style — conclusion first,
bullets, no filler — and obey the harness-loaded rules from the
Conventions section.

If a draft genuinely needs a user decision to proceed (forks in the
road, not preferences you can recommend), batch decisions into a single
`AskUserQuestion` call (≤4 questions). Up front in the same reply, list
every decision you are NOT asking about and the default you'll apply.
For each question, give a 5-point recommendation level and the
reasoning. Reserve `AskUserQuestion` for real forks — bikeshedding gets
stated as defaults.

Record the draft in the scratchpad. **Do not present the draft to the
user yet.** The next phase is review.

## Phase 4 — Fresh-eyes review (loop, max 3 rounds per group)

Spawn ONE subagent per round (`general-purpose` is the safe default).
Use `code-explore` only when the review hinges on grep/Read of the repo
to verify the draft against actual code. The prompt MUST be
self-contained — the reviewer has no prior conversation context.

Each round's prompt MUST:

- State the reviewer's role. Default to English for precision; Japanese is
  fine when the asks themselves are dense Japanese context. English form:
  "You are an external reviewer. Read the following user requests and the
  draft solution and judge OK or NG." (Japanese equivalent: 「あなたは外
  部レビュアーです。以下のユーザー要望と解決策案を読み、OK か NG かを
  判定してください」.)
- Hand it:
  - The collected asks (verbatim, by group).
  - The current draft solution (full, no abbreviations).
  - The repo root path and pointers to project-relevant conventions the
    subagent will not auto-load (e.g. `CONTRIBUTING.md`, repo-specific
    style guides). The Agent tool does not expose per-call cwd, so always
    include the repo root path in the reviewer prompt text and instruct
    the reviewer to read `<root>/CLAUDE.md` and any other named files
    explicitly **only if they exist** (treat file-not-found as "no rules
    to load" and proceed). Do not rely on auto-load. Do not copy-paste
    content.
- Tell the reviewer it has no prior context and to treat the asks +
  draft + repo as the only sources of truth.
- The reviewer's job is to surface missed / contradictory / hazardous
  items. Verdict OK means "I found none of those", not "I confirm the
  draft is correct."
- Demand structured output in this exact shape, with no preamble and no
  closing summary. Schema headers and field labels stay English regardless
  of body language. Reviewer must return at least one Top-issues bullet
  when the global Verdict is NG; on a malformed empty-NG, the orchestrator
  re-prompts once and on a second failure treats the round as NG with an
  attributed catch-all (`[group: <first in-review group>] reviewer
  malformed`).

  ```
  Verdict: OK | NG
  ## Per-group verdicts
  - <group name>: OK | NG
  - ...
  ## Findings
  - [group: <group name>] Coverage: does the draft answer every ask? (List missed asks.)
  - [group: <group name>] Contradictions: claims that disagree within the draft, across
    groups, or with repo conventions.
  - [group: <group name>] Hazards: concrete failure modes the draft would hit at runtime or
    rollout (correctness, security, ops, supply chain, …). Name the mode.
  - [group: <group name>] Overlooked: things a competent planner would address but didn't
    (edge cases, observability, rollback, …).
  - [group: <group name>] Style (advisory): wording/format nits that do NOT block.
  ## Top issues (only if global Verdict = NG; 1–3 per NG group, one sentence each)
  1. [group: <group name>] ...
  2. [group: <group name>] ...
  3. [group: <group name>] ...
  ```

- Verdict rules: NG if ANY ask is unanswered OR there is at least one
  Hazard / Contradiction / Overlooked finding that would change the
  plan. Otherwise OK. Style-only findings (the Style line) are advisory
  and do NOT make a draft NG.

Loop rules. State is per-group: each group carries `round` (1–3) and
`status` ∈ `in-review` / `ok` / `accepted` / `abandoned` / `ng-after-3`.
Escalation is decided per group, not per bullet.

- Review all `in-review` groups together in one reviewer call per round.
- Global Verdict OK → every in-review group becomes `ok`; the loop ends.
- On a well-formed NG, use the per-group verdicts: groups not flagged NG
  become `ok`. Each NG group gets its draft revised from that group's
  findings, then its `round` advanced; a group whose round would exceed
  3 keeps the revision but becomes `ng-after-3` (Phase 5 presents it as
  「Round 3 反映済み・未レビュー」).
- Exception — repeated finding: if a Top-issues bullet for a group
  raises essentially the same issue as one from the previous round,
  don't auto-revise that group; escalate to the user (see Escalation
  below). An Override keeps the group's round counter where it is and
  suppresses that finding in the next reviewer round. Halt guard: if
  every NG finding for a group was overridden and nothing else needs
  revision, mark the group `ok` rather than looping on nothing.

Record every round in the scratchpad (verdict + findings + revisions
made + any user decisions taken).

Failure modes to handle:

- Reviewer returns malformed output → re-prompt once with an explicit
  schema reminder. If still malformed, treat as NG **for all in-review
  groups** and consume the round (the "groups not flagged NG become ok"
  rule applies only to well-formed reviews).
- Reviewer flags only the Style line → treat as OK; carry those nits to
  the final presentation as advisory.

**Escalation (repeated finding).** The reviewer has no prior-round
context, so repeat detection is orchestrator-side: load the previous
round's Top-issues for the group from the scratchpad and judge whether a
current bullet raises essentially the same issue (semantic judgment;
compare round N to N−1 only — a bullet that skips a round counts as
progress; Findings-block items that never make Top-issues are out of
scope). The schema's `[group: <name>]` prefix on each Top-issues bullet
is what makes this attribution possible — keep requiring it.

On a repeat, escalate that group to the user via `AskUserQuestion` —
batch into one call when ≤ 4 groups escalate in the same round, else
serialize. Exactly three mutually exclusive options, each with a 5-point
recommendation:

- **Accept current draft (treat finding as known limit)** — record the
  accepted finding in the scratchpad. The group becomes `accepted`; its
  draft moves to Phase 5 as-is, with no further reviewer rounds.
- **Override finding (mark advisory, continue review)** — record the
  overridden bullet and tell the next reviewer round "this item was
  overridden by the user; do not flag it again"; also exclude the
  overridden bullet from repeat detection in later rounds (so a
  disobedient reviewer can't re-escalate it). The group's `round`
  counter does **not** advance for this escalation.
- **Abandon this group** — status `abandoned`; the group drops out of
  subsequent reviewer prompts and Phase 5 drafts.

## Phase 5 — Present — then STOP

At Phase 5 entry each group is in one of: `ok`, `accepted` (via escalation),
`abandoned`, or `ng-after-3`. Present a single combined Japanese report
containing, in this order:

- **見出し** — 状況を先頭で明示する: 全グループ `ok` なら「解決策
  (レビューOK / 最終ラウンド <N> で通過)」、全グループ `ng-after-3`
  なら「解決策案 (レビュー未通過 — 3周打ち切り)」、それ以外
  (`accepted` / `abandoned` を含む任意の組み合わせ)なら「解決策
  (グループごとに状況が異なる)」。
- **グループごとの節** — 名前と status を添え、何をやるか / 順序 /
  完了条件を列挙する。`abandoned` は status と理由のみ。`ng-after-3`
  は「Round 3 反映済み・未レビュー」と明記し、残った Findings
  (Coverage / Contradictions / Hazards / Overlooked の種別ごと)、
  各 Round の修正経緯、推奨(要望の絞り直し・分割、許容したい
  Findings を明示しての再実行)を添える。
- **レビュー履歴 (要約)** — 実際に走ったラウンドだけ、ラウンド番号と
  verdict、NG なら主な指摘 → 修正を1行ずつ。
- **助言レベル** — style nits / advisory があれば任意取り込みとして
  列挙。

Then state plainly: 「以上です。issue化・別エージェントへ委譲などの次
のアクションは任意に進めてください」.

STOP. Do NOT silently soften the draft to claim OK — a real failure is a
finding to surface, not an obstacle to remove.

## What this skill does NOT do

- It does NOT file GitHub Issues, open PRs, edit code, or delegate to
  implementer agents. After presenting, the skill ends — the user picks
  the next action (invoke `audit-issues` / `tackle-issues`, manual
  delegation, hold, …).
- It does NOT answer asks during Phase 1 intake. Intake and answering
  are separated on purpose so grouping is honest.
- It does NOT pre-validate the draft itself — the whole point of the
  review loop is an unanchored second opinion. If you find yourself
  agreeing with the draft before review, that is a hint to start
  Phase 4, not a substitute for it.
