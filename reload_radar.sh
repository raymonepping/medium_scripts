#!/usr/bin/env bash

set -euo pipefail
set -o errtrace

disable_strict_mode() { set +e +u +o pipefail; }
enable_strict_mode()  { set -euo pipefail; set -o errtrace; }

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() {
  # If QUIET=true, only print ERROR/FAIL lines, else print everything
  local level="$1"
  shift
  if [[ "${QUIET:-false}" == true && "$level" != "ERROR" && "$level" != "FAIL" ]]; then
    return
  fi
  echo "[$(timestamp)] $level $*"
}

# Always prints, even in quiet mode
note_update() { echo -e "$@"; }

# Only prints in verbose mode (or not quiet)
note() { [[ "${QUIET:-false}" == true ]] && return; echo -e "$@"; }

HELP_MSG="
Usage: reload_radar.sh [--verbose|--quiet|--help]

Options:
  --verbose      Show every script, including unchanged ones
  --quiet        Only print updated scripts (default)
  --help         Show this help message and exit
"

QUIET=true
for i in "$@"; do
  case "${i,,}" in
    --help) echo "$HELP_MSG"; exit 0 ;;
    --quiet) QUIET=true ;;
    --quiet=*|--quiet:*) val="${i#*=}"; QUIET="${val,,}";;
    --quiettrue|--quiet1|--quietyes) QUIET=true ;;
    --quietfalse|--quiet0|--quietno) QUIET=false ;;
    --verbose) QUIET=false ;;
  esac
done

log "INFO" "Reloading radar_love_cli cleanly..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RADAR_DIR="$SCRIPT_DIR/radar_love_cli"
cd "$SCRIPT_DIR"

VERSION=$(awk -F'"' '/^VERSION="/ { print $2; exit }' "$RADAR_DIR/bin/radar_love")
log "INFO" "Detected version: $VERSION"

FORMULA_FILE="radar-love-cli.rb"
FORMULA_PATH="$RADAR_DIR/Formula/$FORMULA_FILE"

if [[ ! -f "$FORMULA_PATH" ]]; then
  log "ERROR" "Formula file not found: $FORMULA_PATH"
  exit 1
fi

log "INFO" "Found formula: $FORMULA_PATH"
log "INFO" "Syncing VERSION to all scripts in bin/ and core/..."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

UPDATED=0
UPDATED_FILES=()
TOTAL=0

disable_strict_mode
while IFS= read -r -d '' file; do
  BASENAME=$(basename "$file")
  ((TOTAL++))
  CUR_VERSION=$(awk -F'"' '/^[[:space:]]*VERSION="/ {print $2}' "$file" | head -1)

  if [[ "$CUR_VERSION" != "$VERSION" ]]; then
    note_update "${YELLOW}📝 $BASENAME updated ($CUR_VERSION → $VERSION)${NC}"
    # Grab current permissions (Mac: stat -f; Linux: stat --format)
    if stat --version >/dev/null 2>&1; then
      # Linux/GNU stat
      PERMS=$(stat --format '%a' "$file")
    else
      # macOS/BSD stat
      PERMS=$(stat -f '%A' "$file")
    fi
    awk -v ver="$VERSION" '{ if ($0 ~ /^[[:space:]]*VERSION="/) sub(/^[[:space:]]*VERSION=".*"/, "VERSION=\"" ver "\""); print }' "$file" > "$file.tmp" && \
      mv "$file.tmp" "$file" && \
      chmod "$PERMS" "$file"
    UPDATED_FILES+=("$BASENAME")
    ((UPDATED++))
  else
    note "  $BASENAME unchanged (VERSION: $CUR_VERSION)"
  fi

done < <(find "$RADAR_DIR/bin" "$RADAR_DIR/core" -type f -name '*.sh' -print0 2>/dev/null)
enable_strict_mode

if (( UPDATED == 0 )); then
  note_update "${GREEN}✅ All scripts already at VERSION $VERSION${NC}"
fi

if [[ "$QUIET" == false ]]; then
  note "Total scripts scanned: $TOTAL"
fi

# --- Remaining steps unchanged below ---

(
  cd "$RADAR_DIR"
  log "INFO" "Staging and committing CLI updates to Git..."

  git add "$FORMULA_FILE" || true
  git add bin/* || true
  git add core/*.sh || true

  if git diff --cached --quiet; then
    log "INFO" "No CLI changes to commit."
  else
    git commit -m "chore(release): sync scripts and bump to v$VERSION"
    git push
  fi

  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ "$REMOTE_URL" =~ radar[-_]love[-_]cli ]]; then
    if ! git tag | grep -q "v$VERSION"; then
      log "INFO" "Tagging v$VERSION..."
      git tag "v$VERSION"
      git push origin "v$VERSION"
    else
      log "INFO" "Tag v$VERSION already exists."
    fi
  else
    log "INFO" "Not tagging — not in radar_love_cli repo."
  fi
)
cd - > /dev/null

TAR_URL="https://github.com/raymonepping/homebrew-radar-love-cli/archive/refs/tags/v${VERSION}.tar.gz"
CODELOAD_URL="https://codeload.github.com/raymonepping/homebrew-radar-love-cli/tar.gz/refs/tags/v${VERSION}"
TAR_NAME="radar-love-cli-${VERSION}.tar.gz"

log "INFO" "Waiting for GitHub tarball to be published..."

for i in {1..30}; do
  if curl --silent --head --fail "$CODELOAD_URL" >/dev/null; then
    log "INFO" "Tarball is available at $CODELOAD_URL (try $i)"
    break
  fi
  log "INFO" "Tarball not ready yet... ($i)"
  sleep 2
done

if ! curl --silent --head --fail "$CODELOAD_URL" >/dev/null; then
  log "ERROR" "Tarball still not available after 60s. Try again soon."
  exit 1
fi

log "INFO" "Downloading archive from $TAR_URL"
for i in {1..10}; do
  curl -Lsf -o "/tmp/${TAR_NAME}" "$TAR_URL" || true
  FILESIZE=$(stat -f%z "/tmp/${TAR_NAME}" 2>/dev/null || echo 0)
  if (( FILESIZE > 10000 )); then
    log "INFO" "Tarball downloaded and valid."
    break
  fi
  log "INFO" "Tarball still not ready... ($i)"
  sleep 2
done

if (( FILESIZE <= 10000 )); then
  log "ERROR" "Tarball invalid or too small after 10 attempts."
  exit 1
fi

SHA256=$(shasum -a 256 "/tmp/${TAR_NAME}" | cut -d ' ' -f1)
log "INFO" "Calculated SHA256: $SHA256"

log "INFO" "Updating formula: $FORMULA_PATH"
awk -v url="$TAR_URL" -v sha="$SHA256" -v version="$VERSION" '
  {
    if ($1 == "url")      { print "  url \"" url "\"" }
    else if ($1 == "sha256")  { print "  sha256 \"" sha "\"" }
    else if ($1 == "version") { print "  version \"" version "\"" }
    else { print }
  }
' "$FORMULA_PATH" > "$FORMULA_PATH.tmp" && mv "$FORMULA_PATH.tmp" "$FORMULA_PATH"
log "INFO" "Formula updated."

FORMULA_DIR_COMMIT=$(dirname "$FORMULA_PATH")
(
  cd "$FORMULA_DIR_COMMIT"
  log "INFO" "Committing updated formula..."
  git add "$(basename "$FORMULA_PATH")" || true

  if git diff --cached --quiet; then
    log "INFO" "No formula changes to commit."
  else
    git commit -m "chore(formula): update to v$VERSION"
    git push
  fi
)

if brew list radar-love-cli &>/dev/null; then
  log "INFO" "Uninstalling existing radar-love-cli..."
  brew uninstall radar-love-cli
elif brew list radar_love_cli &>/dev/null; then
  log "INFO" "Uninstalling old radar_love_cli..."
  brew uninstall radar_love_cli
else
  log "INFO" "radar-love-cli not installed — skipping uninstall."
fi

if brew tap | grep -q "raymonepping/radar_love_cli"; then
  log "INFO" "Untapping raymonepping/radar_love_cli..."
  brew untap raymonepping/radar_love_cli
fi

for cellar in \
    "$(brew --prefix)/Cellar/radar-love-cli" \
    "$(brew --prefix)/Cellar/radar_love_cli"
do
  if [[ -d "$cellar" ]]; then
    log "INFO" "Removing leftover Cellar path: $cellar"
    rm -rf "$cellar"
  fi
done

RADAR_BIN="$(command -v radar_love || true)"
if [[ -n "$RADAR_BIN" && -f "$RADAR_BIN" ]]; then
  log "INFO" "Removing old binary at: $RADAR_BIN"
  rm -f "$RADAR_BIN"
fi

log "INFO" "Tapping raymonepping/radar_love_cli..."
brew tap raymonepping/radar_love_cli

log "INFO" "Installing radar_love_cli..."
brew install raymonepping/radar_love_cli/radar-love-cli

tag_stats() {
  local TAG_COUNT LATEST_TAG
  TAG_COUNT=$(git tag | grep -c .)
  LATEST_TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || echo "")
  local MAJOR_RELEASE=""

  if [[ -z "$LATEST_TAG" ]]; then
    LATEST_TAG="(none yet!)"
  fi

  # Allow optional "v" prefix (v2.0.0 or 2.0.0)
  if [[ "$LATEST_TAG" =~ ^v?([0-9]+)\.0\.0$ ]]; then
    MAJOR_RELEASE="true"
  fi

  echo "🎸 You've released $TAG_COUNT versions... but who's counting?"
  echo "🏷️  Latest version tag: $LATEST_TAG"

  if [[ "$MAJOR_RELEASE" == "true" ]]; then
    echo -e "🚀 Major Release $LATEST_TAG — Flag validation hardened, user experience tightened, and rockstar stats added."
  fi
  echo
}

log "INFO" "Verifying installation..."
if command -v radar_love &>/dev/null; then
  log "INFO" "Installed at: $(which radar_love)"
  radar_love --version
  echo ""
  (cd "$RADAR_DIR" && tag_stats)
else
  log "ERROR" "Installation failed."
  exit 1
fi