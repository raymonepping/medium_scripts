#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="${1:-.}"
OUTPUT_FILE="${2:-repos_report.md}"
shift || true  # Shift $1 (already stored in ROOT_DIR)

EXCLUDES=()

# Parse optional --exclude flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --exclude)
      shift
      EXCLUDES+=("$1")
      ;;
    *)
      echo "⚠️ Unknown argument: $1"
      ;;
  esac
  shift || true
done

echo "📂 Scanning: $ROOT_DIR"

# Header
{
  echo "# 🧾 Repository Audit Report"
  echo ""
  echo "| Repo | Connected | Latest Tag | Remote URL | Status |"
  echo "|------|-----------|------------|------------|--------|"
} > "$OUTPUT_FILE"

found_any=false

for path in "$ROOT_DIR"/*; do
  [[ -d "$path" ]] || continue
  repo=$(basename "$path")

  # Exclude check
  if printf '%s\n' "${EXCLUDES[@]}" | grep -qx "$repo"; then
    echo "🚫 Skipping $repo (excluded)"
    continue
  fi

  echo "🔍 Checking $repo..."

  cd "$path" || continue

  if [[ -d ".git" ]]; then
    found_any=true

    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    connected="✅"
    [[ -z "$remote_url" ]] && connected="❌" && remote_url="—"

    tag=$(git describe --tags --abbrev=0 2>/dev/null || git tag --sort=-creatordate | head -n1 || echo "—")
[[ -z "$tag" ]] && tag="—"

    status=$(git status -sb 2>/dev/null | head -n1 | sed 's/## //' || echo "—")

    echo "| \`$repo\` | $connected | $tag | $remote_url | $status |" >> "$OLDPWD/$OUTPUT_FILE"
  else
    echo "⚠️  No .git found in $repo"
  fi

  cd "$OLDPWD" || exit 1
done

if [[ "$found_any" == false ]]; then
  echo "❌ No Git repos found in: $ROOT_DIR"
else
  echo "✅ Report generated at: $OUTPUT_FILE"
fi
