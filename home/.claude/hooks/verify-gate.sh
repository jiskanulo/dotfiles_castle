#!/usr/bin/env bash
# Stop-hook verification gate for Claude Code.
#
# Enforces the task-execution discipline (@references/task-execution.md): if code
# was edited this session but no verification command (test / build / lint /
# typecheck) ran afterward, block the stop ONCE and send the agent back to verify
# what it touched. Prose in CLAUDE.md is advisory; this hook makes it bite.
#
# Wired from ~/.claude/settings.json:
#   "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/verify-gate.sh" }] }]
#
# Stdin: the Stop-hook JSON payload (.transcript_path, .stop_hook_active, .cwd).
# Output: {"decision":"block","reason":"…"} to stdout when a verify is missing;
#         nothing (exit 0) when verification ran, no edits happened, we already
#         nudged once, or the project has no verify harness at all (no
#         package.json / Cargo.toml / Makefile / … from cwd up to $HOME).
#         Fails OPEN on any error — never wedges a session shut.
#
# The once-only guard (.stop_hook_active) is what makes "no verification applies"
# work: after the nudge the agent states N/A (or verifies) and stops again; the
# second stop carries stop_hook_active=true and passes straight through.

set -euo pipefail

payload="$(cat)"

# jq is required; without it, fail open rather than block work.
command -v jq >/dev/null 2>&1 || exit 0

# Already nudged once this stop-cycle → let the agent through (loop guard).
if [[ "$(printf '%s' "$payload" | jq -r '.stop_hook_active // false')" == "true" ]]; then
  exit 0
fi

transcript="$(printf '%s' "$payload" | jq -r '.transcript_path // empty')"
[[ -n "$transcript" && -f "$transcript" ]] || exit 0

# Gate only in projects that actually have a verify harness. Walk from cwd up
# to $HOME (or /) looking for a build/test marker; if none exists there is no
# real check to run (dotfiles, plain-text repos, scratch dirs) — pass silently.
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
if [[ -n "$cwd" && -d "$cwd" ]]; then
  markers=(
    package.json Cargo.toml Makefile justfile go.mod pyproject.toml setup.py
    setup.cfg Gemfile composer.json build.gradle build.gradle.kts pom.xml
    mix.exs CMakeLists.txt deno.json deno.jsonc tsconfig.json
  )
  dir="$cwd" found=0
  while :; do
    for m in "${markers[@]}"; do
      if [[ -e "$dir/$m" ]]; then
        found=1
        break 2
      fi
    done
    [[ "$dir" == "/" || "$dir" == "$HOME" ]] && break
    dir="$(dirname "$dir")"
  done
  (( found )) || exit 0
fi

# Verify-ish command patterns. Broad on purpose: we only need to detect that SOME
# verification was attempted — the agent picks the project's actual command.
verify_re='(^|[^a-z])(test|spec|pytest|jest|vitest|mocha|rspec|phpunit|ctest|go +test|cargo +(test|build|check|clippy)|tsc|typecheck|type-check|lint|eslint|biome|ruff|mypy|flake8|build|gradle|mvn|make( |$)|just( |$)|npm +(run +)?(test|build|lint|typecheck)|pnpm +(run +)?(test|build|lint|typecheck|check)|yarn +(test|build|lint|typecheck)|bun +(test|run)|dotnet +(test|build))'

# Walk the transcript in order, emitting one line per tool_use:
#   EDIT   — an Edit/Write/MultiEdit/NotebookEdit call against a code file
#   VERIFY — a Bash call whose command matches verify_re
#   OTHER  — anything else (incl. docs/config-only edits: .md/.json/.toml/.yml,
#            and scratchpad writes under /tmp/claude-* or /private/tmp/claude-*)
# Docs/config-only edits and scratchpad writes are filtered out so a markdown
# tweak or a temp file write does not wedge the next Stop until you fake a
# verify command. The moment a real code file is edited, the gate re-engages.
# Then: did a VERIFY occur at or after the LAST EDIT?
result="$(
  jq -rs --arg re "$verify_re" '
    [ .[]
      | (.message.content // empty)
      | if type=="array" then .[] else empty end
      | select(type=="object" and .type=="tool_use")
      | if ((.name // "") | test("^(Edit|Write|MultiEdit|NotebookEdit)$")) then
          (if (.name // "") == "NotebookEdit" then (.input.notebook_path // "") else (.input.file_path // "") end) as $fp
          | (if ($fp | test("\\.(md|json|toml|ya?ml)$"; "i"))
                  or ($fp | test("^/(private/)?tmp/claude-"))
             then "OTHER" else "EDIT" end)
        elif (.name // "") == "Bash"
             and ((.input.command // "") | ascii_downcase | test($re)) then "VERIFY"
        else "OTHER" end
    ] as $ev
    | ($ev | index("EDIT")) as $hasEdit
    | if $hasEdit == null then "noedit"
      else
        ([ $ev | to_entries[] | select(.value=="EDIT") | .key ] | last) as $lastEdit
        | ([ $ev | to_entries[] | select(.value=="VERIFY" and (.key >= $lastEdit)) ] | length) as $verifiedAfter
        | if $verifiedAfter > 0 then "verified" else "unverified" end
      end
  ' "$transcript" 2>/dev/null || echo "error"
)"

[[ "$result" == "unverified" ]] || exit 0

jq -n '{
  decision: "block",
  reason: "You edited code this session but ran no verification (test / build / lint / typecheck) afterward. Per the task-execution discipline, verify what you touched: run the project'"'"'s real checks for the changed area (invoke them the way the repo documents — wrapper / version-manager / container included). If verification genuinely does not apply — e.g. a docs- or config-only change — or you already verified another way, state that in one line and stop. Do not weaken or skip tests to pass."
}'
