#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

VERSION="1.0.0"

ROOT_DIR="."
OUTPUT_FILE="repos_report.md"
DRYRUN=false
SORT_BY="tag"
ORDER="desc"
EXCLUDES=()

print_help() {
  cat <<EOF
📘 audit_git_repos.sh — Git Repo Auditor

Usage:
  ./audit_git_repos.sh [root_dir] [--exclude DIR ...] [--sort tag|name|date] [--order asc|desc] [--dryrun]

Options:
  --help       Show this help message and exit
  --version    Show version info and exit
  --dryrun     Simulate scan without writing to output file
  --exclude    Exclude specific subdirectories (can be repeated)
  --sort       Sort by: tag | name | date   (default: tag)
  --order      asc or desc                  (default: desc)

Example:
  ./audit_git_repos.sh ./projects --exclude backups temp --sort name --order asc
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      print_help
      exit 0
      ;;
    --version)
      echo "🧾 audit_git_repos.sh v$VERSION"
      exit 0
      ;;
    --exclude)
      shift
      EXCLUDES+=("$1")
      ;;
    --sort)
      shift
      SORT_BY="$1"
      ;;
    --order)
      shift
      ORDER="$1"
      ;;
    --dryrun)
      DRYRUN=true
      ;;
    *)
      ROOT_DIR="$1"
      ;;
  esac
  shift
done

AUDIT_IGNORE_FILE="$ROOT_DIR/.auditignore"
if [[ -f "$AUDIT_IGNORE_FILE" ]]; then
  while read -r line; do
    [[ -n "$line" && ! "$line" =~ ^# ]] && EXCLUDES+=("$line")
  done < "$AUDIT_IGNORE_FILE"
fi

mapfile -t REPORT_LINES < <(echo "| Repo | Connected | Latest Tag | Remote URL | Status |"; echo "|------|-----------|------------|------------|--------|")

declare -A TAG_MAP

echo "📂 ${DRYRUN:+Dry run — }scanning: $ROOT_DIR"

found_any=false

for path in "$ROOT_DIR"/*; do
  [[ -d "$path" ]] || continue
  dir_name=$(basename "$path")

  if [[ " ${EXCLUDES[*]} " =~ " $dir_name " ]]; then
    echo "🚫 ${DRYRUN:+Would }skip excluded: $dir_name"
    continue
  fi

  echo "🔍 ${DRYRUN:+Would }check: $dir_name..."

  if [[ -d "$path/.git" ]]; then
    found_any=true
    cd "$path"

    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    connected="✅"
    [[ -z "$remote_url" ]] && connected="❌" && remote_url="—"

    tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "—")
    status=$(git status -sb 2>/dev/null | head -n1 | sed 's/## //' || echo "—")

    line="| \`$dir_name\` | $connected | $tag | $remote_url | $status |"
    REPORT_LINES+=("$line")
    TAG_MAP["$dir_name"]="$tag"

    cd - >/dev/null || exit 1
  else
    echo "⚠️  No .git found in $dir_name"
  fi

done

if [[ "$found_any" == false ]]; then
  echo "❌ No Git repos found in: $ROOT_DIR"
  exit 1
fi

# Sort
sorted_lines=("${REPORT_LINES[0]}" "${REPORT_LINES[1]}")
rest=("${REPORT_LINES[@]:2}")

case "$SORT_BY" in
  tag)
    sorted_rest=( $(printf "%s\n" "${rest[@]}" | sort -t '|' -k4 -V) )
    ;;
  name)
    sorted_rest=( $(printf "%s\n" "${rest[@]}" | sort -t '|' -k2) )
    ;;
  date)
    # Not implemented due to tag-to-date mapping limitations
    sorted_rest=("${rest[@]}")
    ;;
  *)
    sorted_rest=("${rest[@]}")
    ;;

esac

[[ "$ORDER" == "desc" ]] && sorted_rest=( $(printf "%s\n" "${sorted_rest[@]}" | tac) )

sorted_lines+=("${sorted_rest[@]}")

if [[ "$DRYRUN" == false ]]; then
  printf "%s\n" "# 🧾 Repository Audit Report" > "$OUTPUT_FILE"
  printf "%s\n" "" >> "$OUTPUT_FILE"
  for line in "${sorted_lines[@]}"; do
    echo "$line" >> "$OUTPUT_FILE"
  done
  echo "✅ Report generated at: $OUTPUT_FILE"
else
  echo "✅ Dry run complete. No output written."
fi
