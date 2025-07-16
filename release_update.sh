#!/usr/bin/env bash
set -euo pipefail
set -o errtrace

# --- UTILS: Strict Mode Toggle ---
disable_strict_mode() { set +e +u +o pipefail; }
enable_strict_mode() {
  set -euo pipefail
  set -o errtrace
}

echo ""
IFS=$'\n\t'

VERSION="1.1.0"
SCRIPT_NAME="project_release"
DEFAULT_LOG="release.log"

# --- Defaults / Args ---
TARGET=""
DEST=""
BUMP="patch"
TPL=""
BIN=""
DRYRUN="false"
LOG="$DEFAULT_LOG"
SKIP_BACKUP="false"
SKIP_BUMP="false"
SKIP_DOC="false"
SKIP_COMMIT="false"
SKIP_AUDIT="false"
BUMP_FILE=""
AUDIT_DEST=""


usage() {
  cat <<EOF
$SCRIPT_NAME - Modular release orchestrator
Version: $VERSION

Usage: $0 --target <target> --output-dir <dest> --bump <major|minor|patch> --tpl <tpl_path> --bin <bin_path> [options]

  --target         Target repo/project (for backup)
  --output-dir     Backup destination
  --bump           Bump type: major|minor|patch
  --tpl            Template path for self_doc
  --bin            Binary/script location for self_doc
  --dryrun         Simulate all actions
  --log <file>     Log file (default: release.log)
  --audit-dest     Audit report destination
  --skip-backup    Skip repository_backup
  --skip-bump      Skip bump_version
  --skip-doc       Skip self_doc
  --skip-commit    Skip commit_gh
  --skip-audit     Skip repository_audit
  --help           Show this help
  --version        Show version

All CLI tools must be in \$PATH. Logs actions with timestamps and step progress.
EOF
}

log() {
  local level="$1"
  shift
  local msg
  msg="[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*"
  echo -e "$msg"
  echo -e "$msg" >>"$LOG"
}

progress() {
  local step="$1"
  local total="$2"
  local msg="$3"
  local timestamp
  timestamp="[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]"
  printf "%s [%d/%d] %s... " "$timestamp" "$step" "$total" "$msg"
}

finish_progress() {
  printf "✅\n"
}

fail_progress() {
  printf "❌\n"
}

if [[ "${1:-}" =~ ^(--help|-h)$ ]]; then
  usage
  exit 0
fi
if [[ "${1:-}" == "--version" ]]; then
  echo "$VERSION"
  exit 0
fi

# --- Parse Args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
  --target)
    TARGET="$2"
    shift 2
    ;;
  --output-dir)
    DEST="$2"
    shift 2
    ;;
  --bump)
    BUMP="$2"
    shift 2
    ;;
  --bump-file)
    BUMP_FILE="$2"
    shift 2
    ;;
  --tpl)
    TPL="$2"
    shift 2
    ;;
  --bin)
    BIN="$2"
    shift 2
    ;;
  --dryrun)
    DRYRUN="true"
    shift
    ;;
  --log)
    LOG="$2"
    shift 2
    ;;
--audit-dir)
    AUDIT_DEST="$2"
    shift 2
    ;;    
  --skip-backup)
    SKIP_BACKUP="true"
    shift
    ;;
  --skip-bump)
    SKIP_BUMP="true"
    shift
    ;;
  --skip-doc)
    SKIP_DOC="true"
    shift
    ;;
  --skip-commit)
    SKIP_COMMIT="true"
    shift
    ;;
  --skip-audit)
    SKIP_AUDIT="true"
    shift
    ;;
  --help)
    usage
    exit 0
    ;;
  --version)
    echo "$VERSION"
    exit 0
    ;;
  *)
    echo "Unknown arg: $1"
    usage
    exit 1
    ;;
  esac
done

# --- Dependency Check ---
deps=(repository_backup bump_version self_doc commit_gh repository_audit sanity_check)
for dep in "${deps[@]}"; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    log ERROR "Missing required CLI: $dep"
    exit 2
  fi
done

[[ -z "$TARGET" || -z "$DEST" || -z "$TPL" || -z "$BIN" ]] && {
  usage
  exit 3
}
[[ -z "$BUMP_FILE" ]] && {
  usage
  exit 3
}
[[ -z "$AUDIT_DEST" ]] && {
  usage
  exit 3
}

total_steps=6
current_step=1

# --- Step 1: repository_backup ---
step_backup() {
  progress $current_step $total_steps "Step 1: Backing up $TARGET"

  if [[ "${SKIP_BACKUP:-false}" == "true" ]]; then
    finish_progress
    log INFO "Step 1 skipped by flag."
    return
  fi

  # Sanity check for required variables
  if [[ -z "${TARGET:-}" || -z "${DEST:-}" ]]; then
    fail_progress
    log ERROR "Missing TARGET or DEST. Cannot proceed with backup."
    exit 11
  fi

  # Construct command dynamically for clarity/logging
  local CMD="repository_backup --target \"$TARGET\" --output-dir \"$DEST\""
  [[ "${DRYRUN:-false}" == "true" ]] && CMD+=" --dryrun"

  # Run command and capture output
  # log INFO "Running: $CMD"
  eval "$CMD" >>"$LOG" 2>&1

  if [[ $? -eq 0 ]]; then
    finish_progress
    log INFO "Step 1 completed: backup successful."
  else
    fail_progress
    log ERROR "Step 1 failed: repository_backup returned non-zero exit."
    log ERROR "Check log output in: $LOG"
    exit 10
  fi
}

# --- Step 2: sanity_check (non-blocking) ---
step_sanity() {
  current_step=$((current_step + 1))
  progress $current_step $total_steps "Step 2: sanity_check (validation only)"
  if sanity_check --quiet >>"$LOG" 2>&1; then
    finish_progress
    log INFO "Step 2 completed: sanity_check passed."
  else
    finish_progress
    log WARN "Step 2: sanity_check completed with warnings (not blocking)."
  fi
}

# --- Step 3: bump_version ---
step_bump() {
  current_step=$((current_step + 1))
  progress $current_step $total_steps "Step 3: bump_version $BUMP"
  if [[ "$SKIP_BUMP" == "true" ]]; then
    finish_progress
    log INFO "Step 3 skipped."
    return
  fi
  if bump_version "$BUMP_FILE" --"$BUMP" ${DRYRUN:+--dryrun} >>"$LOG" 2>&1; then
    finish_progress
    log INFO "Step 3 completed: bump_version $BUMP."
  else
    fail_progress
    log ERROR "Step 3 failed: bump_version error."
    exit 11
  fi
}

# --- Step 4: self_doc ---
step_doc() {
  current_step=$((current_step + 1))
  progress $current_step $total_steps "Step 4: Generating docs"

  if [[ "$SKIP_DOC" == "true" ]]; then
    finish_progress
    log INFO "Step 4 skipped."
    return
  fi

  if [[ "$DRYRUN" == "true" ]]; then
    self_doc \
      --tpl-dir "$TPL" \
      --cli-bin "$BIN" \
      --output-dir "$TARGET" \
      --outfile README.md \
      --dry-run >>"$LOG" 2>&1
  else
    self_doc \
      --tpl-dir "$TPL" \
      --cli-bin "$BIN" \
      --output-dir "$TARGET" \
      --outfile README.md >>"$LOG" 2>&1
  fi

  if [[ $? -eq 0 ]]; then
    finish_progress
    log INFO "Step 4 completed: self_doc successful."
  else
    fail_progress
    log ERROR "Step 4 failed: self_doc error."
    exit 12
  fi
}

# --- Step 5: commit_gh ---
step_commit() {
  current_step=$((current_step + 1))
  progress $current_step $total_steps "Step 5: Committing changes"
  if [[ "$SKIP_COMMIT" == "true" ]]; then
    finish_progress
    log INFO "Step 5 skipped."
    return
  fi
  pushd "$TARGET" >/dev/null
  if commit_gh ${DRYRUN:+--dryrun} >>"$LOG" 2>&1; then
    popd >/dev/null
    finish_progress
    log INFO "Step 5 completed: commit_gh successful."
  else
    popd >/dev/null
    fail_progress
    log ERROR "Step 5 failed: commit_gh error."
    exit 13
  fi
}

# --- Step 6: repository_audit ---
step_audit() {
  current_step=$((current_step + 1))
  progress $current_step $total_steps "Step 6: repository_audit (child)"
  if [[ "$SKIP_AUDIT" == "true" ]]; then
    finish_progress
    log INFO "Step 6 skipped."
    return
  fi
  if repository_audit --child "$TARGET" --outdir "$AUDIT_DEST" ${DRYRUN:+--dryrun} >>"$LOG" 2>&1; then

# if repository_audit --child "$TARGET" --outdir "$DEST" ${DRYRUN:+--dryrun} >>"$LOG" 2>&1; then
    finish_progress
    log INFO "Step 6 completed: repository_audit successful."
  else
    fail_progress
    log ERROR "Step 6 failed: repository_audit error."
    exit 14
  fi
}

# --- Bump all scripts to the new version ---
bump_all_scripts_to_version() {
  local version="$1"
  local base
  base="$(cd "$2" && pwd)"
  local updated=0
  local total=0
  local folders=("$base/bin" "$base/lib" "$base/core")
  disable_strict_mode
  while IFS= read -r -d '' file; do
    if grep -q 'VERSION="' "$file"; then
      ((total++))
      cur_ver=$(awk -F'"' '/VERSION="/ {print $2; exit}' "$file")
      if [[ "$cur_ver" != "$version" ]]; then
        if stat --version >/dev/null 2>&1; then
          perms=$(stat --format '%a' "$file")
        else
          perms=$(stat -f '%A' "$file")
        fi
        awk -v ver="$version" '{ if ($0 ~ /VERSION="/) sub(/VERSION=".*"/, "VERSION=\"" ver "\""); print }' "$file" >"$file.tmp" &&
          mv "$file.tmp" "$file" && chmod "$perms" "$file"
        log INFO "📝 Bumped $(basename "$file") ($cur_ver → $version)"

        ((updated++))
      fi
    fi
  done < <(find "${folders[@]}" -type f -name '*.sh' -print0 2>/dev/null)
  enable_strict_mode
  if ((updated == 0)); then
    log INFO "✅ All scripts already at VERSION $version"
  else
    log INFO "✅ Updated $updated of $total scripts to VERSION $version"
  fi
}

# --- Step: Brew Formula Check ---
check_brew_formula() {
  local formula_dir="$TARGET/Formula"
  if [[ -d "$formula_dir" ]]; then
    shopt -s nullglob
    local rb_files=("$formula_dir"/*.rb)
    if ((${#rb_files[@]})); then
      for f in "${rb_files[@]}"; do
        log INFO "Detected Homebrew formula: $f"
      done
      log INFO "✅ Project is brew formula-enabled (Formula/*.rb found)"
    else
      log INFO "Formula/ directory exists, but no .rb files found."
    fi
    shopt -u nullglob
  else
    log INFO "No Formula/ directory detected under $TARGET."
  fi
}

# --- Main function ---
main() {
  log INFO "$SCRIPT_NAME v$VERSION starting."
  step_backup
  step_sanity
  step_bump

  # --- CRITICAL: Get the latest version *after* bump_version has run! ---
  SYNC_VERSION=$(awk -F'"' '/^VERSION="/ { print $2; exit }' "$BUMP_FILE")
  log INFO "Syncing VERSION=$SYNC_VERSION to all scripts in $TARGET"
  bump_all_scripts_to_version "$SYNC_VERSION" "$TARGET"

  # --- Brew formula check (NEW) ---
  check_brew_formula

  step_doc
  step_commit
  step_audit
  log INFO "All steps complete. Full details in $LOG"
  echo -e "\n🚀 Release workflow finished. Check $LOG for details."
}

# --- Run the main function ---
main "$@"

if [[ -t 1 ]]; then
  echo -e "\n\033[1;32mAll release steps completed successfully.\033[0m"
fi
