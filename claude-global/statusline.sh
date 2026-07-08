#!/bin/bash

# Colors
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
CYAN=$'\033[36m'
RESET=$'\033[0m'

# Read JSON input from stdin
input=$(cat)

# Extract values
model_name=$(echo "$input" | jq -r '.model.display_name')
git_branch=$(git branch --show-current 2>/dev/null || echo "-")
git_changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
work_dir=$(echo "$input" | jq -r '.workspace.current_dir' | xargs basename)

# Tokens
total_input=$(echo "$input" | jq '.context_window.total_input_tokens')
total_output=$(echo "$input" | jq '.context_window.total_output_tokens')
input_k=$(echo "scale=1; $total_input / 1000" | bc)
output_k=$(echo "scale=1; $total_output / 1000" | bc)

# Context usage calculation
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
    current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')
    pct=$((current * 100 / size))

    # Color based on usage
    if [ $pct -lt 50 ]; then
        bar_color=$GREEN
    elif [ $pct -lt 80 ]; then
        bar_color=$YELLOW
    else
        bar_color=$RED
    fi

    filled=$((pct / 10))
    empty=$((10 - filled))
    bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))$(printf '░%.0s' $(seq 1 $empty 2>/dev/null))
    context_info="${bar_color}${bar} ${pct}%${RESET}"
else
    context_info="░░░░░░░░░░ 0%"
fi

# Cost calculation
input_cost=$(echo "scale=4; $total_input * 3.00 / 1000000" | bc)
output_cost=$(echo "scale=4; $total_output * 15.00 / 1000000" | bc)
total_cost=$(echo "scale=2; $input_cost + $output_cost" | bc)

# Git changes
if [ "$git_changes" -eq 0 ]; then
    changes_display="${GREEN}clean${RESET}"
else
    changes_display="${YELLOW}${git_changes}${RESET}"
fi

# Format output
echo "${CYAN}${model_name}${RESET} | ${context_info} | ${BLUE}${input_k}K/${output_k}K${RESET} | ${GREEN}\$${total_cost}${RESET} | ${work_dir} | ${git_branch}(${changes_display})"
