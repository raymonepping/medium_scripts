#!/usr/bin/env bash
# shellcheck shell=bash

# --- top10_validator.sh: Check a script against our Bash Top 10 (Color + Markdown) ---

# shellcheck disable=SC2034 # intentional: VERSION is used by automation
VERSION="2.1.0"

# --- Enable strict mode for safety and fail-fast behavior ---
set -euo pipefail

# --- Disable strict mode temporarily when parsing or processing risky logic ---
disable_strict_mode() {
  set +e +u +o pipefail
}

# --- Enable strict mode again after risky logic ---
enable_strict_mode() {
  set -euo pipefail
}

# --- Define color variables for output formatting ---
color_reset=$'\e[0m'
color_red=$'\e[31m'
color_yellow=$'\e[33m'
color_green=$'\e[32m'
color_bold=$'\e[1m'

# --- Define status icons ---
CROSS="❌"
WARN="🟠"
CHECK="✅"
STAR="🌟"

# --- Declare rule arrays and tracking levels ---
declare -a RULES STATUS LEVEL

# --- Define Top 10 validation rules (plus bonus) ---
RULES[0]='Has VERSION="..." at top for semantic versioning (BONUS)'
RULES[10]="Shebang: Portable interpreter (#!/usr/bin/env bash)"
RULES[9]="Help flag/usage info present"
RULES[8]="Uses Bash [[ ... ]] tests"
RULES[7]="Uses local in functions"
RULES[6]="ShellCheck disables found, review context"
RULES[5]="Variables are quoted"
RULES[4]="File listing: Uses find/globs, avoids ls"
RULES[3]="Strict error handling: set -euo pipefail"
RULES[2]="Nonzero exit codes for error"
RULES[1]="Uses awk for structured data, sed only for simple replacements"

# --- Function to show usage help ---
show_help() {
  cat <<EOF
Usage: ./top10_validator.sh [script.sh] [options]

Options:
  -h, --help              Show this help message
  --version               Show script version
  --md, --markdown        Output results to Markdown
  --output md             Same as --markdown
  --output=md             Same as --markdown
  --quiet-header          Hide header line in output (default)
  --show-header           Show header line in output
  --hide-script-name      Hide script name from output (default)
  --show-script-name      Show script name in output
  --footer                Add footer with validator/commit info (default)
  --no-footer             Disable footer in Markdown output
  --footer=true|false     Explicitly enable/disable footer

Examples:
  ./top10_validator.sh ./myscript.sh
  ./top10_validator.sh ./myscript.sh --output md
  ./top10_validator.sh ./myscript.sh --markdown --footer=false

EOF
}


# --- Parse command-line arguments ---
if [[ $# -lt 1 ]]; then
  show_help
  exit 1
fi

# --- Initialize flag variables ---
SCRIPT=""
MD_OUT=false
QUIET_HEADER=true
SHOW_FOOTER=true
HIDE_SCRIPT_NAME=true
expecting_output_arg=false

# --- Process each argument ---
for arg in "$@"; do
  if $expecting_output_arg; then
    [[ "$arg" == "md" || "$arg" == "markdown" ]] && MD_OUT=true
    expecting_output_arg=false
    continue
  fi
  case "$arg" in
    -h|--help) show_help; exit 0 ;;
    --version) echo "top10_validator.sh version: $VERSION"; exit 0 ;;
    --md|--markdown) MD_OUT=true ;;
    --output) expecting_output_arg=true ;;
    --output=md|--output=markdown) MD_OUT=true ;;
    --output=*) val="${arg#*=}"; [[ "$val" == "md" || "$val" == "markdown" ]] && MD_OUT=true ;;
    --quiet-header) QUIET_HEADER=true ;;
    --no-footer) SHOW_FOOTER=false ;;
    --footer) SHOW_FOOTER=true ;;
    --footer=*)
      val="${arg#*=}"
      [[ "$val" == "false" ]] && SHOW_FOOTER=false
      [[ "$val" == "true" ]] && SHOW_FOOTER=true
      ;;    
    --show-header) QUIET_HEADER=false ;;
    --hide-script-name) HIDE_SCRIPT_NAME=true ;;
    --show-script-name) HIDE_SCRIPT_NAME=false ;;
    -*)
      echo "❌ Unknown option: $arg"
      show_help
      exit 1
      ;;
    *)
      [[ -z "$SCRIPT" ]] && SCRIPT="$arg"
      ;;
  esac
done

# --- Validate input script ---
[[ ! -f "$SCRIPT" ]] && echo "❌ File not found: $SCRIPT" && exit 1

# --- Initialize LEVELs to 'bad' ---
for ((i=0; i<=10; i++)); do LEVEL[$i]="bad"; done

# --- Disable strict mode for grep/parsing sections ---
disable_strict_mode

# --- Run checks 10 to 0 ---
# 10
if head -n1 "$SCRIPT" | grep -q '/usr/bin/env bash'; then
  STATUS[10]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[10]="best"
elif head -n1 "$SCRIPT" | grep -q '^#!'; then
  STATUS[10]="${color_yellow}${WARN} - [B02] -${color_reset}"; LEVEL[10]="better"
else
  STATUS[10]="${color_red}${CROSS} - [B01] -${color_reset}"
fi

# 9
if grep -qE '(-h|--help)' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[9]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[9]="best"
elif grep -qi 'usage' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[9]="${color_yellow}${WARN} - [B02] -${color_reset}"; LEVEL[9]="better"
else
  STATUS[9]="${color_red}${CROSS} - [B01] -${color_reset}"
fi

# 8
if grep -q '\[\[' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[8]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[8]="best"
elif grep -q '\[ ' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[8]="${color_yellow}${WARN} - [B02] -${color_reset}"; LEVEL[8]="better"
else
  STATUS[8]="${color_red}${CROSS} - [B01] -${color_reset}"
fi

# 7
if grep -q 'local ' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[7]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[7]="best"
elif grep -q '()' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[7]="${color_yellow}${WARN} - [B02] -${color_reset}"; LEVEL[7]="better"
else
  STATUS[7]="${color_red}${CROSS} - [B01] -${color_reset}"
fi

# 6
if grep -Eq '# shellcheck disable=.*#' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[6]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[6]="best"
elif grep -q 'shellcheck disable' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[6]="${color_yellow}${WARN} - [B02] -${color_reset}"; LEVEL[6]="better"
elif grep -q 'shellcheck' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[6]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[6]="best"
else
  STATUS[6]="${color_red}${CROSS} - [B01] -${color_reset}"
fi

# 5
if grep -qE '\"\$[a-zA-Z0-9_]+\"' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[5]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[5]="best"
elif grep -qE '\$[a-zA-Z0-9_]+\b' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[5]="${color_yellow}${WARN} - [B02] -${color_reset}"; LEVEL[5]="better"
else
  STATUS[5]="${color_red}${CROSS} - [B01] -${color_reset}"
fi

# 4
if grep -E '^[^#"\047]*\bls\b[[:space:]]' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[4]="${color_red}${CROSS} - [B01] -${color_reset}"
elif grep -q 'find ' "$SCRIPT" >/dev/null 2>&1 || grep -qE '\*\.[a-zA-Z0-9]+' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[4]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[4]="best"
else
  STATUS[4]="${color_yellow}${WARN} - [B02] -${color_reset}"; LEVEL[4]="better"
fi

# 3
if grep -q 'set -euo pipefail' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[3]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[3]="best"
elif grep -q 'set -e' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[3]="${color_yellow}${WARN} - [B02] -${color_reset}"; LEVEL[3]="better"
else
  STATUS[3]="${color_red}${CROSS} - [B01] -${color_reset}"
fi

# 2
if grep -q 'exit 1' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[2]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[2]="best"
elif grep -q 'exit 0' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[2]="${color_yellow}${WARN} - [B02] -${color_reset}"; LEVEL[2]="better"
else
  STATUS[2]="${color_red}${CROSS} - [B01] -${color_reset}"
fi

# 1
if grep -q 'awk ' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[1]="${color_green}${CHECK} - [B03] -${color_reset}"; LEVEL[1]="best"
elif grep -q 'sed ' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[1]="${color_yellow}${WARN} - [B02] -${color_reset}"; LEVEL[1]="better"
else
  STATUS[1]="${color_red}${CROSS} - [B01] -${color_reset}"
fi

# 0 BONUS
if grep -qE '^VERSION="' "$SCRIPT" >/dev/null 2>&1; then
  STATUS[0]="${color_green}${STAR} - [B00] -${color_reset}"; LEVEL[0]="bonus"
else
  STATUS[0]="${color_red}${CROSS} - [B01] -${color_reset}"; LEVEL[0]="bad"
fi

# --- Output Results ---
output_block=""
if [[ "$QUIET_HEADER" != true ]]; then
  if [[ "$HIDE_SCRIPT_NAME" == true ]]; then
    output_block+="Top 10 Bash Best Practices Checklist\n\n"
  else
    output_block+="Top 10 Bash Best Practices Check: $SCRIPT\n\n"
  fi
fi

# ---
output_block+=$(cat <<EOF
10 ${STATUS[10]} ${RULES[10]}
 9 ${STATUS[9]} ${RULES[9]}
 8 ${STATUS[8]} ${RULES[8]}
 7 ${STATUS[7]} ${RULES[7]}
 6 ${STATUS[6]} ${RULES[6]}
 5 ${STATUS[5]} ${RULES[5]}
 4 ${STATUS[4]} ${RULES[4]}
 3 ${STATUS[3]} ${RULES[3]}
 2 ${STATUS[2]} ${RULES[2]}
 1 ${STATUS[1]} ${RULES[1]}
 0 ${STATUS[0]} ${RULES[0]}

----
Summary Table:
EOF
)

# --- Count levels, if it’s a failed bonus, counts as a violation
best=0; warn=0; bad=0; bonus=0
for ((i=10; i>=1; i--)); do
  case "${LEVEL[$i]}" in
    best)   ((best++)) ;;
    better) ((warn++)) ;;
    bad)    ((bad++)) ;;
  esac
done
if [[ "${LEVEL[0]:-}" == "bonus" ]]; then
  bonus=1
else
  ((bad++)) 
fi

# --- Assess risk
assess_risk() {
  if (( bad == 0 && warn <= 2 )); then
    RISK_TEXT="✅ Excellent"
  elif (( bad == 0 && warn <= 4 )); then
    RISK_TEXT="🟡 Fair"
  else
    RISK_TEXT="🔴 Needs review"
  fi
}
assess_risk

# --- Final Score Calculation ---
total_points=0
for ((i=10; i>=1; i--)); do
  case "${LEVEL[$i]}" in
    best)   ((total_points+=10)) ;;
    better) ((total_points+=5)) ;;
    bad)    ((total_points+=0)) ;;
  esac
done

score=$(awk "BEGIN { printf \"%.1f\", $total_points / 100 * 10 }")

# --- Bonus status for visual clarity, count failed bonus as a violation
if [[ "${LEVEL[0]:-}" == "bonus" ]]; then
  bonus=1
  bonus_text="🌟"
else
  bonus=0
  bonus_text="❌"
  ((bad++))  
fi

score_line="🎯 Final Score: $score/10 (Bonus: $bonus_text)"


# --- Build Summary Block ---
summary_block=$(cat <<EOF
Best: $best   Warn: $warn   Bad: $bad   Bonus: $bonus

Level  Count     Description
-----  --------  -----------------------
B03    $(printf "%-8d" "$best") ✅ Best practices
B02    $(printf "%-8d" "$warn") ⚠️  Warnings / Better
B01    $(printf "%-8d" "$bad") ❌ Violations
B00    $(printf "%-8d" "$bonus") 🌟 Bonus points

Validated script: $SCRIPT
Summary: This is a heuristic scan. Review the output for improvement hints!

$score_line
EOF
)

# --- Enable strict mode again
enable_strict_mode

# --- Terminal output ---
echo -e "$output_block"
echo -e "$summary_block"

# --- Markdown output ---
if [[ "$MD_OUT" == true ]]; then
  md_file="validated_$(basename "$SCRIPT" .sh).md"
  BADGE="[![Top 10 Bash Check](https://img.shields.io/badge/bash--top10-validated-blue?logo=gnubash&style=flat-square)](./$md_file)"
  HEADER="## ✅ Top 10 Bash Best Practices - $(date '+%Y-%m-%d %H:%M:%S') ##"

  {
    echo "$HEADER"
    echo ""
    echo "$BADGE"
    echo ""
    echo "$output_block"
    echo "$summary_block"
  } | sed 's/\x1b\[[0-9;]*m//g' > "$md_file"

  # --- Optional Git metadata for footer ---
  author_info=""

  if [[ -n "${GITHUB_ACTOR:-}" ]]; then
    author_info+="Validated by: @${GITHUB_ACTOR}"
  elif [[ -n "${USER:-}" ]]; then
    author_info+="Validated by: ${USER}"
  fi

  if [[ -n "${GITHUB_SHA:-}" ]]; then
    author_info+=" on $(date '+%Y-%m-%d %H:%M') (Commit: ${GITHUB_SHA:0:7})"
  elif git rev-parse --is-inside-work-tree &>/dev/null; then
    git_sha="$(git rev-parse --short HEAD 2>/dev/null || true)"
    [[ -n "$git_sha" ]] && author_info+=" on $(date '+%Y-%m-%d %H:%M') (Commit: $git_sha)"
  else
    author_info+=" on $(date '+%Y-%m-%d %H:%M')"
  fi

  if [[ -n "$author_info" ]]; then
    echo -e "\n---\n_${author_info}_\n" >> "$md_file"
  fi

  echo -e "\n📄 Markdown file written: $md_file"
fi

# --- Count results ---
best=0; warn=0; bad=0; bonus=0
for ((i=10; i>=1; i--)); do
  case "${LEVEL[$i]}" in
    best)   ((best++)) ;;
    better) ((warn++)) ;;
    bad)    ((bad++)) ;;
  esac
done

# --- Bonus and score logic ---
[[ "${LEVEL[0]:-}" == "bonus" ]] && bonus=1

# --- Enable strict mode for rest
enable_strict_mode

echo -e "${color_green}${color_bold}Best:${color_reset} $best   ${color_yellow}${color_bold}Warn:${color_reset} $warn   ${color_red}${color_bold}Bad:${color_reset} $bad   ${color_green}${color_bold}Bonus:${color_reset} $bonus\n"

# ---
printf "%-6s %-10s %s\n" "Level" "Count" "Description"
printf "%-6s %-10s %s\n" "-----" "-----" "-----------"
printf "%-6s %-10d %s\n" "B03" "$best"  "✅ Best practices"
printf "%-6s %-10d %s\n" "B02" "$warn"  "⚠️ Warnings / Better"
printf "%-6s %-10d %s\n" "B01" "$bad"   "❌ Violations"
printf "%-6s %-10d %s\n" "B00" "$bonus" "🌟 Bonus points"

# --- Risk Assessment
assess_risk() {
  if (( bad == 0 && warn <= 2 )); then
    RISK_TEXT="✅ Excellent"
  elif (( bad == 0 && warn <= 4 )); then
    RISK_TEXT="⚠️ Fair"
  else
    RISK_TEXT="🔴 Needs review"
  fi
}

# ---
assess_risk

# ---
echo ""
echo -e "${color_bold}Validated script:${color_reset} $SCRIPT"
echo -e "${color_bold}Summary:${color_reset} This is a heuristic scan. Review the output for improvement hints!"
