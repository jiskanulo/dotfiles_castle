---
name: audit-issues
description: This skill should be used when the user asks to "audit the codebase", "review code quality", "find security issues", "check maintainability", "file GitHub issues from review", or wants a three-axis (security/maintainability/UX) quality audit that ends in filed Issues. Reports findings first, asks for approval, then files independent topics as separate issues and related topics under a parent epic with native sub-issues. Optionally narrows to a single axis (security / maintainability / ux) when the user names one.
allowed-tools: Read, Grep, Glob, Bash, Agent, AskUserQuestion
---

# Quality Audit → Issue Filing

Evaluate the current codebase across three axes, report findings concisely,
then file GitHub Issues with correct grouping after the user approves at
the Step 3 gate.

This skill is project-agnostic: discover the repo's actual architecture,
stack, and conventions at run time. The concrete file names / APIs in the
checklists below are **examples** — translate each into the equivalent for
whatever language, framework, and layout this repo actually uses.

Scope: if the user names a single axis (`security`, `maintainability`, `ux`,
case-insensitive), audit only that axis; otherwise audit all three.

## Conventions to follow

- For sub-issue linking and `gh` usage, follow the `# GitHub CLI (gh)` block
  in user-global `CLAUDE.md`: prefer native `gh issue create --parent <n>` and
  `gh issue edit <n> --add-sub-issue`; `gh api` is fallback only.
- Read whatever project rules exist first — coding-standards / framework-pattern
  / `CLAUDE.md` / `CONTRIBUTING.md` docs the repo ships. Don't assume a specific
  rule file exists; check, then honor what's there.
- **Write issue bodies in the repo's language.** Match the language of the
  existing issues and any stated language policy (e.g. Japanese if the repo's
  issues are Japanese; English otherwise). This skill body and your reasoning
  stay in English.
- Reuse, don't duplicate: delegate the actual issue filing (Step 4) to the
  `issue-manager` agent, which owns issue formatting. This skill is the
  **quality-audit + grouped-filing** flow specifically.

## Step 1 — Survey

Delegate the survey to a `code-explore` subagent (per the role-based model
selection rules in user-global CLAUDE.md). Pass these instructions:
- Map the tree and file sizes. Discover the source dirs and extensions from
  what the repo actually contains rather than assuming.
- List open issues (`gh issue list --state open --limit 100`) to avoid duplicates.
- Note recent commits for context (`git log --oneline -10`).
- Return only conclusions (key paths, top large files, existing issue titles,
  recent themes) — not raw command output.

Keep only the conclusions in the main context.

## Step 2 — Evaluate (per requested scope)

For each finding, **verify empirically before asserting** — do not guess:

- "Dead code" → grep for callers outside the file/tests first.
- "Config gap" → read the actual config/value before claiming it (the relevant
  config file, builder options, env, etc. for this stack).

The bullets below are **generic risk patterns**; the parenthetical paths/APIs
are illustrative. Find each pattern's real location in this repo (or note it
doesn't apply to this stack).

### Security

- **Outbound request / SSRF**: any code fetching user-influenced URLs —
  HTTPS/scheme enforcement, host allowlist, local/private-IP blocking, and
  **redirect policy** (does the HTTP client follow redirects past validation?).
- **Path traversal**: input→path construction and any `is_within`/containment
  check before filesystem reads/writes/deletes.
- **Command/subprocess injection**: external-process calls — pass an argument
  vector (no shell), escape/length-cap interpolated metadata.
- **SQL injection**: confirm every query uses parameter binding, never
  string-interpolated SQL.
- **Platform/framework hardening**: the app framework's security surface — e.g.
  (web) CSP/CORS, (desktop frameworks like Tauri/Electron) the config's CSP +
  asset/permission scopes and least-privilege capability grants, (server) auth
  middleware coverage.
- **Privilege/secrets**: user-overridable binary/exec paths, secrets in logs or
  persisted settings.

### Maintainability

- **Dead/unused modules** (e.g. leftovers from a migration or framework switch):
  fully-present but unreferenced code. Verify with a repo-wide grep for callers.
- **Overly-technical or redundant implementations** that hurt future changes:
  oversized files, duplicated logic, premature abstraction, contract drift.
- **Misleading naming** (e.g. names referencing an old framework/API the code no
  longer uses).
- **Suppressed-warning accumulation** (`#[allow(dead_code)]`, `eslint-disable`,
  `# type: ignore`, `//nolint`, …) without a documented reason.

### UX

- **Error surfacing**: are friendly/localized messages actually wired to the UI,
  or does the UI render raw backend strings? (Check the message catalog/source
  vs. the components that display errors.)
- **Runtime correctness**: concurrent-operation guards (e.g. double submit),
  cancellation semantics (UI state vs. actual backend stop).
- **Asset/display robustness**: media/image fallbacks (onError vs. CSS), and
  empty / loading / error states.
- **Settings/path edge cases**: behavior when inputs/paths fall outside expected
  scopes.

## Step 3 — Report (then STOP for approval)

Write per the user's style: **conclusion first, information-dense, bullets**,
no filler. For each finding give: file:line, the concrete risk/cost, a proposed
fix, and a 5-point recommendation level. Group findings by axis.

Then propose the **filing plan**: which findings become standalone issues vs.
which cluster under a parent epic, with labels and priority. **Ask via
`AskUserQuestion` before creating anything** (this skill never auto-files).

## Step 4 — File issues (only after approval)

Grouping rule:

- **Independent topics → separate issues.**
- **Related topics (same module/theme) → one parent epic + native sub-issues.**
  Create the parent first, then create children with `gh issue create
  --parent <n>` (which links at creation time). Use `gh issue edit <n>
  --add-sub-issue` only to attach pre-existing issues. Fall back to `gh api
  .../sub_issues` only when the installed `gh` lacks these flags. Rely on
  GitHub's native sub-issue panel for tracking — do not duplicate a Markdown
  checklist of children in the parent body.

Delegate the filing itself to the `issue-manager` agent; have it return the
created issue numbers and parent→sub links.

Each issue body uses this shape (in the repo's language).

English repos:

```
## Background
## Approach (needs design)  ← only when the fix needs design discussion
## Acceptance criteria   ← checkbox list with verification items
## Notes                 ← priority + parent ref (e.g. parent: #NN)
```

Japanese repos (use these headings instead):

```
## 背景
## 方針(要検討)     ← 修正方針に検討が必要なときだけ
## 受け入れ条件     ← チェックボックスリスト、検証項目を含む
## 補足            ← 優先度 + 親 ref (例: 親: #NN)
```

Apply labels from **the repo's existing label set** (`gh label list`). Common
ones: `security`, `enhancement`, `bug`, `documentation`, plus area labels the
repo defines (e.g. `backend` / `frontend` / `ui` / `infrastructure`). Don't
invent labels the repo doesn't have.

After creation, print the issue numbers, the parent→sub links, and which to
tackle first.
