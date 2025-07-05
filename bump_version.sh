#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.12.4"

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
if [[ "$RAW_SCRIPT" == "--help" ]]; then
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

SCRIPT_BASENAME=$(basename "${SCRIPT_PATH%.sh}")
CHANGELOG="$(dirname "$SCRIPT_PATH")/CHANGELOG_${SCRIPT_BASENAME}.md"

# --- Find and validate VERSION line ---
current_line=$(grep -E '^[[:space:]]*VERSION="[0-9]+\.[0-9]+\.[0-9]+"' "$SCRIPT_PATH" | head -n1 || true)
if [[ -z "$current_line" ]]; then
  echo -e "${RED}❌ VERSION line not found in $SCRIPT_PATH${RESET}"
  exit 1
fi
current_version=$(echo "$current_line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
IFS='.' read -r major minor patch <<<"$current_version"

# --- Normalize version numbers ---
major=$((10#$major))
minor=$((10#$minor))
patch=$((10#$patch))

# --- Validate extracted version ---
if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}❌ Invalid version number format in $current_version${RESET}"
  exit 1
fi

# --- Calculate next version ---
case "$BUMP_TYPE" in
major)
  new_major=$((major + 1))
  new_minor=0
  new_patch=0
  msg_type="🟥"
  ;;
minor)
  new_major=$major
  new_minor=$((minor + 1))
  new_patch=0
  msg_type="🔵"
  ;;
patch)
  new_major=$major
  new_minor=$minor
  new_patch=$((patch + 1))
  msg_type="🟣"
  ;;
esac

new_version="${new_major}.${new_minor}.${new_patch}"

if [[ "$current_version" == "$new_version" ]]; then
  echo -e "${YELLOW}⚠️  No change: Version already at $new_version (forcing next logical version)${RESET}"
  case "$BUMP_TYPE" in
  major) new_version="$((new_major + 1)).0.0" ;;
  minor) new_version="${new_major}.$((new_minor + 1)).0" ;;
  patch) new_version="${new_major}.${new_minor}.$((new_patch + 1))" ;;
  esac
fi

# --- DRY RUN ---
if [[ "$DRY_RUN" == "1" ]]; then
  echo -e "${CYAN}🧪 [DRY RUN] Would update ${SCRIPT_PATH}: ${current_version} → ${new_version}${RESET}"
  [[ "$WRITE_CHANGELOG" == "1" ]] && echo -e "${CYAN}🧪 [DRY RUN] Would update CHANGELOG.md${RESET}"
  exit 0
fi

########################################################################################
# --- Insert # shellcheck disable=SC2034 above VERSION if missing ---
tmpfile_sc="$(dirname "$SCRIPT_PATH")/.bump_sc_tmp_$$"
sc_added=0
found=0
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" =~ ^[[:space:]]*VERSION=\"[0-9]+\.[0-9]+\.[0-9]+\" ]]; then
    found=1
    # Check previous line by reading file into an array (expensive, but fine for short files)
    prev_line="$(tail -n +$(($(grep -n "$line" "$SCRIPT_PATH" | head -n1 | cut -d: -f1)-1)) "$SCRIPT_PATH" | head -n1 || true)"
    if [[ "$prev_line" != "# shellcheck disable=SC2034" ]]; then
      echo "# shellcheck disable=SC2034" >> "$tmpfile_sc"
      sc_added=1
    fi
  fi
  echo "$line" >> "$tmpfile_sc"
done < "$SCRIPT_PATH"

if [[ $found -eq 1 ]]; then
  mv "$tmpfile_sc" "$SCRIPT_PATH"
  [[ $sc_added -eq 1 ]] && echo -e "${CYAN}🧪 Added '# shellcheck disable=SC2034' above VERSION for ShellCheck compliance.${RESET}"
else
  rm -f "$tmpfile_sc"
fi
########################################################################################

# --- Replace VERSION in script safely ---
TMPFILE="$(dirname "$SCRIPT_PATH")/.bump_tmp_$$"
was_executable=0
[[ -x "$SCRIPT_PATH" ]] && was_executable=1

awk -v v="VERSION=\"${new_version}\"" '
  c==0 && /^[[:space:]]*VERSION="[0-9]+\.[0-9]+\.[0-9]+"/ { print v; c=1; next }
  { print }
' "$SCRIPT_PATH" >"$TMPFILE" && mv "$TMPFILE" "$SCRIPT_PATH"

[[ "$was_executable" == "1" ]] && chmod +x "$SCRIPT_PATH"

# --- Write to CHANGELOG if enabled ---
timestamp=$(date "+%Y-%m-%d %H:%M:%S")
user=$(whoami)
entry="${msg_type} ${timestamp} — ${user}: ${SCRIPT_PATH##*/} bumped from ${current_version} to ${new_version}"
BADGE="[![version](https://img.shields.io/badge/version-${new_version}-red)](https://github.com/raymonepping)"

if [[ "$WRITE_CHANGELOG" == "1" ]]; then
  tmp_changelog="${CHANGELOG}.tmp"
  if [[ ! -d "$(dirname "$CHANGELOG")" ]]; then
    mkdir -p "$(dirname "$CHANGELOG")"
  fi
  if [[ ! -f "$CHANGELOG" ]]; then
    echo -e "# CHANGELOG: ${SCRIPT_BASENAME}\n\n$entry\n" >"$CHANGELOG"
  else
    awk -v badge="$BADGE" -v entry="$entry" '
      BEGIN { badge_inserted=0; entry_inserted=0 }
      NR==1 && /^# CHANGELOG/ { print $0; next }
      /^\[\!\[version.*shields\.io\/badge\/version/ { print badge; badge_inserted=1; next }
      /^\!\[.*shields\.io\/badge\/version/ { print badge; badge_inserted=1; next }
      !entry_inserted && badge_inserted { print ""; print entry; entry_inserted=1 }
      { print }
      END {
        if (!badge_inserted) print badge
        if (!entry_inserted) { print ""; print entry }
      }
    ' "$CHANGELOG" >"$tmp_changelog" && mv "$tmp_changelog" "$CHANGELOG"
  fi
  echo -e "${CYAN}📝 CHANGELOG updated: ${CHANGELOG}${RESET}"
fi

# --- Replace VERSION in script safely and preserve +x permissions ---
TMPFILE="$(dirname "$SCRIPT_PATH")/.bump_tmp_$$"

# Preserve current execute permission (optional, mostly for clarity)
was_executable=0
[[ -x "$SCRIPT_PATH" ]] && was_executable=1

# Replace the version
awk -v v="VERSION=\"${new_version}\"" '
  c==0 && /^[[:space:]]*VERSION="[0-9]+\.[0-9]+\.[0-9]+"/ { print v; c=1; next }
  { print }
' "$SCRIPT_PATH" >"$TMPFILE" && mv "$TMPFILE" "$SCRIPT_PATH"

# 🛠 Always restore executable bit to avoid permission errors
chmod +x "$SCRIPT_PATH"

echo -e "${GREEN}✅ ${SCRIPT_PATH} bumped: ${current_version} → ${new_version}${RESET}"