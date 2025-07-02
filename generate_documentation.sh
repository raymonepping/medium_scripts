#!/usr/bin/env bash
set -euo pipefail

export LC_CTYPE=UTF-8
VERSION="1.5.0"

# -- Set top level variable for script execution --
TOP_LEVEL_CALL=true

# --- Handle --help and --version flags early ---
if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [OPTIONS] <script-or-folder>"
  echo ""
  echo "Options:"
  echo "  --depth <n>                 Set recursion depth (default: 10)"
  echo "  --include-lint              Include lint badge in Markdown"
  echo "  --include-called-scripts    true|false (default: true)"
  echo "  --strict <true|false>       Only parse comments starting with '# ---' (default: true)"
  echo "  --help                      Show this help message"
  echo "  --version                   Show script version"
  exit 0
fi

# --- Handle --version flag ---
if [[ "${1:-}" == "--version" ]]; then
  echo "$0 version $VERSION"
  exit 0
fi

# --- Define configuration variables ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/docs"
IGNORE_FILE="$SCRIPT_DIR/.doc_bash_ignore"
LINT_ENABLED=false
INCLUDE_LINT=false
SUMMARY_MODE=false
CLEAN_MODE=false
STRICT_MODE=true
MAX_DEPTH=10
EMOJI_MODE=true
VISITED=()
INCLUDE_CALLED_SCRIPTS=true
mkdir -p "$OUTPUT_DIR"

# --- Load ignore list ---
IGNORED_COMMANDS=("echo" "clear" "pwd" "read" "exit" "if" "fi" "then" "else" "while" "do" "done")
[[ -f "$IGNORE_FILE" ]] && mapfile -t IGNORED_COMMANDS < "$IGNORE_FILE"

# --- Tool checks ---
if command -v shellcheck &>/dev/null; then
  LINT_ENABLED=true
fi
command -v shfmt &>/dev/null && [[ -d "$SCRIPT_DIR/scripts" ]] && find "$SCRIPT_DIR/scripts" -name "*.sh" -exec shfmt -w {} +

# --- CLI flags ---
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --depth)
      if [[ -n "${2:-}" ]]; then MAX_DEPTH="$2"; shift
      else echo "❌ Missing value for --depth"; exit 1; fi ;;
    --include-lint) INCLUDE_LINT=true ;;
    --strict)
      if [[ -n "${2:-}" ]]; then STRICT_MODE="$2"; shift
      else echo "❌ Missing value for --strict"; exit 1; fi ;;
    --include-called-scripts)
      if [[ -n "${2:-}" ]]; then
        if [[ "$2" == "true" ]]; then INCLUDE_CALLED_SCRIPTS=true;
        else INCLUDE_CALLED_SCRIPTS=false; fi
        shift
      else
        echo "❌ Missing value for --include-called-scripts"; exit 1;
      fi ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done
set -- "${ARGS[@]}"

# --- Utility: Emoji echo ---
em() {
  local emoji="$1"; shift
  if [[ "$EMOJI_MODE" == true ]]; then
    echo "$emoji $*"
  else
    echo "$*"
  fi
}

# Add this function near the top (with the other utility functions)
clean_trailing_blank_lines() {
  local file="$1"
  awk '
    { lines[NR]=$0 }
    END {
      last=0
      for(i=NR;i>=1;i--) if(lines[i] ~ /[^[:space:]]/) { last=i; break }
      for(i=1;i<=last;i++) print lines[i]
    }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# --- Lint Badge Generation ---
generate_lint_badge() {
  local file="$1"
  if [[ "$INCLUDE_LINT" == true ]]; then
    if [[ "$LINT_ENABLED" != true ]]; then
      echo "[![Lint](https://img.shields.io/badge/lint-unavailable-lightgrey)](https://www.shellcheck.net/)"
      return
    fi
    local issues badge_url
    issues=$(shellcheck "$file" 2>/dev/null | grep -E '^[^ ]+:[0-9]+' | wc -l | tr -d ' ')
    if [[ "${issues:-0}" -eq 0 ]]; then
      badge_url="https://img.shields.io/badge/lint-passing-brightgreen"
    elif [[ "$issues" -le 9 ]]; then
      badge_url="https://img.shields.io/badge/lint-warnings-orange"
    else
      badge_url="https://img.shields.io/badge/lint-issues-red"
    fi
    echo "[![Lint]($badge_url)](https://www.shellcheck.net/)"
  fi
}

# --- Bash Version Badge Generation ---
generate_bash_badge() {
  local bashv color badge
  bashv=$(bash --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
  [[ -z "$bashv" ]] && return
  bashv="${bashv%%.0}"      
  color="red"
  [[ "${bashv%%.*}" -lt 5 ]] && color="yellow"
  badge="[![Bash](https://img.shields.io/badge/bash-${bashv//./--}-$color)](https://www.gnu.org/software/bash/)"
  echo "$badge"
}

# --- File Size Badge Generation ---
generate_size_badge() {
  local file="$1"
  local size badge
  size=$(ls -lh "$file" 2>/dev/null | awk '{print $5}')
  [[ -z "$size" ]] && return
  badge="[![Size](https://img.shields.io/badge/size-${size// /%20}-yellow)](./$(basename "$file"))"
  echo "$badge"
}

# --- Last Updated Badge Generation ---
generate_updated_badge() {
  local file="$1"
  local updated badge
  updated=$(date -r "$file" +"%Y--%m--%d" 2>/dev/null || date -u -r "$file" +"%Y--%m--%d" 2>/dev/null)
  [[ -z "$updated" ]] && return
  badge="[![Updated](https://img.shields.io/badge/updated-$updated-blue)](./$(basename "$file"))"
  echo "$badge"
}

# --- Compose Badges Line ---
compose_badge_row() {
  local version="$1"
  local file="$2"
  local badge_lines=()

  badge_lines+=("[![Version](https://img.shields.io/badge/version-$version-purple.svg)](./$(basename "$file"))")
  badge_lines+=("[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/$(basename "$file" .sh).md)")

  # Only add if enabled and present
  [[ "$INCLUDE_LINT" == true ]] && {
    local lint; lint="$(generate_lint_badge "$file")"
    [[ -n "$lint" ]] && badge_lines+=("$lint")
  }
  local size updated bashv
  size="$(generate_size_badge "$file")"
  updated="$(generate_updated_badge "$file")"
  bashv="$(generate_bash_badge)"
  [[ -n "$size" ]] && badge_lines+=("$size")
  [[ -n "$updated" ]] && badge_lines+=("$updated")
  [[ -n "$bashv" ]] && badge_lines+=("$bashv")

  for b in "${badge_lines[@]}"; do
    echo "$b"
  done
}


# --- Summary Extraction ---
extract_summary() {
  local file="$1"
  if [[ "$STRICT_MODE" == true ]]; then
    awk '/^# --- .* ---$/ { gsub(/^# --- /, "- ", $0); gsub(/ ---$/, "", $0); print }' "$file"
  else
    awk '/^\s*#/ {
      line = $0
      sub(/^#+[[:space:]]*/, "", line)
      if (line ~ /[a-zA-Z]/) {
        sub(/[^a-zA-Z0-9 -]*$/, "", line)
        print "- " line
      }
    }' "$file"
  fi
}

# --- Variable Extraction ---
extract_variables() {
  grep -E '^[[:space:]]*[A-Z_][A-Z0-9_]*=' "$1" \
    | cut -d'=' -f1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' \
    | sort -u | awk 'NF { print "- " $0 }'
}

# --- Detect Called Scripts ---
find_called_scripts() {
  local file="$1"
  grep -Eo '\b(\./)?[a-zA-Z0-9_\-]+\.sh\b' "$file" | sort -u
  grep -Eo '\b[a-zA-Z0-9_\-]+\b' "$file" | while read -r cmd; do
    [[ "$cmd" =~ \.sh$ ]] && continue
    [[ -f "./$cmd" && -x "./$cmd" ]] && echo "./$cmd"
    [[ -x "$(command -v "$cmd")" ]] && file "$(command -v "$cmd")" | grep -qi "bash script" && echo "$(command -v "$cmd")"
  done
}

# --- Main Parser ---
parse_script() {
  local file="$1"
  local depth="$2"
  local output_file="$3"
  local is_main="${4:-false}"

  file="$(realpath "$file")"
  [[ "$depth" -gt "$MAX_DEPTH" ]] && return
  [[ " ${VISITED[*]} " == *" $file "* ]] && return
  VISITED+=("$file")
  GENERATED=1

  local base_name summary_section variable_section version timestamp has_version
  base_name="$(basename "$file" .sh)"
  summary_section=$(extract_summary "$file")
  variable_section=$(extract_variables "$file")
  # -- Strictly extract only VERSION="..." (ignores VERSION_FILE etc)
  version=$(awk -F '"' '/^VERSION="/ {print $2; exit}' "$file")
  if [[ -z "$version" ]]; then
    version="0.0.0"
    has_version=false
  else
    has_version=true
  fi
  timestamp="$(date "+%Y-%m-%d %H:%M:%S")"

  em "📄" "Processing: $base_name.sh"

  {
    if [[ "$depth" -eq 0 ]]; then
      if [[ "$has_version" == true ]]; then
        echo "# ${base_name}.sh - v$version - $timestamp"
      else
        echo "# ${base_name}.sh - $timestamp"
        echo
        echo "⚠️ No version detected — please run \`bump_version\` against this script."
      fi
      echo
      compose_badge_row "$version" "$file"
      echo
      echo "## Table of Contents"
    fi
    echo "- High-level summary - ${base_name}.sh"
    echo "- Variables Set - ${base_name}.sh"
    echo
    echo "## High-level summary - ${base_name}.sh"
    echo "$summary_section"
    echo
    echo "## Variables Set - ${base_name}.sh"
    echo "$variable_section"
    echo
  } >> "$output_file"

  if [[ "$INCLUDE_CALLED_SCRIPTS" == true ]]; then
    mapfile -t called_scripts < <(find_called_scripts "$file")
    for called in "${called_scripts[@]}"; do
      [[ -f "$called" ]] && parse_script "$called" $((depth + 1)) "$output_file" false
    done
  fi

  if [[ "$is_main" == true ]]; then
    sleep 0.05
    em "✅" "Documentation generated in: ./$(basename "$OUTPUT_DIR")"
    em "ℹ️" "Customize ignored commands via: $(basename "$IGNORE_FILE")"
  fi
}

# --- Generate Entry Point ---
em "🚀" "Starting documentation generation..."
GENERATED=0

for input in "${ARGS[@]}"; do
  if [[ -f "$input" ]]; then
    main_name="$(basename "$input" .sh)"
    output_file="$OUTPUT_DIR/$main_name.md"
    : > "$output_file"
    parse_script "$input" 0 "$output_file" true
  elif [[ -d "$input" ]]; then
    while IFS= read -r script; do
      main_name="$(basename "$script" .sh)"
      output_file="$OUTPUT_DIR/$main_name.md"
      : > "$output_file"
      parse_script "$script" 0 "$output_file" true
    done < <(find "$input" -name "*.sh")
  else
    em "❌" "Invalid input: $input"
  fi
done

# --- Remove all trailing blank lines in generated markdown files ---
em "🧹" "Tidying up markdown output in $OUTPUT_DIR ..."
for md in "$OUTPUT_DIR"/*.md; do
  [[ -f "$md" ]] && clean_trailing_blank_lines "$md"
done
em "🎉" "All documentation is now perfectly clean!"
