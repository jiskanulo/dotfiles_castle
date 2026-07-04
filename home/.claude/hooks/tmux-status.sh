#!/usr/bin/env bash
# Reflect Claude Code's session state into tmux so every pane/window running
# Claude shows what it is doing at a glance.
#
# Invoked from ~/.claude/settings.json hooks with the hook event as $1
# (registered by install-hooks.sh):
#   UserPromptSubmit -> ▶ (working)
#   Notification     -> ⏳ (waiting for input / permission)
#   Stop             -> ✅ (finished, idle)
#   SessionStart     -> clear (fresh session, no stale icon)
#   SessionEnd       -> clear
#
# The state is stored as the pane-scoped user option @claude_status on the
# pane Claude was launched in ($TMUX_PANE, inherited from the launch shell).
# tmux.conf renders it in window-status-format / pane-border-format.
# No-ops silently outside tmux so the same dotfiles are safe everywhere.

event="${1:-}"

[ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

case "$event" in
  UserPromptSubmit) icon="▶" ;;
  Notification)     icon="⏳" ;;
  Stop)             icon="✅" ;;
  SessionStart|SessionEnd)
    tmux set-option -p -t "$TMUX_PANE" -u @claude_status 2>/dev/null
    exit 0
    ;;
  *) exit 0 ;;
esac

tmux set-option -p -t "$TMUX_PANE" @claude_status "$icon" 2>/dev/null

exit 0
