#!/usr/bin/env bash
# Idempotently register this repo's hooks in ~/.claude/settings.json.
#
# settings.json is per-machine (not symlinked by homeshick), so run this once on each
# new macOS host after `homeshick link`:
#   ~/.claude/hooks/install-hooks.sh
#
# Registered hooks (event -> script [sound]):
#   Stop             -> notify.sh    silent        (desktop notification on finish)
#   Notification     -> notify.sh    Ping          (desktop notification on input wait)
#   UserPromptSubmit -> prompt-repetition-nudge.sh (suggest a skill/alias on repeats)
#   UserPromptSubmit / Notification / Stop / SessionStart / SessionEnd
#                    -> tmux-status.sh             (pane status icon in tmux)
#
# Per-event sounds are overridable via env when running this script:
#   CLAUDE_STOP_SOUND=Glass CLAUDE_NOTIFICATION_SOUND=Hero ~/.claude/hooks/install-hooks.sh
# An empty value (the Stop default) yields a silent banner.
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
  "UserPromptSubmit tmux-status.sh"
  "Notification tmux-status.sh"
  "Stop tmux-status.sh"
  "SessionStart tmux-status.sh"
  "SessionEnd tmux-status.sh"
)

# notify.sh and tmux-status.sh take the event as an argument; other scripts read
# everything from stdin.
arg_for() { case "$1" in notify.sh|tmux-status.sh) printf ' %s' "$2" ;; *) printf '' ;; esac; }

# Per-event CLAUDE_NOTIFY_SOUND prefix, applied to notify.sh only. An explicitly
# empty value yields a silent banner (notify.sh drops the `sound name` clause when
# CLAUDE_NOTIFY_SOUND is set-but-empty). Other scripts/events get no prefix.
sound_for() {
  [ "$2" = notify.sh ] || { printf ''; return; }
  case "$1" in
    Stop)         printf 'CLAUDE_NOTIFY_SOUND=%s ' "${CLAUDE_STOP_SOUND-}" ;;
    Notification) printf 'CLAUDE_NOTIFY_SOUND=%s ' "${CLAUDE_NOTIFICATION_SOUND-Ping}" ;;
    *)            printf '' ;;
  esac
}

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

mkdir -p "$(dirname "$settings")"
[ -f "$settings" ] || echo '{}' > "$settings"

for entry in "${hooks[@]}"; do
  event="${entry%% *}"
  script="${entry##* }"
  cmd="$(sound_for "$event" "$script")~/.claude/hooks/${script}$(arg_for "$script" "$event")"

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
