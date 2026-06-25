#!/bin/bash
input=$(cat)

# Require jq; degrade gracefully if missing.
if ! command -v jq >/dev/null 2>&1; then
  printf 'jq not found'
  exit 0
fi

# Extract every field in a single jq pass. Spawning jq once per field is the
# dominant cost on a status line that re-renders constantly. Fields are joined
# with US (\037) rather than tab: read merges consecutive whitespace delimiters,
# which would collapse empty fields and shift every later value.
IFS=$'\037' read -r model effort dir used_pct \
  session_pct weekly_pct session_reset weekly_reset \
  total_input total_output model_id < <(
  jq -r '
    [ .model.display_name,
      .effort.level,
      .workspace.current_dir,
      .context_window.used_percentage,
      .rate_limits.five_hour.used_percentage,
      .rate_limits.seven_day.used_percentage,
      .rate_limits.five_hour.resets_at,
      .rate_limits.seven_day.resets_at,
      .context_window.total_input_tokens,
      .context_window.total_output_tokens,
      .model.id
    ] | map(. // "" | tostring) | join("\u001f")
  ' <<<"$input"
)

dir_name=""
branch=""
if [ -n "$dir" ]; then
  dir_name="${dir##*/}"
  branch=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null)
fi

# Round a numeric value to an integer; print nothing for empty/non-numeric input.
# Rejects empty, any non-[0-9.] char, and strings with more than one dot.
round() {
  case "$1" in
    '' | *[!0-9.]* | *.*.* ) return ;;
  esac
  printf '%.0f' "$1"
}

# Current epoch seconds, captured once so fmt_reset doesn't fork date per call.
now=$(date +%s)

# Format seconds-until-reset as a compact "Nd Nh", "Nh Nm", or "Nm" string.
# Expects an epoch-seconds integer; ignores anything non-numeric.
fmt_reset() {
  local target="$1" diff d h m
  case "$target" in
    '' | *[!0-9]* ) return ;;
  esac
  diff=$((target - now))
  [ "$diff" -le 0 ] && { printf 'now'; return; }
  d=$((diff / 86400))
  h=$(((diff % 86400) / 3600))
  m=$(((diff % 3600) / 60))
  if [ "$d" -gt 0 ]; then
    printf '%dd %dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then
    printf '%dh %dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

# Cost estimate (approximate). Pricing per 1M tokens by tier.
case "$model_id" in
  *fable*)  input_price=10; output_price=50;;
  *opus*)   input_price=5;  output_price=25;;
  *sonnet*) input_price=3;  output_price=15;;
  *haiku*)  input_price=1;  output_price=5;;
  *)        input_price=3;  output_price=15;;
esac

cost=$(awk -v i="${total_input:-0}" -v o="${total_output:-0}" \
  -v ip="$input_price" -v op="$output_price" \
  'BEGIN { printf "%.3f", (i * ip + o * op) / 1000000 }')

# Build status line
parts="$model"

if [ -n "$effort" ]; then
  parts="$parts [$effort]"
fi

if [ -n "$branch" ]; then
  parts="$parts | $dir_name ($branch)"
else
  parts="$parts | $dir_name"
fi

used_int=$(round "$used_pct")
if [ -n "$used_int" ]; then
  parts="$parts | ctx: ${used_int}%"
fi

session_int=$(round "$session_pct")
if [ -n "$session_int" ]; then
  session_left=$(fmt_reset "$session_reset")
  if [ -n "$session_left" ]; then
    parts="$parts | session: ${session_int}% (${session_left})"
  else
    parts="$parts | session: ${session_int}%"
  fi
fi

weekly_int=$(round "$weekly_pct")
if [ -n "$weekly_int" ]; then
  weekly_left=$(fmt_reset "$weekly_reset")
  if [ -n "$weekly_left" ]; then
    parts="$parts | week: ${weekly_int}% (${weekly_left})"
  else
    parts="$parts | week: ${weekly_int}%"
  fi
fi

parts="$parts | \$$cost"

printf '%s' "$parts"
