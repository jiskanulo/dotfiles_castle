#!/usr/bin/env bash
# Idempotently register the notify.sh Stop/Notification hooks in ~/.claude/settings.json.
#
# settings.json is per-machine (not symlinked by homeshick), so run this once on each
# new macOS host after `homeshick link`:
#   ~/.claude/hooks/install-notify-hooks.sh
#
# Safe to re-run: it replaces any existing Stop/Notification hooks that point at notify.sh
# and leaves the rest of settings.json untouched. Requires jq.
set -euo pipefail

settings="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
cmd_stop='"$HOME/.claude/hooks/notify.sh" Stop'
cmd_notif='"$HOME/.claude/hooks/notify.sh" Notification'

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

mkdir -p "$(dirname "$settings")"
[ -f "$settings" ] || echo '{}' > "$settings"

tmp="$(mktemp)"
jq \
  --arg stop "$cmd_stop" \
  --arg notif "$cmd_notif" \
  '
  .hooks //= {}
  # drop any prior notify.sh hooks so re-running stays clean
  | .hooks.Stop = ((.hooks.Stop // []) | map(select(any(.hooks[]?; .command | test("notify\\.sh")) | not)))
  | .hooks.Notification = ((.hooks.Notification // []) | map(select(any(.hooks[]?; .command | test("notify\\.sh")) | not)))
  | .hooks.Stop += [{ "hooks": [{ "type": "command", "command": $stop }] }]
  | .hooks.Notification += [{ "hooks": [{ "type": "command", "command": $notif }] }]
  ' "$settings" > "$tmp"

mv "$tmp" "$settings"
echo "Registered notify hooks in $settings"
