#!/usr/bin/env bash
set -euo pipefail

VERSION="1.5.4"

# Default presets
TARGET_DIR="."
EXCLUDES=()
USED_PRESETS=()
OUTPUT_MODE="tree"
CONFIG_FILE="$HOME/.treeignore"
COLOR=true
HISTORY_MODE=false
SHOW_VERSION=false
VERBOSE=false
QUIET=false
HINT_FILE="$HOME/.broot_hint_seen"

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
  echo "  --output broot         Launch broot from target directory"
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

log() {
  [[ "$QUIET" == false ]] && echo "$@"
}

print_version() {
  echo "folder_tree ${VERSION}"
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
      echo "❌ Unknown bump type: $TYPE (use patch, minor, or major)"
      exit 1
      ;;
  esac

  local NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
  sed -i '' "s/^VERSION=\".*\"/VERSION=\"${NEW_VERSION}\"/" "$FILE"
  echo "✅ Bumped version: $OLD_VERSION → $NEW_VERSION"
  exit 0
}

# Ensure tree is available
if ! command -v tree &>/dev/null; then
  echo "❌ 'tree' not found. Install it with: brew install tree"
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
          echo "⚠️ Unknown preset: $type"
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
  echo "❌ Directory not found: $TARGET_DIR"
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

# Git-tracked output mode
if [[ "$OUTPUT_MODE" == "git" ]]; then
  if ! command -v git &>/dev/null; then
    echo "❌ Git not found."
    exit 1
  fi
  if [[ ! -d "$TARGET_DIR/.git" ]]; then
    echo "❌ '$TARGET_DIR' is not a Git repo."
    exit 1
  fi
  echo "📂 Git-tracked files in: $(basename "$TARGET_DIR")"
  cd "$TARGET_DIR"
  git ls-tree -r --name-only HEAD | sed 's|[^/][^/]*|  - &|g'
  exit 0
fi

# broot mode
if [[ "$OUTPUT_MODE" == "broot" ]]; then
  if ! command -v broot &>/dev/null; then
    echo "❌ 'broot' is not installed. Install it with: brew install broot"
    exit 1
  fi

  echo "🚀 Launching broot in: $TARGET_DIR"
  broot "$TARGET_DIR"

  if [[ ! -f "$HINT_FILE" && ! "$(command -v br)" ]]; then
    echo -e "ℹ️  Tip: To unlock full broot functionality (like 'cd' from inside), install the shell function:"
    echo -e "👉 Run: broot --install"
    echo -e "🔁 Then restart your terminal or run: exec \$SHELL"
    touch "$HINT_FILE"
  fi

  exit 0
fi

# Build tree args
TREE_ARGS=(-F --dirsfirst)
[[ "$OUTPUT_MODE" != "markdown" && "$COLOR" == true ]] && TREE_ARGS+=(-C)
for pattern in "${EXCLUDES[@]}"; do
  TREE_ARGS+=(-I "$pattern")
done

[[ "$SHOW_VERSION" == true ]] && echo "🌳 folder_tree ${VERSION}"

log "📂 Target: $(basename "$TARGET_DIR")"
[[ "${#USED_PRESETS[@]}" -gt 0 ]] && log "📦 Presets: ${USED_PRESETS[*]}"
[[ -f "$CONFIG_FILE" ]] && log "🛡️ Excludes from: $(basename "$CONFIG_FILE")" || log "🛡️ Using built-in presets only"
[[ "$VERBOSE" == true ]] && log "🔍 TREE_ARGS: ${TREE_ARGS[*]}"

pushd "$TARGET_DIR" >/dev/null
TREE_OUTPUT="$(tree "${TREE_ARGS[@]}" . 2>/dev/null || true)"
popd >/dev/null

if [[ "$OUTPUT_MODE" == "markdown" ]]; then
  if [[ "$QUIET" == false ]]; then
    echo "🌳 Generating updated folder tree..."
  fi
  BADGE1="[![Folder Tree](https://img.shields.io/badge/folder--tree-generated-blue?logo=tree&style=flat-square)](./FOLDER_TREE.md)"
  BADGE2="[![Folder Tree Version](https://img.shields.io/badge/folder--tree-v${VERSION}-purple?style=flat-square)](./FOLDER_TREE.md)"

  TREE_MD="$(
    echo "## 📁 Folder Tree - $(date '+%Y-%m-%d %H:%M:%S') ##"
    echo ""
    echo "$BADGE1"
    echo "$BADGE2"
    echo ""
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
    echo -e "\n---\n"
  )"
  OUTPUT_FILE="$TARGET_DIR/FOLDER_TREE.md"
  echo "$TREE_MD" > "$OUTPUT_FILE"

  # Safe relative path for output
  if [[ "$QUIET" == false ]]; then
    if command -v realpath &>/dev/null && realpath --help 2>&1 | grep -q -- '--relative-to'; then
      REL_PATH=$(realpath --relative-to="." "$OUTPUT_FILE")
    elif command -v python3 &>/dev/null; then
      REL_PATH=$(python3 -c "import os.path; print(os.path.relpath('$OUTPUT_FILE', '.'))")
    else
      REL_PATH="$OUTPUT_FILE"
    fi
    echo "📜 Markdown output written to (overwrite): $REL_PATH"
  fi
  [[ -z "$TREE_OUTPUT" && "$QUIET" == false ]] && echo "⚠️  Nothing to show. All contents excluded or directory is empty."
  exit 0
fi

if [[ -z "$TREE_OUTPUT" ]]; then
  [[ "$QUIET" == false ]] && echo "⚠️  Nothing to show. All contents excluded or directory is empty."
  exit 0
else
  echo "$TREE_OUTPUT"
fi
