#!/bin/bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
dir=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$dir")
branch=$(git --git-dir="$dir/.git" --work-tree="$dir" branch --show-current 2>/dev/null)

# Token usage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

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

parts="$parts | \$$cost"

printf '%s' "$parts"
