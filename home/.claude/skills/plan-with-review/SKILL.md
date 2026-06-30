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

Loop (illustrative pseudocode — not runnable). State is per-group, with
escalation decided per group (not per bullet):

```
groups = { g: {round: 1, draft: draft_g, status: "in-review"} for g in all_groups }

while any(g.status == "in-review" for g in groups.values()):
    in_review = {g: groups[g] for g in groups if groups[g].status == "in-review"}
    if not in_review: break
    review = run_review({g: in_review[g].draft for g in in_review})

    if review.verdict == OK:
        for g in in_review: groups[g].status = "ok"
        break

    # NG round: use per-group verdicts to advance groups individually
    ng_groups = {pgv.group for pgv in review.per_group_verdicts if pgv.verdict == NG}
    for g in in_review:
        if g not in ng_groups:
            groups[g].status = "ok"          # absent from NG → this group is fine

    # Group surviving bullets by group (dedup: one decision per group)
    survivors_by_group = {}                  # g -> [bullet]
    for bullet in review.top_issues:
        if bullet.group in ng_groups and repeat_detected(bullet.group, bullet):
            survivors_by_group.setdefault(bullet.group, []).append(bullet)

    # Escalate per group (≤4 batch in one AskUserQuestion; >4 serialize)
    decisions = ask_per_group(survivors_by_group)   # g -> Accept|Override|Abandon
    for g, choice in decisions.items():
        if choice == "Accept":  groups[g].status = "accepted"
        if choice == "Abandon": groups[g].status = "abandoned"
        if choice == "Override":
            # round does NOT advance; suppress repeat-detection for this
            # bullet on the next round; revise excludes the overridden
            # finding from the payload
            pass

    # For NG groups that did NOT escalate (no repeat detected), advance + revise
    for g in ng_groups:
        if g in decisions and decisions[g] != "Override":
            continue
        if g in decisions and decisions[g] == "Override":
            # halt guard: if every NG bullet for g was Overridden AND no
            # non-Override revision happened this round, mark g ok to
            # prevent stalling
            if all_bullets_overridden_no_other_findings(g, review):
                groups[g].status = "ok"
            continue
        # auto-revise from this group's findings (with group attribution)
        revise(groups[g].draft, [f for f in review.findings if f.group == g])
        groups[g].round += 1
        if groups[g].round > 3:
            groups[g].status = "ng-after-3"
```

Record every round in the scratchpad (verdict + findings + revisions
made + any user decisions taken).

Failure modes to handle:

- Reviewer returns malformed output → re-prompt once with an explicit
  schema reminder. If still malformed, treat as NG and consume the
  round.
- Reviewer flags only the Style line → treat as OK; carry those nits to
  the final presentation as advisory.
- Same Top-issues bullet survives two rounds unchanged → escalate to the
  user via `AskUserQuestion`. Detection is orchestrator-side: load the
  prior round's Top-issues for the relevant group from the scratchpad and
  compare to the current round's bullets for that group. Token metric
  (fixed for determinism): strip the leading `[group: <name>]` prefix
  from each bullet first. Then, if the bullet is ASCII-only, case-fold
  the text, split on whitespace into tokens, strip trailing `.,;:!?`
  from each token, keep stopwords, and match when
  `|A ∩ B| / min(|A|, |B|) ≥ 0.6`. If the bullet contains non-ASCII
  (e.g. CJK), use character-bigram Jaccard instead: collect all
  2-character substrings and match when `|A ∩ B| / |A ∪ B| ≥ 0.5`. The
  detection compares round N to round N-1 only; a bullet that disappears
  in N-1 and resurfaces in N is not escalated (intentional — a one-round
  break is taken as progress). Detection covers the Top-issues bullets;
  Findings-block items that never make Top-issues are deliberately out of
  scope. The reviewer itself has no prior-round context (per the "no prior
  conversation context" rule above) and cannot detect this on its own.

  **Group attribution.** The schema returns one global Top-issues list; the
  reviewer prompt MUST require each Top-issues bullet to begin with
  `[group: <group name>]` so the orchestrator can attribute bullets back
  to groups. Update the schema example accordingly. Use exactly three
  mutually exclusive options with a 5-point recommendation each. Each
  option resolves the *group* the surviving bullet belongs to. If multiple
  groups have a surviving bullet in the same round, batch into one
  `AskUserQuestion` call when ≤ 4 groups; otherwise serialize the
  escalations one group at a time.
  - **Accept current draft (treat finding as known limit)** — record the
    accepted finding in the scratchpad. The group's `status` becomes
    `accepted`; its draft moves to Phase 5 as-is. No further reviewer
    rounds for this group.
  - **Override finding (mark advisory, continue review)** — record the
    overridden bullet in the scratchpad and add it to the next round's
    reviewer prompt as "this item was overridden by the user; do not
    flag it again." Suppress repeat-detection for this bullet next round.
    The group's `round` counter does **not** advance for this escalation;
    the next reviewer call still counts as the same round number that
    triggered the escalation.
  - **Abandon this group** — set group's `status` to `abandoned`. It does
    not appear in subsequent reviewer prompts or in Phase 5.

## Phase 5 — Present — then STOP

At Phase 5 entry each group is in one of: `ok`, `accepted` (via escalation),
`abandoned`, or `ng-after-3`. Present a single combined report whose top-
level shape depends on what's present:

- All groups `ok` (no escalations, no NG-after-3) → use the **All-OK
  template** below.
- All groups `ng-after-3` → use the **All-NG-after-3 template** below.
- Mixed (any combination of `ok` / `accepted` / `abandoned` / `ng-after-3`)
  → use the **Mixed template** below.

### All-OK template

Present, in Japanese, in this shape:

```
## 解決策 (レビューOK / <N>周目で通過)   ← <N> は OK が出たラウンド番号

### グループ1: <名前>
- 何をやるか
- 順序
- 完了条件

### グループ2: …

## レビュー履歴 (要約)
- <ラウンド番号>: <verdict> — <NGなら主な指摘 → 修正、OKなら省略>
- ... (実際に走ったラウンド数だけ列挙)

## 助言レベル (任意で取り込み)
- <style nits / advisoryがあれば>
```

Then state plainly: 「以上です。issue化・別エージェントへ委譲などの次
のアクションは任意に進めてください」.

### All-NG-after-3 template

Present, in Japanese:

```
## 解決策案 (レビュー未通過 — 3周打ち切り)
<最終ドラフト — Round 3 の指摘を反映した修正後のドラフト。
 このバージョンはまだレビューを受けていない点に注意>

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

### Mixed template

Present, in Japanese:

```
## 解決策 (グループごとに状況が異なる)

### グループ1: <名前> (status: ok | accepted | abandoned | ng-after-3)
- 何をやるか
- 順序
- 完了条件
  (abandoned の場合はドラフトなし、status のみ表示)
  (ng-after-3 の場合は「Round 3 反映済み・未レビュー」と明記)

### グループ2: …

## レビュー履歴 (要約)
- <ラウンド番号>: <verdict> — <NGなら主な指摘 → 修正、OKなら省略>
- ... (実際に走ったラウンドだけ列挙)

## NG / abandoned summary
- <グループ名> (ng-after-3): <残った Findings>
- <グループ名> (abandoned): <ユーザーが abandon を選んだ理由>
- (accepted は user が override 込みで OK としたものなので summary 不要)

## 助言レベル (任意で取り込み)
- <style nits / advisoryがあれば>
```

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
