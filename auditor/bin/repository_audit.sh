#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

VERSION="1.0.0"
SCRIPT_NAME="repository_audit.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
TEMPLATE="$SCRIPT_DIR/template/audit_report.tpl"

# Load shared functions
# shellcheck source=lib/utils.sh
source "$LIB_DIR/utils.sh"

# Default values
PARENT=""
CHILD=""
OUTPUT="markdown"
DRYRUN=false
HELP=false
SUMMARY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent)
      PARENT="$2"; shift 2;;
    --child)
      CHILD="$2"; shift 2;;
    --output)
      OUTPUT="$2"; shift 2;;
    --dryrun)
      DRYRUN=true; shift;;
    --summary)
      SUMMARY=true; shift;;
    --version)
      echo "$SCRIPT_NAME v$VERSION"; exit 0;;
    --help)
      HELP=true; shift;;
    *)
      echo "❌ Unknown option: $1"; exit 1;;
  esac
done

if [[ "$HELP" == true ]]; then
  cat <<EOF
📘 $SCRIPT_NAME (v$VERSION)

Usage:
  $SCRIPT_NAME --parent <folder> [--output markdown|table] [--dryrun] [--summary]
  $SCRIPT_NAME --child <repo_path> [--output markdown|table] [--dryrun] [--summary]

Options:
  --parent        Parent directory to scan for Git repositories
  --child         Single repository path to audit
  --output        Output format: markdown (default) or table
  --dryrun        Simulate only, don’t create any files
  --summary       Include summary block at the end
  --version       Show version information
  --help          Show this help message
EOF
  exit 0
fi

# Validate input
if [[ -n "$PARENT" && -n "$CHILD" ]]; then
  echo "❌ Please provide only one of --parent or --child"; exit 1
fi
if [[ -z "$PARENT" && -z "$CHILD" ]]; then
  echo "❌ Please provide either --parent or --child"; exit 1
fi

# Prepare output file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT="repos_report_$TIMESTAMP.md"

# Run audit
if [[ -n "$PARENT" ]]; then
  audit_parent "$PARENT" "$REPORT" "$OUTPUT" "$DRYRUN"
elif [[ -n "$CHILD" ]]; then
  audit_child "$CHILD" "$REPORT" "$OUTPUT" "$DRYRUN"
fi

# Show summary
if [[ "$SUMMARY" == true ]]; then
  print_summary "$REPORT"
fi

# Final message
[[ "$DRYRUN" == false ]] && echo "✅ Report saved to: $REPORT" || echo "🧪 Dry run completed."
