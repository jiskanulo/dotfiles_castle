#!/usr/bin/env bash
# Idempotently register this repo's hooks in ~/.claude/settings.json.
#
# settings.json is per-machine (not symlinked by homeshick), so run this once on each
# new macOS host after `homeshick link`:
#   ~/.claude/hooks/install-hooks.sh
#
# Registered hooks (event -> script):
#   Stop             -> notify.sh                  (desktop notification on finish)
#   Notification     -> notify.sh                  (desktop notification on input wait)
#   UserPromptSubmit -> prompt-repetition-nudge.sh (suggest a skill/alias on repeats)
#
# Safe to re-run: for each event it drops any existing hook pointing at the same
# script (matched by basename) before re-adding, and leaves the rest of
# settings.json untouched. Requires jq.
set -euo pipefail

settings="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

# Each entry: "<HookEvent> <script-basename>". The registered command is
# "~/.claude/hooks/<script> [<HookEvent>]"; the unquoted ~ is tilde-expanded by the
# shell at hook run time (paths have no spaces). Dedup matches the script basename.
hooks=(
  "Stop notify.sh"
  "Notification notify.sh"
  "UserPromptSubmit prompt-repetition-nudge.sh"
)

# notify.sh takes the event as an argument; other scripts read everything from stdin.
arg_for() { case "$1" in notify.sh) printf ' %s' "$2" ;; *) printf '' ;; esac; }

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

mkdir -p "$(dirname "$settings")"
[ -f "$settings" ] || echo '{}' > "$settings"

for entry in "${hooks[@]}"; do
  event="${entry%% *}"
  script="${entry##* }"
  cmd="~/.claude/hooks/${script}$(arg_for "$script" "$event")"

  tmp="$(mktemp)"
  jq \
    --arg event "$event" \
    --arg script "$script" \
    --arg cmd "$cmd" \
    '
    .hooks //= {}
    # drop any prior hook for this event whose command references the same script
    # (literal substring match), so re-running stays clean
    | .hooks[$event] = ((.hooks[$event] // []) | map(select(any(.hooks[]?; .command | contains($script)) | not)))
    | .hooks[$event] += [{ "hooks": [{ "type": "command", "command": $cmd }] }]
    ' "$settings" > "$tmp"
  mv "$tmp" "$settings"
  echo "Registered $event -> $script in $settings"
done
