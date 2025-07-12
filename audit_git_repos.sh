#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="${1:-.}"
OUTPUT_FILE="${2:-repos_report.md}"
AUDITIGNORE_FILE=".auditignore"

EXCLUDES=()

# Parse optional --exclude flags and check for .auditignore
while [[ $# -gt 0 ]]; do
  case "$1" in
  --exclude)
    shift
    EXCLUDES+=("$1")
    shift
    ;;
  *)
    ROOT="$1"
    shift
    ;;
  esac
done

# Read .auditignore if present
if [[ -f "$ROOT_DIR/$AUDITIGNORE_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    EXCLUDES+=("$line")
  done <"$ROOT_DIR/$AUDITIGNORE_FILE"
fi

function is_excluded() {
  local path="$1"
  for exclude in "${EXCLUDES[@]}"; do
    [[ "$path" == *"$exclude"* ]] && return 0
  done
  return 1
}

# Color codes for terminal (optional)
RESET="$(tput sgr0)"
GREEN="$(tput setaf 2)"
RED="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"

# Header
{
  echo "# 🧾 Repository Audit Report"
  echo ""
  echo "| Repo | Connected | Latest Tag | At Tag | Commits Since Tag | Last Commit | Remote URL | Status |"
  echo "|------|-----------|------------|--------|-------------------|-------------|------------|--------|"
} >"$OUTPUT_FILE"

declare -a rows=()

found_any=false

for path in "$ROOT_DIR"/*; do
  [[ -d "$path" ]] || continue
  repo=$(basename "$path")

  is_excluded "$repo" && echo "🚫 Skipping excluded: $repo" && continue

  cd "$path" || continue

  echo "🔍 Checking $repo..."

  if [[ -d ".git" ]]; then
    found_any=true

    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    connected="✅"
    [[ -z "$remote_url" ]] && connected="❌" && remote_url="—"

    tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "—")
    head_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")
    at_tag="❌"
    [[ -n "$head_tag" ]] && at_tag="✅"

    commits_since_tag="—"
    [[ "$tag" != "—" ]] && commits_since_tag=$(git rev-list "$tag"..HEAD --count 2>/dev/null || echo "—")

    last_commit=$(git log -1 --format=%cd --date=short 2>/dev/null || echo "—")

    shallow=""
    [[ -f .git/shallow ]] && shallow="⚠️ Shallow clone detected"

    status=$(git status -sb 2>/dev/null | head -n1 | sed 's/## //' || echo "—")

    row="| \`$repo\` | $connected | $tag | $at_tag | $commits_since_tag | $last_commit | $remote_url | $status $shallow |"
    rows+=("$row")
  else
    echo "⚠️  No .git found in $repo"
  fi

  cd "$OLDPWD" || exit 1

done

# Sort by version tag (descending)
sorted_rows=$(printf '%s\n' "${rows[@]}" | sort -r -t '|' -k3)
echo "$sorted_rows" >>"$OUTPUT_FILE"

if [[ "$found_any" == false ]]; then
  echo "❌ No Git repos found in: $ROOT_DIR"
else
  echo "✅ Report generated at: $OUTPUT_FILE"
fi
