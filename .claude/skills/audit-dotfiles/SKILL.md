---
name: audit-dotfiles
description: This skill should be used when the user asks to "audit dotfiles", "verify dotfiles", "dotfiles health check", "check for stale configs", "find config improvements", "設定と実環境の乖離を検証", "dotfiles を検証", "より良い設定ができる場所を調査", "改善できる場所", or wants this castle's tracked configs verified against the live machine — installed tools/apps, symlink state, reference chains, and effective behavior. Reports findings with 5-point recommendation levels, then resolves minor items one question at a time.
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion
---

# Dotfiles Audit (config vs live environment)

Verify that what this castle tracks matches the machine it runs on. The
dominant failure mode is **semantic rot**: a file that exists but whose
premise is false (an empty template, a tool no longer installed, a
fragment never sourced). Path-existence checks alone cannot catch this —
probe the live environment.

## Step 0 — Load the accepted-state list

Read the auto-memory `project_dotfiles_audit_accepted_state.md` (via
MEMORY.md). Entries there are deliberate user decisions — do NOT
re-report them as findings. If the environment has changed around one
(e.g. the app got reinstalled), report that as an update to the list
instead.

## Step 1 — Inventory and symlink state

- `git ls-files` for the tracked set.
- For each tracked leaf, check the `$HOME` side: LINKED (symlink into the
  castle) / REAL (shadowing file) / ABSENT. REAL and ABSENT are findings
  (un-linked tracking).

## Step 2 — Probe the live environment

- **Commands**: `command -v` every binary the configs reference (pagers,
  aliases, plugin managers, conditional sources). MISSING + referenced =
  finding.
- **Apps**: `brew list --cask`, `/Applications`, `~/Applications` for
  GUI apps whose configs are tracked (terminal, keyboard remappers,
  automation tools).
- **Reference chains**: fragments actually sourced from `.zshrc`/`.zprofile`
  (orphans are findings), pager/hook commands actually resolvable, paths
  referenced inside configs actually existing. Guarded references
  (`(N-/)`, `command -v` checks, `2>/dev/null`) are defensive, not
  findings.

## Step 2b — Probe effective behavior and cross-layer interactions

Measure, don't infer: report an effect only after reproducing it, and
correct a finding as soon as a measurement contradicts it.

- **Key routing across layers** (terminal → tmux → shell → app): the tmux
  prefix must not swallow keys apps bind (e.g. C-t vs fzf's Ctrl-T), the
  terminal must send Option as Alt where Alt bindings exist, and the zsh
  keymap / `KEYTIMEOUT` must be explicit.
- **Recipes**:
  - vim effective options:
    `vim --not-a-term -c 'redir! > F | set opt? | redir END' -c 'qa!' </dev/null`.
    Never `-u ~/.vimrc` or `-es`: they keep `compatible` / Ex-mode
    defaults and report wrong values.
  - Cell width and pager rendering: a detached
    `tmux new-session -d -s T -x W -y H "<cmd>; exec sleep 5"`, then
    `tmux display -p -t T '#{cursor_x}'` or `tmux capture-pane -p -t T`;
    kill the session afterwards.
  - zsh keymap: `env VISUAL=… zsh -i -c 'bindkey -lL main'` (without an
    explicit `bindkey -v`/`-e`, the keymap follows `$VISUAL`/`$EDITOR`).
  - Ghostty defaults with their docs: `ghostty +show-config --default --docs`.
  - Commands launched by tmux run under non-interactive `$SHELL -c`; check
    that wrapper functions still apply with `zsh -c 'whence -w <cmd>'`.

## Step 3 — Classify and report

House style: conclusion first, dense, bullets. Group as:

1. **バグ** — config silently broken (typo, dead pager, never-enabled
   option). Highest priority.
2. **実態と乖離** — config for tools/apps not installed, orphaned files,
   falsified doc claims.
3. **軽微** — obsolete flags, dead sections, cosmetic drift.

Every finding: file:line, evidence (what was probed), proposed fix, and a
5-point recommendation level.

## Step 4 — Resolve

- Bugs: fix directly (with user visibility), one intent per commit.
- 乖離 / 軽微: decide **one item per AskUserQuestion**, background stated
  immediately before the question and key points repeated in the option
  descriptions (per `feedback_minor_findings_one_by_one`). Sub-items of
  the same file and concern may share one multiSelect question.
- Deletions follow `feedback_dotfiles_workflow`: `git rm`, then `mv` the
  dangling `$HOME` symlink into the session scratchpad (only if that fails,
  hand the user a `! rm -f <HOME path>` line).
- Decisions that suppress future findings go into
  `project_dotfiles_audit_accepted_state.md`.
