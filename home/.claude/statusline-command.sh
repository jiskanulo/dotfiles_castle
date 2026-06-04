#!/bin/bash
input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name')
dir=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$dir")
branch=$(git --git-dir="$dir/.git" --work-tree="$dir" branch --show-current 2>/dev/null)

# Token usage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Rate limits: 5-hour window (current session) and 7-day window (weekly)
session_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
weekly_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
session_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
weekly_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Format seconds-until-reset as a compact "Nd Nh", "Nh Nm", or "Nm" string
fmt_reset() {
  local target="$1" now diff d h m
  [ -z "$target" ] && return
  now=$(date +%s)
  diff=$((target - now))
  [ "$diff" -le 0 ] && { printf 'now'; return; }
  d=$((diff / 86400))
  h=$(((diff % 86400) / 3600))
  m=$(((diff % 3600) / 60))
  if [ "$d" -gt 0 ]; then
    printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then
    printf '%dh%dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

# Cost estimate (approximate): claude-opus-4 ~$15/$75 per M tokens input/output
# Use display_name to decide pricing tier
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

model_id=$(echo "$input" | jq -r '.model.id')

# Pricing per 1M tokens (approximate)
case "$model_id" in
  *opus*)       input_price=15; output_price=75 ;;
  *sonnet*)     input_price=3;  output_price=15 ;;
  *haiku*)      input_price=0.8; output_price=4 ;;
  *)            input_price=3;  output_price=15 ;;
esac

cost=$(echo "$total_input $total_output $input_price $output_price" | awk '{printf "%.3f", ($1 * $3 + $2 * $4) / 1000000}')

# Build status line
parts="$model"

if [ -n "$branch" ]; then
  parts="$parts | $dir_name ($branch)"
else
  parts="$parts | $dir_name"
fi

if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  parts="$parts | ctx:${used_int}%"
fi

if [ -n "$session_pct" ]; then
  session_int=$(printf "%.0f" "$session_pct")
  session_left=$(fmt_reset "$session_reset")
  if [ -n "$session_left" ]; then
    parts="$parts | session:${session_int}% (${session_left})"
  else
    parts="$parts | session:${session_int}%"
  fi
fi

if [ -n "$weekly_pct" ]; then
  weekly_int=$(printf "%.0f" "$weekly_pct")
  weekly_left=$(fmt_reset "$weekly_reset")
  if [ -n "$weekly_left" ]; then
    parts="$parts | week:${weekly_int}% (${weekly_left})"
  else
    parts="$parts | week:${weekly_int}%"
  fi
fi

parts="$parts | \$$cost"

printf '%s' "$parts"
