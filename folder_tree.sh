#!/usr/bin/env bash
set -euo pipefail
set -o errtrace

disable_strict_mode() { set +e +u +o pipefail; }
enable_strict_mode()  { set -euo pipefail; set -o errtrace; }

VERSION="1.5.6"

# --- COLORS & ICONS ---
color_reset=$'\e[0m'
color_green=$'\e[32m'
color_red=$'\e[31m'
color_yellow=$'\e[33m'
color_blue=$'\e[34m'
color_bold=$'\e[1m'
color_info=$'\e[36m'

icon_ok="✅"
icon_warn="⚠️"
icon_err="❌"
icon_tree="🌳"
icon_info="ℹ️"
icon_md="📜"
icon_git="🔗"
icon_hidden="👻"
icon_preset="🧰"
icon_excl="🛡️"
icon_target="📂"

# Default presets
TARGET_DIR="."
EXCLUDES=()
USED_PRESETS=()
OUTPUT_MODE="tree"
CONFIG_FILE="$HOME/.treeignore"
COLOR=true
HISTORY_MODE=false
HIDDEN=false
SHOW_VERSION=false
VERBOSE=false
QUIET=false
HINT_FILE="$HOME/.broot_hint_seen"
GROUP_EXT=""

declare -A EXCLUDE_PRESETS

# 🧰 Back-end / scripting
EXCLUDE_PRESETS[node]="node_modules dist .next .vite"
EXCLUDE_PRESETS[python]="__pycache__ .venv venv *.pyc"
EXCLUDE_PRESETS[terraform]=".terraform"
EXCLUDE_PRESETS[docker]="*.dockerfile Dockerfile*"

# ☕ Java / Maven / Gradle
EXCLUDE_PRESETS[java]="target .gradle .idea build *.class out"

# 📦 JS tooling
EXCLUDE_PRESETS[javascript]=".eslintcache .turbo .cache"

# 🎨 Vue / Nuxt
EXCLUDE_PRESETS[vue]=".vite dist coverage"
EXCLUDE_PRESETS[nuxt]=".nuxt .output dist"

# 🧾 Git / Infra
EXCLUDE_PRESETS[github]=".git .github .gitignore"

print_usage() {
  echo "Usage: folder_tree [options] [target_directory]"
  echo ""
  echo "Options:"
  echo "  --preset <types>       Comma-separated: node,nuxt,all,..."
  echo "  --config <file>        Load exclude patterns (default: ~/.treeignore)"
  echo "  --output markdown      Output Markdown-style list"
  echo "  --output broot         Output Broot-style list"
  echo "  --output git           Show Git-tracked files as Markdown list"
  echo "  --hidden               Show hidden files and folders (dotfiles)"
  echo "  --no-color             Disable colored output"
  echo "  --version              Print script version"
  echo "  --bump-version <type>  Bump version: patch | minor | major"
  echo "  --list-presets         Show all available preset types"
  echo "  --history              Append to FOLDER_TREE.md instead of overwriting"
  echo "  --verbose              Enable verbose output"
  echo "  --quiet                Suppress output"
  echo "  -h, --help             Show help"
  exit 0
}

log_info()    { [[ "$QUIET" == false ]] && echo -e "${color_info}${icon_info} $*${color_reset}"; }
log_ok()      { [[ "$QUIET" == false ]] && echo -e "${color_green}${icon_ok} $*${color_reset}"; }
log_warn()    { [[ "$QUIET" == false ]] && echo -e "${color_yellow}${icon_warn} $*${color_reset}"; }
log_err()     { echo -e "${color_red}${icon_err} $*${color_reset}" >&2; }
log_target()  { [[ "$QUIET" == false ]] && echo -e "${color_blue}${icon_target} $*${color_reset}"; }
log_excl()    { [[ "$QUIET" == false ]] && echo -e "${color_yellow}${icon_excl} $*${color_reset}"; }
log_preset()  { [[ "$QUIET" == false ]] && echo -e "${color_bold}${icon_preset} $*${color_reset}"; }
log_hidden()  { [[ "$QUIET" == false ]] && echo -e "${color_yellow}${icon_hidden} $*${color_reset}"; }

print_version() {
  echo -e "${icon_tree} folder_tree ${VERSION}"
  exit 0
}

list_presets() {
  echo "📦 Available --preset options:"
  for key in "${!EXCLUDE_PRESETS[@]}"; do
    echo "  - $key"
  done | sort
  exit 0
}

bump_version() {
  local TYPE="$1"
  local FILE
  FILE="$(realpath "${BASH_SOURCE[0]}")"
  local OLD_VERSION
  OLD_VERSION=$(grep '^VERSION=' "$FILE" | cut -d'"' -f2)

  IFS='.' read -r MAJOR MINOR PATCH <<< "$OLD_VERSION"
  case "$TYPE" in
    patch) PATCH=$((PATCH+1)) ;;
    minor) MINOR=$((MINOR+1)); PATCH=0 ;;
    major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
    *)
      log_err "Unknown bump type: $TYPE (use patch, minor, or major)"
      exit 1
      ;;
  esac

  local NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
  sed -i '' "s/^VERSION=\".*\"/VERSION=\"${NEW_VERSION}\"/" "$FILE"
  log_ok "Bumped version: $OLD_VERSION → $NEW_VERSION"
  exit 0
}

# Ensure tree is available
if ! command -v tree &>/dev/null; then
  log_err "'tree' not found. Install it with: brew install tree"
  exit 1
fi

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset)
      IFS=',' read -ra TYPES <<< "$2"
      for type in "${TYPES[@]}"; do
        if [[ "$type" == "all" ]]; then
          for val in "${EXCLUDE_PRESETS[@]}"; do EXCLUDES+=($val); done
          USED_PRESETS=("all")
          break
        elif [[ -n "${EXCLUDE_PRESETS[$type]+_}" ]]; then
          EXCLUDES+=(${EXCLUDE_PRESETS[$type]})
          USED_PRESETS+=("$type")
        else
          log_warn "Unknown preset: $type"
        fi
      done
      shift 2
      ;;
    --output)
      OUTPUT_MODE="$2"
      shift 2
      ;;
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --no-color)
      COLOR=false
      shift
      ;;
    --version)
      SHOW_VERSION=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    --bump-version)
      bump_version "$2"
      ;;
    --list-presets)
      list_presets
      ;;
    --history)
      HISTORY_MODE=true
      shift
      ;;
    --hidden)
      HIDDEN=true
      shift
      ;;
    --noreport)
      TREE_ARGS+=("--noreport")
      shift
      ;;
    --compute)
      TREE_ARGS+=("--du")  # note: `tree` uses --du, not --compute
      shift
      ;;
    -v|-t|-c|-U|-r)
      TREE_ARGS+=("$1")
      shift
      ;;        
    -h|--help)
      print_usage
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

# Resolve and validate target dir
if [[ ! -d "$TARGET_DIR" ]]; then
  log_err "Directory not found: $TARGET_DIR"
  exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
[[ -d "$TARGET_DIR/.git" ]] && EXCLUDES+=(".git")

# Load config file
if [[ -f "$CONFIG_FILE" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" && ! "$line" =~ ^# ]] && EXCLUDES+=("$line")
  done < "$CONFIG_FILE"
fi

# If hidden mode is enabled, allow "bin" folders (but keep other excludes)
if [[ "$HIDDEN" == true ]]; then
  log_info "Hidden mode enabled — allowing additional folders to be shown."
  # Define an array of folder names to allow ( "folder2" "folder3" )
  ALLOW_FOLDERS=("bin")
  log_hidden "Hidden mode override — allowed folders: ${ALLOW_FOLDERS[*]}"
  # Loop through each allowed folder and remove it from EXCLUDES
  for allow in "${ALLOW_FOLDERS[@]}"; do
    EXCLUDES=($(printf '%s\n' "${EXCLUDES[@]}" | grep -vFx "$allow"))
  done
fi

# Git-tracked output mode
if [[ "$OUTPUT_MODE" == "git" ]]; then
  if ! command -v git &>/dev/null; then
    log_err "Git not found."
    exit 1
  fi
  if [[ ! -d "$TARGET_DIR/.git" ]]; then
    log_err "'$TARGET_DIR' is not a Git repo."
    exit 1
  fi
  echo -e "${icon_git} Git-tracked files in: $(basename "$TARGET_DIR")"
  cd "$TARGET_DIR"
  git ls-tree -r --name-only HEAD | sed 's|[^/][^/]*|  - &|g'
  exit 0
fi

# broot mode
if [[ "$OUTPUT_MODE" == "broot" ]]; then
  if ! command -v broot &>/dev/null; then
    log_err "'broot' is not installed. Install it with: brew install broot"
    exit 1
  fi

  echo -e "${color_green}🚀 Launching broot in: $TARGET_DIR${color_reset}"
  broot "$TARGET_DIR"

  if [[ ! -f "$HINT_FILE" && ! "$(command -v br)" ]]; then
    echo -e "${color_info}${icon_info} Tip: To unlock full broot functionality (like 'cd' from inside), install the shell function:${color_reset}"
    echo -e "👉 Run: broot --install"
    echo -e "🔁 Then restart your terminal or run: exec \$SHELL"
    touch "$HINT_FILE"
  fi

  exit 0
fi

# Build tree args
TREE_ARGS+=(-F --dirsfirst --sort name)
[[ "$OUTPUT_MODE" != "markdown" && "$COLOR" == true ]] && TREE_ARGS+=(-C)
[[ "$HIDDEN" == true ]] && TREE_ARGS+=(-a)
for pattern in "${EXCLUDES[@]}"; do
  TREE_ARGS+=(-I "$pattern")
done

[[ "$SHOW_VERSION" == true ]] && print_version

# --- Strict mode OFF: allow errors/nulls/empty ---
disable_strict_mode

log_target "Target: $(basename "$TARGET_DIR")"
[[ "${#USED_PRESETS[@]}" -gt 0 ]] && log_preset "Presets: ${USED_PRESETS[*]}"
[[ -f "$CONFIG_FILE" ]] && log_excl "Excludes from: $(basename "$CONFIG_FILE")" || log_excl "Using built-in presets only"
[[ "$HIDDEN" == true ]] && log_hidden "Hidden files/folders will be shown."
[[ "$VERBOSE" == true ]] && log_info "TREE_ARGS: ${TREE_ARGS[*]}"

pushd "$TARGET_DIR" >/dev/null

TREE_OUTPUT="$(tree "${TREE_ARGS[@]}" . 2>/dev/null || true)"

# If not grouping, proceed as before (e.g. humanize sizes, print pretty, etc)
if [[ "${TREE_ARGS[*]}" =~ --du ]]; then
  TREE_OUTPUT="$(echo "$TREE_OUTPUT" | awk '
    function human(x) {
      units[0] = "B"; units[1] = "KB"; units[2] = "MB"; units[3] = "GB"; units[4] = "TB"
      i = 0
      while (x >= 1024 && i < 4) { x /= 1024; i++ }
      return sprintf("%.1f %s", x, units[i])
    }
    {
      while (match($0, /\[[[:space:]]*[0-9]+\]/)) {
        size_str = substr($0, RSTART+1, RLENGTH-2)
        gsub(/[[:space:]]/, "", size_str)
        size_n = size_str + 0
        hr = "[ " human(size_n) " ]"
        pad = length(substr($0, RSTART, RLENGTH)) - length(hr)
        if (pad > 0) hr = hr sprintf("%"pad"s", "")
        $0 = substr($0, 1, RSTART-1) hr substr($0, RSTART+RLENGTH)
      }
      print
    }
    /^[[:space:]]*[0-9]+ bytes used/ {
      total = $1 + 0
      sub(/^[[:space:]]*[0-9]+ bytes used/, "")
      printf("📦 Total: %s%s\n", human(total), $0)
      next
    }
  ')"
fi

popd >/dev/null

enable_strict_mode

# --- Clean tree output for empty check, don't break output file logic ---
CLEAN_TREE="$(echo "$TREE_OUTPUT" | grep -vE '^[[:space:]]*$' | grep -vE '^[0-9]+ directories?, [0-9]+ files$')"

if [[ "$OUTPUT_MODE" == "markdown" ]]; then
  BADGE1="[![Folder Tree](https://img.shields.io/badge/folder--tree-generated-blue?logo=tree&style=flat-square)](./FOLDER_TREE.md)"
  BADGE2="[![Folder Tree Version](https://img.shields.io/badge/folder--tree-v${VERSION}-purple?style=flat-square)](./FOLDER_TREE.md)"
  BADGE3="[![Bash Defender](https://img.shields.io/badge/bash--script-defensive--mode-blueviolet?logo=gnubash&logoColor=white&style=flat-square)](https://en.wikipedia.org/wiki/Defensive_programming)"


  # Markdown will *always* be written, even if empty/quiet
  TREE_MD="$(
    echo "## 📁 Folder Tree - $(date '+%Y-%m-%d %H:%M:%S') ##"
    echo ""
    echo "$BADGE1"
    echo "$BADGE2"
    echo "$BADGE3"
    echo ""
    if [[ -z "$CLEAN_TREE" ]]; then
      echo "**⚠️  Nothing to show. All contents excluded or directory is empty.**"
    else
      echo "$TREE_OUTPUT" | awk '
        BEGIN { indent = ""; }
        {
          gsub(/\u2502/, "|")
          gsub(/\u251c\u2500\u2500 /, "- ")
          gsub(/\u2514\u2500\u2500 /, "- ")
          gsub(/    /, "  ")
          print
        }
      '
    fi
    echo -e "\n---\n"
  )"
  # OUTPUT_FILE="$TARGET_DIR/FOLDER_TREE.md"
  # echo "$TREE_MD" > "$OUTPUT_FILE"

  OUTPUT_FILE="$(pwd)/FOLDER_TREE.md"
  echo "$TREE_MD" > "$OUTPUT_FILE"


  # Print summary unless --quiet
  if [[ "$QUIET" == false ]]; then
    if [[ -z "$CLEAN_TREE" ]]; then
      log_warn "Nothing to show. All contents excluded or directory is empty."
    fi
    # Relative path detection for nice output
    if command -v realpath &>/dev/null && realpath --help 2>&1 | grep -q -- '--relative-to'; then
      REL_PATH=$(realpath --relative-to="." "$OUTPUT_FILE")
    elif command -v python3 &>/dev/null; then
      REL_PATH=$(python3 -c "import os.path; print(os.path.relpath('$OUTPUT_FILE', '.'))")
    else
      REL_PATH="$OUTPUT_FILE"
    fi
    echo -e "${color_green}${icon_ok} Markdown output written to (overwrite): $REL_PATH${color_reset}"
  fi
  exit 0
fi

if [[ -z "$CLEAN_TREE" ]]; then
  log_warn "Nothing to show. All contents excluded or directory is empty."
  exit 0
else
  echo "$TREE_OUTPUT"
fi

