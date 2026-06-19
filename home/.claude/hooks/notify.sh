#!/usr/bin/env bash
# macOS desktop notification for Claude Code hooks (portable, no hardcoded paths).
#
# Invoked from ~/.claude/settings.json hooks, e.g.:
#   "Stop":         [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh Stop" }] }]
#   "Notification": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh Notification" }] }]
#
# Reads the hook payload JSON on stdin and uses its `.message` field when present
# (Notification supplies one; Stop does not, so a sensible default is used).
# The payload's `.cwd` basename is shown as the notification subtitle so you can
# tell which session/working directory a notification came from at a glance.
#
# Overridable via env: CLAUDE_NOTIFY_TITLE, CLAUDE_NOTIFY_SOUND
# (sound names come from /System/Library/Sounds, e.g. Glass, Ping, Hero, Submarine).
# No-ops silently on non-macOS hosts so the same dotfiles are safe everywhere.

event="${1:-}"
title="${CLAUDE_NOTIFY_TITLE:-Claude Code}"
# `-` (no colon) so an explicitly empty CLAUDE_NOTIFY_SOUND stays empty (silent),
# while an unset value still falls back to the default.
sound="${CLAUDE_NOTIFY_SOUND-Glass}"

payload="$(cat 2>/dev/null)"
msg=""
cwd=""
if [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
  msg="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)"
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
fi

# Append the working directory to the title so you can tell which session a
# notification came from at a glance. Normally "parent/leaf"; collapses to just
# "leaf" for top-level dirs (/Users) and when parent == leaf (/foo/foo), and
# shows "/" at the filesystem root.
if [ -n "$cwd" ]; then
  leaf="$(basename "$cwd")"
  parentpath="$(dirname "$cwd")"
  parent="$(basename "$parentpath")"
  if [ "$cwd" = "/" ]; then
    where="/"
  elif [ "$parentpath" = "/" ] || [ "$parent" = "$leaf" ]; then
    where="$leaf"
  else
    where="$parent/$leaf"
  fi
  title="$title - $where"
fi
subtitle=""

case "$event" in
  Stop)         msg="${msg:-Task completed}" ;;
  Notification) msg="${msg:-Waiting for your input}" ;;
  *)            msg="${msg:-Claude Code}" ;;
esac

# osascript is macOS-only; do nothing elsewhere.
command -v osascript >/dev/null 2>&1 || exit 0

# An empty CLAUDE_NOTIFY_SOUND yields a silent banner (no `sound name` clause).
if [ -n "$sound" ]; then
  osascript \
    -e 'on run argv' \
    -e 'display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv) sound name (item 4 of argv)' \
    -e 'end run' \
    "$msg" "$title" "$subtitle" "$sound" >/dev/null 2>&1
else
  osascript \
    -e 'on run argv' \
    -e 'display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv)' \
    -e 'end run' \
    "$msg" "$title" "$subtitle" >/dev/null 2>&1
fi

exit 0
