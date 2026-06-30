---
name: plan-with-review
description: This skill should be used when the user asks to "考えを整理して", "計画を立てて", "やりたいことを相談", "ヒアリングして計画にして", "plan with review", or wants to gather multiple asks one at a time, group them, draft a solution, and have a fresh-context reviewer validate it (up to 3 rounds) before presenting the result. Intake is conversational — one ask per turn until the user signals "以上です" / "終わり" — and the skill stops after presenting; downstream actions (file as issue, delegate to another agent, etc.) are left to the user.
argument-hint: "[optional: first ask or topic seed, e.g. 'CI高速化したい']"
---

# Plan with Review (intake → group → draft → fresh-eyes review × ≤3 → present)

Conduct a structured planning conversation: gather the user's asks one at
a time, group them, draft a solution, then hand the draft to a
fresh-context reviewer (`general-purpose` subagent) for OK/NG validation.
Iterate up to three review rounds. Present the final result and STOP —
the user decides what to do next (file as issue, delegate to another
agent, hold).

## Trigger

User runs the skill, or asks to「考えを整理して」「計画を立てて」「やり
たいことを相談したい」「ヒアリングして計画にして」"plan with review",
or wants multiple loose requests turned into a reviewed plan before any
implementation or issue-filing happens.

## Inputs (`$ARGUMENTS`)

- Empty (default) → start Phase 1 cold by asking the user for their first
  ask.
- Non-empty → use the argument verbatim as ask #1, then proceed to ask
  for the next one.

## Conventions

- User-global rules at `@references/task-execution.md` and per-project
  rule files (`.claude/rules/*`, `CLAUDE.md`, `CONTRIBUTING.md`) always
  apply. Read them at run time — do not assume.
- Chat replies to the user stay in Japanese per the global communication
  preference. The reviewer prompt and structured outputs can be English
  for precision.
- This skill **never edits files, opens PRs, or files Issues**. It
  STOPS after presenting; the user picks the next action.

## Externalize state

The whole flow can span many turns and may survive compaction. Maintain
a progress file under the session scratchpad (the harness-provided path,
NOT `/tmp`):

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

1. If `$ARGUMENTS` is non-empty, record it verbatim as ask #1 and skip to
   step 3. Otherwise ask plainly (free text, NOT `AskUserQuestion`):
   「やりたいこと・相談したいことを1つ教えてください」.
2. Wait for the user's reply. Record it verbatim in the scratchpad as the
   next ask.
3. Acknowledge in one short line (「受け取りました: <要約>」) and ask:
   「他にもありますか? なければ『以上です』『終わり』などとお伝えくだ
   さい」.
4. Repeat steps 2–3 until the user signals done. Done signals include
   「以上」「終わり」「それで全部」「以上です」「これだけ」"no more"
   "done", or any unambiguous equivalent. If a message could be either a
   done signal or another ask, ask which it is — do not guess.

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

Show a compact list of groups to the user inline — one line per group,
no question, just a summary. If a single group covers everything, say so
explicitly. Do not over-decompose; when in doubt, keep things grouped.

## Phase 3 — Draft solutions

For each group, draft a solution: what to do, in what order, with
explicit done-criteria. Apply existing house style — conclusion first,
bullets, no filler — and obey the repo conventions read on entry.

If a draft genuinely needs a user decision to proceed (forks in the
road, not preferences you can recommend), batch decisions into a single
`AskUserQuestion` call (≤4 questions). Up front in the same reply, list
every decision you are NOT asking about and the default you'll apply.
For each question, give a 5-point recommendation level and the
reasoning. Reserve `AskUserQuestion` for real forks — bikeshedding gets
stated as defaults.

Record the draft in the scratchpad. **Do not present the draft to the
user yet.** The next phase is review.

## Phase 4 — Fresh-eyes review (loop, max 3 rounds)

Spawn ONE subagent per round (`general-purpose` is the safe default;
`code-explore` also works when the review needs only Read/Grep and the
cheaper model is acceptable). The prompt MUST be self-contained — the
reviewer has no prior conversation context.

Each round's prompt MUST:

- State the reviewer's role: 「あなたは外部レビュアーです。以下のユー
  ザー要望と解決策案を読み、OK か NG かを判定してください」.
- Hand it:
  - The collected asks (verbatim, by group).
  - The current draft solution (full, no abbreviations).
  - The repo root path and pointers to project-relevant conventions
    (`CLAUDE.md`, `.claude/rules/*`) — do not copy-paste them.
- Tell the reviewer it has no prior context and to treat the asks +
  draft + repo as the only sources of truth.
- Forbid the reviewer from validating the draft — it is looking for
  what the planner missed, not confirming the work.
- Demand structured output in this exact shape, with no preamble and no
  closing summary:

  ```
  Verdict: OK | NG
  ## Findings
  - Coverage: does the draft answer every ask? (List missed asks.)
  - Contradictions: claims that disagree within the draft, across
    groups, or with repo conventions.
  - Hazards: concrete failure modes the draft would hit at runtime or
    rollout (correctness, security, ops, supply chain, …). Name the
    mode.
  - Overlooked: things a competent planner would address but didn't
    (edge cases, observability, rollback, …).
  ## Top issues (only if Verdict = NG)
  1. ...
  2. ...
  3. ...
  ```

- Verdict rules: NG if ANY ask is unanswered OR there is at least one
  Hazard / Contradiction / Overlooked finding that would change the
  plan. Otherwise OK. Style-only nits do NOT make a draft NG; capture
  them as advisory for the final presentation.

Loop (illustrative pseudocode — not runnable):

```
round = 1
while round <= 3:
    review = run_review(draft)
    if review.verdict == OK:
        break
    revise(draft, review.findings)           # Phase 3 logic, scoped to findings
    if a real fork appeared → AskUserQuestion # batched, with defaults stated
    round += 1
```

Record every round in the scratchpad (verdict + findings + revisions
made + any user decisions taken).

Failure modes to handle:

- Reviewer returns malformed output → treat as NG, log the malformation,
  consume one round.
- Reviewer flags only style nits → treat as OK, note nits as "advisory"
  in the final presentation.
- Same finding survives two rounds unchanged (same Top-issues item by
  substring overlap, or the reviewer self-quotes the previous round) →
  escalate to the user with a single `AskUserQuestion` ("reviewer keeps
  flagging X — accept current draft / override the finding / abandon
  this group") rather than burning the third round on the same loop.

## Phase 5 — Present (OK or NG-after-3) — then STOP

### Verdict OK

Present, in Japanese, in this shape:

```
## 解決策 (レビューOK / N周目で通過)

### グループ1: <名前>
- 何をやるか
- 順序
- 完了条件

### グループ2: …

## レビュー履歴 (要約)
- Round 1: NG — <主な指摘> → <修正>
- Round 2: OK

## 助言レベル (任意で取り込み)
- <style nits / advisoryがあれば>
```

Then state plainly: 「以上です。issue化・別エージェントへ委譲などの次
のアクションは任意に進めてください」.

### Verdict NG after 3 rounds

Present, in Japanese:

```
## 解決策案 (レビュー未通過 — 3周打ち切り)
<最終ドラフト>

## 通過しなかった理由
- 残った Findings (種別ごと):
  - Coverage: …
  - Contradictions: …
  - Hazards: …
  - Overlooked: …
- 各 Round で何を修正したか / なぜ通らなかったか

## 推奨
- 要望を絞り直すか、分割してから再度この skill を呼んでください。
- 残った Findings の中で「許容」したいものがあれば、それを明示して再
  度呼ぶと通過しやすくなります。
```

STOP. Do NOT silently soften the draft to claim OK — a real failure is a
finding to surface, not an obstacle to remove.

## What this skill does NOT do

- It does NOT file GitHub Issues, open PRs, edit code, or delegate to
  implementer agents. After presenting, the skill ends — the user picks
  the next action (`/audit-issues`, `/tackle-issues`, manual
  delegation, hold, …).
- It does NOT answer asks during Phase 1 intake. Intake and answering
  are separated on purpose so grouping is honest.
- It does NOT pre-validate the draft itself — the whole point of the
  review loop is an unanchored second opinion. If you find yourself
  agreeing with the draft before review, that is a hint to start
  Phase 4, not a substitute for it.
