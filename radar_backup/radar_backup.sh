#!/usr/bin/env bash
# --- radar_backup.sh ---
# CLI wrapper for modular backup/restore logic

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$SCRIPT_DIR/radar_backup_lib.sh"
source "$LIB"

VERSION="2.1.15"

# Find config
CONFIG_FILE=""
# 1. Parse --config without shifting away all args!
for ((i=1; i<=$#; i++)); do
  if [[ "${!i}" == "--config" ]]; then
    next=$((i+1))
    CONFIG_FILE="${!next}"
    # Remove --config and its value from the argument list
    set -- "${@:1:$((i-1))}" "${@:((i+2))}"
    break
  fi
done

# 2. Fallback if still not set
if [[ -z "$CONFIG_FILE" ]]; then
  if [[ -f "$PWD/.backup.json" ]]; then
    CONFIG_FILE="$PWD/.backup.json"
  elif [[ -f "$SCRIPT_DIR/.backup.json" ]]; then
    CONFIG_FILE="$SCRIPT_DIR/.backup.json"
  else
    echo "❌ No .backup.json found (tried: \$PWD, \$SCRIPT_DIR). Use --config <file>."
    exit 1
  fi
fi

ROOT_DIR="$(jq -r '.source' "$CONFIG_FILE")"
BACKUP_DIR="$(jq -r '.backup_dir' "$CONFIG_FILE")"
CATALOG_DIR="$(jq -r '.catalog_dir' "$CONFIG_FILE")"

MDLOG="$CATALOG_DIR/backup_log.md"
TPL="$CATALOG_DIR/backup_log.tpl"

# Flags
MODE=""
FILE=""
COUNT=5
QUIET="false"
DRYRUN="false"
VERBOSE="false"

show_help() {
  echo "radar_backup.sh - Modular Backup/Restore Tool (v$VERSION)"
  echo
  echo "Usage:"
  echo "  $0 --backup                        Create a backup"
  echo "  $0 --restore <file>                Restore from a backup file"
  echo "  $0 --recover <file>                Recover a deleted file from backup"
  echo "  $0 --prune <count>                 Keep only the <count> most recent backups"
  echo "  $0 --summary                       Display recent backup summary"
  echo
  echo "Flags:"
  echo "  --quiet                            Suppress non-essential output"
  echo "  --dryrun                           Simulate the operation without making changes"
  echo "  --verbose                          Show detailed logging"
  echo "  --help, -h                         Show this help message"
  echo
  echo "Examples:"
  echo "  $0 --backup"
  echo "  $0 --restore v2.1.14_20250710_075858.tar.gz"
  echo "  $0 --prune 3 --dryrun"
}

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup)   MODE="backup"; shift ;;
    
    
    --restore)
      MODE="restore"
      shift
      FILE="${1:-}"
      if [[ -z "$FILE" ]]; then
        echo "❌ Missing argument: --restore <file>"
        exit 1
      fi
      [[ "$FILE" == */* ]] || FILE="$BACKUP_DIR/$FILE"
      shift
      ;;
    --recover)
      MODE="recover"
      shift
      if [[ -z "$FILE" ]]; then
        echo "❌ Missing argument: --restore <file>"
        exit 1
      fi
      [[ "$FILE" == */* ]] || FILE="$BACKUP_DIR/$FILE"
      shift
      ;;
    --prune)    MODE="prune"; COUNT="${2:-5}"; shift 2 ;;
    --summary)  MODE="summary"; shift ;;
    --quiet)    QUIET="true"; shift ;;
    --dryrun)   DRYRUN="true"; shift ;;
    --verbose)  VERBOSE="true"; shift ;;
    --help|-h)  show_help; exit 0 ;;
    *) echo "❌ Unknown argument: $1"; show_help; exit 1 ;;
  esac
done

# --- Dispatch ---
case "$MODE" in
  backup)
    radar_backup_create "$ROOT_DIR" "$BACKUP_DIR" "$MDLOG" "$TPL" "$COUNT" "$DRYRUN" "$CONFIG_FILE"
    ;;
  restore)
    radar_backup_restore "$FILE" "$ROOT_DIR" "$BACKUP_DIR" "$MDLOG" "$DRYRUN" "$QUIET" "$VERBOSE"
    ;;
  recover)
    radar_backup_recover "$FILE" "$ROOT_DIR" "$BACKUP_DIR" "$MDLOG" "$DRYRUN" "$QUIET" "$VERBOSE"
    ;;
  prune)
    radar_backup_prune "$BACKUP_DIR" "$COUNT" "$MDLOG" "$DRYRUN" "$QUIET" "$VERBOSE"
    ;;
  summary)
    radar_backup_summary "$MDLOG" "$COUNT" "$QUIET"
    ;;
  *)
    echo "❌ No mode selected. Use one of: --backup, --restore, --recover, --prune, --summary"
    echo
    show_help
    exit 1
    ;;
esac
