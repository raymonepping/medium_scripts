#!/usr/bin/env bash
set -euo pipefail
VERSION="1.12.0"

# test
# - test 2

# --- Define Colors for Output ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

# --- Setting Defaults to be used later ---
WRITE_CHANGELOG=1
DRY_RUN=0

# --- Parse script arguments ---
RAW_SCRIPT="${1:-}"
BUMP_TYPE="${2:---patch}"

if [[ -z "$RAW_SCRIPT" ]]; then
  echo -e "${RED}❌ Usage: bump_version <script_name> [--patch|--minor|--major] [--changelog true|false] [--dry-run]${RESET}"
  exit 1
fi

# --- Handle --help flag ---
if [[ "${1:-}" == "--help" ]]; then
  cat <<EOF
$(basename "$0") [script.sh] [--patch|--minor|--major] [--changelog true|false] [--dry-run] [--help]

Automates semantic version bumps in Bash scripts with VERSION="x.y.z" format.

  --patch         Increment the patch version (default)
  --minor         Increment the minor version (reset patch)
  --major         Increment the major version (reset minor/patch)
  --changelog     true (default) or false; log bumps to CHANGELOG.md
  --dry-run       Show what would happen, but make no changes
  --help          Show this help and exit

Examples:
  ./bump_version.sh myscript.sh --patch
  ./bump_version.sh myscript.sh --minor --changelog false
  ./bump_version.sh myscript.sh --major --dry-run
EOF
  exit 0
fi

# --- Handling additional flags ---
shift 2 || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --changelog)
      [[ "${2:-}" == "false" ]] && WRITE_CHANGELOG=0
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# --- Validate bump type ---
if [[ ! "$BUMP_TYPE" =~ ^--?(patch|minor|major)$ ]]; then
  echo -e "${RED}❌ Invalid bump type: $BUMP_TYPE${RESET}"
  exit 1
fi
BUMP_TYPE="${BUMP_TYPE/--/}"

# --- Resolve script path ---
SCRIPT_PATH="$RAW_SCRIPT"
[[ ! -f "$SCRIPT_PATH" && -f "${RAW_SCRIPT}.sh" ]] && SCRIPT_PATH="${RAW_SCRIPT}.sh"
[[ ! -f "$SCRIPT_PATH" && -f "./${RAW_SCRIPT}" ]] && SCRIPT_PATH="./${RAW_SCRIPT}"
if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo -e "${RED}❌ Script not found: $SCRIPT_PATH${RESET}"
  exit 1
fi

# --- Set derived metadata ---
SCRIPT_BASENAME=$(basename "${SCRIPT_PATH%.sh}")

# --- Set CHANGELOG file name, assuming the script is in the same directory as the CHANGELOG ---
CHANGELOG="$(dirname "$SCRIPT_PATH")/CHANGELOG_${SCRIPT_BASENAME}.md"

current_line=$(grep -E '^[[:space:]]*VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$SCRIPT_PATH" | head -n1 || true)
if [[ -z "$current_line" ]]; then
  echo -e "${RED}❌ VERSION line not found in $SCRIPT_PATH${RESET}"
  exit 1
fi
current_version=$(echo "$current_line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
IFS='.' read -r major minor patch <<< "$current_version"

# --- Normalize version numbers ---
major=$((10#$major))
minor=$((10#$minor))
patch=$((10#$patch))

# --- Validate extracted version ---
if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}❌ Invalid version number format in $current_version${RESET}"
  exit 1
fi

# --- Calculate next version to be used ---
case "$BUMP_TYPE" in
  major)
    new_major=$((major + 1)); new_minor=0; new_patch=0
    msg_type="🟥"
    ;;
  minor)
    new_major=$major; new_minor=$((minor + 1)); new_patch=0
    msg_type="🔵"
    ;;
  patch)
    new_major=$major; new_minor=$minor; new_patch=$((patch + 1))
    msg_type="🟣"
    ;;
esac

# --- Construct new version string ---
new_version="${new_major}.${new_minor}.${new_patch}"

# --- Handle version already bumped ---
if [[ "$current_version" == "$new_version" ]]; then
  echo -e "${YELLOW}⚠️  No change: Version already at $new_version (forcing next logical version)${RESET}"
  case "$BUMP_TYPE" in
    major)
      new_version="$((new_major + 1)).0.0"
      ;;
    minor)
      new_version="${new_major}.$((new_minor + 1)).0"
      ;;
    patch)
      new_version="${new_major}.${new_minor}.$((new_patch + 1))"
      ;;
  esac
fi

# --- Dry-run behavior ---
if [[ "$DRY_RUN" == "1" ]]; then
  echo -e "${CYAN}🧪 [DRY RUN] Would update ${SCRIPT_PATH}: ${current_version} → ${new_version}${RESET}"
  [[ "$WRITE_CHANGELOG" == "1" ]] && echo -e "${CYAN}🧪 [DRY RUN] Would update CHANGELOG.md${RESET}"
  exit 0
fi

# --- Safely replace VERSION line ---
TMPFILE="$(dirname "$SCRIPT_PATH")/.bump_tmp_$$"
was_executable=0
[[ -x "$SCRIPT_PATH" ]] && was_executable=1

# --- Check if original script was executable ---
was_executable=0
[[ -x "$SCRIPT_PATH" ]] && was_executable=1

# --- Replace VERSION line in script safely ---
awk -v v="VERSION=\"${new_version}\"" '
  c==0 && /^[[:space:]]*VERSION="[0-9]+\.[0-9]+\.[0-9]+"/ { print v; c=1; next }
  { print }
' "$SCRIPT_PATH" > "$TMPFILE" && mv "$TMPFILE" "$SCRIPT_PATH"

# --- Restore executable flag if it was set originally ---
[[ "$was_executable" == "1" ]] && chmod +x "$SCRIPT_PATH"

# --- Prepare to write to Changelog ---
timestamp=$(date "+%Y-%m-%d %H:%M:%S")
user=$(whoami)
entry="${msg_type} ${timestamp} — ${user}: ${SCRIPT_PATH##*/} bumped from ${current_version} to ${new_version}"

# --- Create badge for version ---
BADGE="[![version](https://img.shields.io/badge/version-${new_version}-red)](https://github.com/raymonepping)"

# --- Write to CHANGELOG if enabled ---
if [[ "$WRITE_CHANGELOG" == "1" ]]; then
  tmp_changelog="${CHANGELOG}.tmp"

  # --- Check if CHANGELOG file exists, if not create it with the entry ---
  if [[ ! -d "$(dirname "$CHANGELOG")" ]]; then
  mkdir -p "$(dirname "$CHANGELOG")"
  fi

  if [[ ! -f "$CHANGELOG" ]]; then

    echo -e "# CHANGELOG: ${SCRIPT_BASENAME}\n\n$entry\n" > "$CHANGELOG"
  else
    awk -v badge="$BADGE" -v entry="$entry" '
      BEGIN { badge_inserted=0; entry_inserted=0 }
      NR==1 && /^# CHANGELOG/ {
        print $0
        next
      }
      /^\[\!\[version.*shields\.io\/badge\/version/ {
        print badge
        badge_inserted=1
        next
      }
      /^\!\[.*shields\.io\/badge\/version/ {
        print badge
        badge_inserted=1
        next
      }
      !entry_inserted && badge_inserted {
        print ""; print entry
        entry_inserted=1
      }
      { print }
      END {
        if (!badge_inserted) print badge
        if (!entry_inserted) {
          print ""; print entry
        }
      }
    ' "$CHANGELOG" > "$tmp_changelog" && mv "$tmp_changelog" "$CHANGELOG"
  fi

  # --- Output Changelog update message ---
  echo -e "${CYAN}📝 CHANGELOG updated: ${CHANGELOG}${RESET}"
fi

# --- Generate success message ---
echo -e "${GREEN}✅ ${SCRIPT_PATH} bumped: ${current_version} → ${new_version}${RESET}"
[[ "${DEBUG:-0}" == "1" ]] && tail -n 4 "$CHANGELOG"

# --- Generate updated documentation for this script ---
if [[ -x "./generate_documentation.sh" ]]; then
  ./generate_documentation.sh "$SCRIPT_PATH" --strict
  echo -e "${GREEN}📚 Documentation updated: docs/$(basename "${SCRIPT_PATH%.sh}").md${RESET}"
else
  echo -e "${YELLOW}⚠️  generate_documentation.sh not found or not executable — skipping doc generation${RESET}"
fi
