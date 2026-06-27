---
description: Audit the codebase across security / maintainability / UX, then file GitHub Issues (independent issues separately; related ones under a parent epic with native sub-issues).
argument-hint: "[optional scope: security | maintainability | ux | all (default)]"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Task
---

# Quality Audit → Issue Filing

Reproduce the standing review workflow: evaluate the current codebase across
three axes, report findings concisely, and — **after the user approves** — file
GitHub Issues with correct grouping.

This command is project-agnostic: discover the repo's actual architecture,
stack, and conventions at run time. The concrete file names / APIs in the
checklists below are **examples** — translate each into the equivalent for
whatever language, framework, and layout this repo actually uses.

Scope argument (`$ARGUMENTS`): `security`, `maintainability`, `ux`, or `all`
(default when empty). When a single axis is given, only audit that axis.

## Conventions to follow

- User-global rules at `@references/git-workflow.md` always apply for any
  commits this skill produces.
- Read whatever project rules exist first — e.g. `.claude/rules/git-workflow.md`
  (especially any **Sub-Issue Linking** section), plus any coding-standards /
  framework-pattern / `CLAUDE.md` / `CONTRIBUTING.md` docs the repo ships. Don't
  assume a specific rule file exists; check, then honor what's there.
- **Write issue bodies in the repo's language.** Match the language of the
  existing issues and any stated language policy (e.g. Japanese if the repo's
  issues are Japanese; English otherwise). This command file and your reasoning
  stay in English.
- Reuse, don't duplicate: the `issue-manager` agent owns issue formatting and
  the `project-investigator` agent owns generic health checks. This command is
  the **quality-audit + grouped-filing** flow specifically.

## Step 1 — Survey

- Map the tree and file sizes. Discover the source dirs and extensions from what
  the repo actually contains rather than assuming — e.g. list tracked files and
  sort by size: `git ls-files | xargs wc -l 2>/dev/null | sort -rn | head -40`
  (or a `find` scoped to the repo's real source directories / extensions).
- List open issues (`gh issue list --state open`) to avoid duplicates.
- Note recent commits for context (`git log --oneline -10`).

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

### Maintainability / extensibility (redundant or overly-technical code)

- **Dead/unused modules** (e.g. leftovers from a migration or framework switch):
  fully-present but unreferenced code. Verify with a repo-wide grep for callers.
- **Overly-technical or redundant implementations** that hurt future changes:
  oversized files, duplicated logic, premature abstraction, contract drift.
- **Misleading naming** (e.g. names referencing an old framework/API the code no
  longer uses).
- Suppressed-warning accumulation (`#[allow(dead_code)]`, `eslint-disable`,
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
which cluster under a parent epic, with labels and priority. **Ask the user to
approve before creating anything** (this command never auto-files).

## Step 4 — File issues (only after approval)

Grouping rule:

- **Independent topics → separate issues.**
- **Related topics (same module/theme) → one parent epic + native sub-issues.**
  Create the parent first, then children, then link them using the project's
  established sub-issue method (e.g. `gh issue create --parent <n>` /
  `gh issue edit --add-sub-issue`, or the GitHub `sub_issues` REST API with each
  child's integer **database id** — see the repo's git-workflow Sub-Issue Linking
  notes if present). Also keep a Markdown checklist in the parent body.

Each issue body uses this shape (in the repo's language; Japanese headings shown
as an example because that's common here):

```
## 背景 (Background)
## 方針(要検討)   ← when the fix needs design discussion
## 受け入れ条件     ← checkbox list, ending with the relevant green checks
## 補足            ← priority + parent ref (e.g. 親: #NN)
```

Apply labels from **the repo's existing label set** (`gh label list`). Common
ones: `security`, `enhancement`, `bug`, `documentation`, plus area labels the
repo defines (e.g. `backend` / `frontend` / `ui` / `infrastructure`). Don't
invent labels the repo doesn't have. End each body with the Claude Code footer.

After creation, print the issue numbers, the parent→sub links, and which to
tackle first.
