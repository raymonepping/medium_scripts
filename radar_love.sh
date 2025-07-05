#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="0.0.3"
echo "$VERSION"

# --- COLOR & FORMAT DEFINITIONS ---
color_reset=$'\e[0m'
color_red=$'\e[31m'
color_green=$'\e[32m'
color_yellow=$'\e[33m'
color_blue=$'\e[34m'
color_cyan=$'\e[36m'
color_bold=$'\e[1m'
color_status=$'\e[37m'

shake_on=$'\e[5m'
shake_off=$'\e[25m'

# --- EMOJI ---
icon_ok="☁️"
icon_err="❌"
icon_warn="⚠️"
icon_folder="📁"
icon_branch="🌱"
icon_push="🚀"
icon_copy="📋"
icon_git="🔧"
icon_lock="🔒"
icon_pr="🔀"
icon_step="➡️"
icon_done="🏁"

# --- CONFIGURATION ---
REPO_NAME="medium_live_forever"
GH_USER="$(gh api user --jq .login)"
DIR="$(pwd)"
PROJECT_FOLDER="$DIR/$REPO_NAME"
CREATE=true
BUILD=false
FRESH=false
LANGUAGE="bash"
SCENARIO="AWS"
COMMIT=false
REQUEST=false

check_github_auth() {
  if ! gh auth status &>/dev/null; then
    fail "GitHub CLI is not authenticated. Please run 'gh auth login' before continuing."
  else
    ok "GitHub CLI authentication verified."
  fi
}

# --- Input file locations ---
SCRIPTS_FOLDER="$HOME/Documents/VSC/MacOS_Environment/medium_scripts/radar_demo"
FILE_BUILDER="vault_radar_builder.sh"
FILE_INPUT="vault_radar_input.json"
FILE_HEADER="header.tpl"
FILE_FOOTER="footer.tpl"
GITIGNORE_SOURCES=("$SCRIPTS_FOLDER/.gitignore" "$HOME/.gitignore_global")

# --- Logging / Output ---
log() { echo "${color_status}${icon_step} $*${color_reset}"; }
ok() { echo "${color_bold}${color_green}${icon_ok} $*${color_reset}"; }
warn() { echo "${color_bold}${color_yellow}${icon_warn} $*${color_reset}"; }
fail() {
  echo "${color_bold}${color_red}${shake_on}${icon_err} $*${shake_off}${color_reset}"
  exit 1
}
banner() { echo -e "\n${color_cyan}${color_bold}==== $* ====${color_reset}"; }

# --- Progress Bar ---
progress() {
  local pct="$1"
  local bar=""
  local n=$((pct / 10))
  for i in $(seq 1 10); do
    if [ "$i" -le "$n" ]; then bar="${bar}#"; else bar="${bar}-"; fi
  done
  printf "${color_green}[%-10s] %3d%%%s\r" "$bar" "$pct" "$color_reset"
  if [ "$pct" -eq 100 ]; then echo; fi
}

# --- Early --help/--version ---
for arg in "$@"; do
  case "$arg" in
  --help)
    cat <<EOF
Usage: $0 [--create true|false] [--build true|false] [--fresh true|false] [--language <lang>] [--scenario <scenario>]
           [--commit true|false] [--request true|false]
  All file locations (scripts folder, .json, builder) are set at the top of the script.
  Example: ./radar_love.sh --build true --request true

Flags:
  --create true|false    Create (or connect) GitHub repo (default: true)
  --build true|false     Generate demo leak branch/files (default: false)
  --fresh true|false     Remove and recreate the repo/folder if it exists (default: false)
  --language <lang>      Builder language for demo (default: bash)
  --scenario <scenario>  Builder scenario for demo (default: AWS)
  --commit true|false    Run commit_gh.sh if present (default: false)
  --request true|false   Trigger PR scan (default: false)
  --help                 Show this help and exit
  --version              Show version and exit

Set REPO_NAME at the top if you want to change the demo repo/folder name.
EOF
    exit 0
    ;;
  --version)
    echo "$(basename "$0") version: $VERSION"
    exit 0
    ;;
  esac
done

# --- Parse Flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
  --create)
    CREATE="$2"
    shift 2
    ;;
  --build)
    BUILD="$2"
    shift 2
    ;;
  --fresh)
    FRESH="$2"
    shift 2
    ;;
  --language)
    LANGUAGE="$2"
    shift 2
    ;;
  --scenario)
    SCENARIO="$2"
    shift 2
    ;;
  --commit)
    COMMIT="$2"
    shift 2
    ;;
  --request)
    REQUEST="$2"
    shift 2
    ;;
  *) fail "Unknown option: $1" ;;
  esac
done

# --- Clean Existing Project Folder If Needed ---
if [[ "$FRESH" == "true" && -d "$PROJECT_FOLDER" ]]; then
  warn "✗ The folder '$PROJECT_FOLDER' already exists."
  rm -rf "$PROJECT_FOLDER"
  ok "Removed $PROJECT_FOLDER. Starting fresh."
fi

# --- Ensure Project Folder Exists ---
mkdir -p "$PROJECT_FOLDER"

# --- Copy .gitignore ---
copy_gitignore() {
  for src in "${GITIGNORE_SOURCES[@]}"; do
    if [[ -f "$src" ]]; then
      cp "$src" "$PROJECT_FOLDER/.gitignore"
      ok "Copied .gitignore from $src"
      return
    fi
  done
  echo "# Auto-generated .gitignore for Radar Love" >"$PROJECT_FOLDER/.gitignore"
  warn "No .gitignore template found, created a default."
}

# --- Copy Input Files ---
copy_inputs() {
  banner "${icon_copy} Copying input files..."
  for file in "$FILE_BUILDER" "$FILE_INPUT" "$FILE_HEADER" "$FILE_FOOTER"; do
    local src="$SCRIPTS_FOLDER/$file"
    local dst="$PROJECT_FOLDER/$file"
    [[ -f "$src" ]] || fail "Source file not found: $src"
    log "${icon_copy} Copying $file"
    cp "$src" "$dst"
    [[ "$file" == "$FILE_BUILDER" ]] && chmod +x "$dst"
    ok "Copied $file"
  done
}

generate_readme_from_template() {
  local template="$SCRIPTS_FOLDER/README.tpl"
  local output="$PROJECT_FOLDER/README.md"

  if [[ ! -f "$template" ]]; then
    warn "README.tpl not found, skipping README generation."
    return
  fi

  awk -v repo="$REPO_NAME" -v dt="$(date '+%Y-%m-%d')" '
    {
      gsub("{{REPO_NAME}}", repo);
      gsub("{{DATE}}", dt);
      print;
    }
  ' "$template" >"$output"

  ok "Generated README.md from template: $template"
}

copy_docs_and_license() {
  for file in README.md LICENSE; do
    local src="$SCRIPTS_FOLDER/$file"
    local dst="$PROJECT_FOLDER/$file"
    if [[ -f "$src" ]]; then
      cp "$src" "$dst"
      ok "Copied $file from $src"
    else
      if [[ "$file" == "README.md" ]]; then
        generate_readme_from_template
      elif [[ "$file" == "LICENSE" ]]; then
        echo "MIT License" >"$dst"
        warn "No LICENSE found; created placeholder."
      fi
    fi
  done
}

# --- Pre-commit hook for sanity_check ---
setup_precommit_hook() {
  local HOOK_PATH="$PROJECT_FOLDER/.git/hooks/pre-commit"
  if command -v sanity_check &>/dev/null; then
    cat >"$HOOK_PATH" <<'EOF'
#!/bin/bash
set -euo pipefail
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.sh$|\.py$|\.js$|\.tf$|Dockerfile$' || true)
if [[ -n "$STAGED_FILES" ]]; then
  echo "🔍 Pre-commit: running sanity_check on staged files..."
  echo "$STAGED_FILES" | xargs sanity_check --fix --quiet
fi
EOF
    chmod +x "$HOOK_PATH"
    ok "Pre-commit hook for sanity_check installed."
  else
    warn "sanity_check not available, skipping pre-commit hook setup."
  fi
}

maybe_init_git() {
  banner "${icon_git} Checking git repository..."
  cd "$PROJECT_FOLDER"
  if [[ ! -d .git ]]; then
    log "No git repo found—initializing."
    git init
    git branch -M main 2>/dev/null || true
    git add .
    git commit -m "Initial commit"
    ok "Git repo initialized and first commit done."
  elif [[ -z "$(git rev-parse --show-cdup 2>/dev/null)" && -z "$(git log --oneline)" ]]; then
    log "Git repo found but no commits. Making initial commit."
    git add .
    git commit -m "Initial commit"
    ok "First commit done."
  else
    ok "Git repo already initialized."
  fi
  setup_precommit_hook
  cd - >/dev/null
}

create_repo() {
  banner "${icon_folder} Creating GitHub repo..."
  cd "$PROJECT_FOLDER"
  maybe_init_git
  log "Creating repo: $GH_USER/$REPO_NAME"
  gh repo create "$GH_USER/$REPO_NAME" --public --source "$PROJECT_FOLDER" --remote=origin --push || warn "Repo may already exist, continuing."
  git branch -M main
  git push -u origin main
  ok "Repo created and pushed: https://github.com/$GH_USER/$REPO_NAME"
  remove_branch_protection
  cd - >/dev/null
}

remove_branch_protection() {
  banner "${icon_lock} Removing branch protection (if any)..."
  gh api --method DELETE "repos/$GH_USER/$REPO_NAME/branches/main/protection" >/dev/null 2>&1 || true
  ok "Branch protection (if any) removed (silent)."
}

build_leaky_branch() {
  local branch="feature/leaky-demo"
  banner "${icon_branch} Building leaky demo branch..."
  cd "$PROJECT_FOLDER"
  git checkout -B "$branch"
  if [[ -f "./$FILE_BUILDER" ]]; then
    ./"$FILE_BUILDER" \
      --language "$LANGUAGE" \
      --scenario "$SCENARIO" \
      --header-template "$FILE_HEADER" \
      --footer-template "$FILE_FOOTER"
    git add radar_demo/Vault_Radar_trigger.*
    git commit -m "Add Vault Radar demo leak file"
    ok "Added demo leaks with $FILE_BUILDER"
  else
    mkdir -p radar_demo
    echo "AWS_ACCESS_KEY_ID=AKIA7SDF3R28QXLN4WTY" >radar_demo/leak.env
    echo "AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYkq8RxCjJ" >>radar_demo/leak.env
    git add radar_demo/leak.env
    git commit -m "Add static leaky secret for demo"
    warn "$FILE_BUILDER not found, added static secret"
  fi
  git push -u origin "$branch"
  ok "Leaky branch pushed: $branch"
  cd - >/dev/null
}

# --- Version bump (multi-lang aware) ---
run_bump_version() {
  cd "$PROJECT_FOLDER"
  # Check for all generated radar_demo trigger files (.sh, .py, etc)
  for file in radar_demo/Vault_Radar_trigger.*; do
    [[ -f "$file" ]] || continue
    if command -v bump_version &>/dev/null; then
      banner "${icon_step} Running version bump on $file"
      bump_version "$file" && ok "Version bump done: $file"
    else
      warn "Skipping version bump; bump_version not found."
    fi
  done
  cd - >/dev/null
}

run_sanity_check() {
  cd "$PROJECT_FOLDER"
  for file in radar_demo/Vault_Radar_trigger.*; do
    [[ -f "$file" ]] || continue
    if command -v sanity_check &>/dev/null; then
      banner "${icon_step} Running sanity_check on $file"
      sanity_check "$file" --fix --report
      ok "sanity_check completed: $file"
    else
      warn "sanity_check not found; skipping sanity check."
    fi
  done
  cd - >/dev/null
}

# ...after run_bump_version and run_sanity_check...

auto_commit_generated_files() {
  cd "$PROJECT_FOLDER"
  # Add all outputs that are modified or created
  git add radar_demo/Vault_Radar_trigger.* radar_demo/CHANGELOG_Vault_Radar_trigger.md radar_demo/Vault_Radar_cleanup.sh sanity_check.md 2>/dev/null || true
  # Only commit if there are staged changes
  if ! git diff --cached --quiet; then
    git commit -m "chore: update trigger file(s), changelog, and sanity report"
    ok "Auto-committed latest outputs."
    git push
  fi
  cd - >/dev/null
}

commit_gh_if_needed() {
  banner "${icon_git} Running commit_gh after build and checks..."
  cd "$PROJECT_FOLDER"
  if command -v commit_gh &>/dev/null; then
    commit_gh --tree false
    ok "commit_gh executed"
  else
    warn "commit_gh not found; skipping."
  fi
  cd - >/dev/null
}

trigger_pr_and_scan() {
  cd "$PROJECT_FOLDER" || fail "Project folder not found!"
  banner "${icon_pr} Triggering PR scan..."

  if command -v trigger_git_scan &>/dev/null; then
    trigger_git_scan --cleanup
    ok "trigger_git_scan (global) executed"
  elif [[ -f "./trigger_git_scan.sh" ]]; then
    ./trigger_git_scan.sh --cleanup
    ok "trigger_git_scan.sh (local) executed"
  else
    warn "trigger_git_scan not found; skipping PR scan trigger."
  fi

  cd - >/dev/null
}

# --- MAIN ---
banner "${icon_push}${icon_ok}${icon_branch} $REPO_NAME: Cloudy Modular Secret Demo Pipeline!"

progress 5
check_github_auth

progress 9
copy_gitignore
progress 10
copy_inputs
progress 11
copy_docs_and_license

progress 20
$CREATE && create_repo

progress 60
$BUILD && build_leaky_branch
progress 70
$BUILD && run_bump_version
progress 80
$BUILD && run_sanity_check
progress 85
$BUILD && auto_commit_generated_files

progress 90
$COMMIT && commit_gh_if_needed

progress 100
$REQUEST && trigger_pr_and_scan

sleep 2
progress 100

echo -e "${color_green}${color_bold}${icon_done} All steps complete. Your ☁️ demo repo is ready to challenge every scanner!${color_reset}"

# Optional: Show a link to the repo and PR scan (if desired)
if [[ "$REQUEST" == "true" ]]; then
  echo -e "\n${color_blue}🔗 View your repo: https://github.com/$GH_USER/$REPO_NAME ${color_reset}"
  echo -e "${color_cyan}Check your PRs for scan results!${color_reset}"
fi

# Oasis-style repo status check
cd "$PROJECT_FOLDER"
echo ""
git status --short | grep . &&
  echo -e "${color_red}❌ I need some time in the sunshine!${color_reset}" ||
  echo -e "${color_green}🎶 In my mind my dreams are real 🎸.${color_reset}"
cd - >/dev/null
