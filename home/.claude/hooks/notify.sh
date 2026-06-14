#!/usr/bin/env bash
# macOS desktop notification for Claude Code hooks (portable, no hardcoded paths).
#
# Invoked from ~/.claude/settings.json hooks, e.g.:
#   "Stop":         [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh Stop" }] }]
#   "Notification": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh Notification" }] }]
#
# Reads the hook payload JSON on stdin and uses its `.message` field when present
# (Notification supplies one; Stop does not, so a sensible default is used).
#
# Overridable via env: CLAUDE_NOTIFY_TITLE, CLAUDE_NOTIFY_SOUND
# (sound names come from /System/Library/Sounds, e.g. Glass, Ping, Hero, Submarine).
# No-ops silently on non-macOS hosts so the same dotfiles are safe everywhere.

event="${1:-}"
title="${CLAUDE_NOTIFY_TITLE:-Claude Code}"
sound="${CLAUDE_NOTIFY_SOUND:-Glass}"

payload="$(cat 2>/dev/null)"
msg=""
if [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
  msg="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)"
fi

case "$event" in
  Stop)         msg="${msg:-Task completed}" ;;
  Notification) msg="${msg:-Waiting for your input}" ;;
  *)            msg="${msg:-Claude Code}" ;;
esac

# osascript is macOS-only; do nothing elsewhere.
command -v osascript >/dev/null 2>&1 || exit 0

osascript \
  -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title (item 2 of argv) sound name (item 3 of argv)' \
  -e 'end run' \
  "$msg" "$title" "$sound" >/dev/null 2>&1

exit 0
