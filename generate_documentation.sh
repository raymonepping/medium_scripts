#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="2.4.4"

# shellcheck disable=SC2034
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
  echo "  --output-dir <dir>          Output directory for docs (default: ./docs where you run the script)"
  echo "  --help                      Show this help message"
  echo "  --version                   Show script version"
  exit 0
fi

if [[ "${1:-}" == "--version" ]]; then
  echo "$0 version $VERSION"
  exit 0
fi

# --- Define configuration variables ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IGNORE_FILE="$SCRIPT_DIR/.doc_bash_ignore"
LINT_ENABLED=false
INCLUDE_LINT=false
STRICT_MODE=true
MAX_DEPTH=10
EMOJI_MODE=true
VISITED=()
INCLUDE_CALLED_SCRIPTS=true
OUTPUT_DIR=""

# --- CLI flags, including output dir ---
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --depth)
      if [[ -n "${2:-}" ]]; then
        MAX_DEPTH="$2"
        shift 2
      else
        echo "❌ Missing value for --depth"
        shift
      fi
      ;;
    --include-lint)
      INCLUDE_LINT=true
      shift
      ;;
    --strict)
      if [[ -n "${2:-}" ]]; then
        STRICT_MODE="$2"
        shift 2
      else
        echo "❌ Missing value for --strict"
        shift
      fi
      ;;
    --include-called-scripts)
      if [[ -n "${2:-}" ]]; then
        if [[ "$2" == "true" ]]; then
          INCLUDE_CALLED_SCRIPTS=true
        else
          INCLUDE_CALLED_SCRIPTS=false
        fi
        shift 2
      else
        echo "❌ Missing value for --include-called-scripts"
        shift
      fi
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

# --- Set OUTPUT_DIR to ./docs if not set ---
if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="$PWD/docs"
fi
mkdir -p "$OUTPUT_DIR"

# --- Load ignore list ---
IGNORED_COMMANDS=("echo" "clear" "pwd" "read" "exit" "if" "fi" "then" "else" "while" "do" "done")
[[ -f "$IGNORE_FILE" ]] && mapfile -t IGNORED_COMMANDS <"$IGNORE_FILE"

# --- Tool checks ---
if command -v shellcheck &>/dev/null; then
  LINT_ENABLED=true
fi
command -v shfmt &>/dev/null && [[ -d "$SCRIPT_DIR/scripts" ]] && find "$SCRIPT_DIR/scripts" -name "*.sh" -exec shfmt -w {} +

# --- Utility: Emoji echo ---
em() {
  local emoji="$1"
  shift
  if [[ "$EMOJI_MODE" == true ]]; then
    echo "$emoji $*"
  else
    echo "$*"
  fi
}

clean_trailing_blank_lines() {
  local file="$1"
  awk '
    { lines[NR]=$0 }
    END {
      last=0
      for(i=NR;i>=1;i--) if(lines[i] ~ /[^[:space:]]/) { last=i; break }
      for(i=1;i<=last;i++) print lines[i]
    }
  ' "$file" >"${file}.tmp" && mv "${file}.tmp" "$file"
}

generate_lint_badge() {
  local file="$1"
  if [[ "$INCLUDE_LINT" == true ]]; then
    if [[ "$LINT_ENABLED" != true ]]; then
      echo "[![Lint](https://img.shields.io/badge/lint-unavailable-lightgrey)](https://www.shellcheck.net/)"
      return
    fi
    local issues badge_url
    issues=$(shellcheck "$file" 2>/dev/null | grep -cE '^[^ ]+:[0-9]+')
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

generate_size_badge() {
  local file="$1"
  local size badge
  if stat --version &>/dev/null; then
    size=$(stat -c %s "$file")
  else
    size=$(stat -f %z "$file")
  fi
  if command -v numfmt &>/dev/null; then
    size=$(numfmt --to=iec --suffix=B "$size")
  else
    size="${size}B"
  fi
  badge="[![Size](https://img.shields.io/badge/size-${size// /%20}-yellow)](./$(basename "$file"))"
  echo "$badge"
}

generate_updated_badge() {
  local file="$1"
  local updated badge
  updated=$(date -r "$file" +"%Y--%m--%d" 2>/dev/null || date -u -r "$file" +"%Y--%m--%d" 2>/dev/null)
  [[ -z "$updated" ]] && return
  badge="[![Updated](https://img.shields.io/badge/updated-$updated-blue)](./$(basename "$file"))"
  echo "$badge"
}

compose_badge_row() {
  local version="$1"
  local file="$2"
  local badge_lines=()

  badge_lines+=("[![Version](https://img.shields.io/badge/version-$version-purple.svg)](./$(basename "$file"))")
  badge_lines+=("[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/$(basename "$file" .sh).md)")

  [[ "$INCLUDE_LINT" == true ]] && {
    local lint
    lint="$(generate_lint_badge "$file")"
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

extract_variables() {
  grep -E '^[[:space:]]*[A-Z_][A-Z0-9_]*=' "$1" |
    cut -d'=' -f1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' |
    sort -u | awk 'NF { print "- " $0 }'
}

find_called_scripts() {
  local file="$1"
  grep -Eo '\b(\./)?[a-zA-Z0-9_\-]+\.sh\b' "$file" | sort -u
  grep -Eo '\b[a-zA-Z0-9_\-]+\b' "$file" | while read -r cmd; do
    [[ "$cmd" =~ \.sh$ ]] && continue
    [[ -f "./$cmd" && -x "./$cmd" ]] && echo "./$cmd"
    # Resolve from $PATH if not in current dir
    [[ -x "$(command -v "$cmd" 2>/dev/null)" ]] && file "$(command -v "$cmd")" | grep -qi "bash script" && command -v "$cmd"
  done
}

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
  } >>"$output_file"

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

# --- Resolve input scripts (supporting $PATH and relative/absolute) ---
resolve_input() {
  local input="$1"
  if [[ -f "$input" || -d "$input" ]]; then
    echo "$input"
  elif command -v "$input" &>/dev/null; then
    command -v "$input"
  else
    echo ""
  fi
}

em "🚀" "Starting documentation generation..."
GENERATED=0

fatal=0

for input in "${ARGS[@]}"; do
  real_input="$(resolve_input "$input")"
  if [[ -z "$real_input" ]]; then
    em "❌" "Invalid input: $input"
    continue
  fi
  if [[ -f "$real_input" ]]; then
    main_name="$(basename "$real_input" .sh)"
    output_file="$OUTPUT_DIR/$main_name.md"
    : >"$output_file"
    parse_script "$real_input" 0 "$output_file" true
  elif [[ -d "$real_input" ]]; then
    while IFS= read -r script; do
      main_name="$(basename "$script" .sh)"
      output_file="$OUTPUT_DIR/$main_name.md"
      : >"$output_file"
      parse_script "$script" 0 "$output_file" true
    done < <(find "$real_input" -name "*.sh")
  else
    em "❌" "Invalid input: $input"
    continue
  fi
done

em "🧹" "Tidying up markdown output in $OUTPUT_DIR ..."
for md in "$OUTPUT_DIR"/*.md; do
  [[ -f "$md" ]] && clean_trailing_blank_lines "$md"
done
em "🎉" "All documentation is now perfectly clean!"

exit $fatal
