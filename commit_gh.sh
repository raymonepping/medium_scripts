#!/bin/bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.4"

QUIET=0
if [[ "${1:-}" == "--quiet" || "${1:-}" == "-q" ]]; then
  QUIET=1
  shift
fi

msg() { [[ $QUIET -eq 0 ]] && echo "$*"; }
always_msg() { echo "$*"; }

cd "$(git rev-parse --show-toplevel)" || exit 1

# --- Detect in-progress rebase or merge and exit if found ---
if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
  echo -e "❌ \033[1;31mGit rebase is in progress.\033[0m"
  echo "   Please resolve conflicts and run 'git rebase --continue' before using this script."
  exit 1
fi

if [ -f ".git/MERGE_HEAD" ]; then
  echo -e "❌ \033[1;31mGit merge is in progress.\033[0m"
  echo "   Please resolve conflicts and run 'git merge --continue' (or abort) before using this script."
  exit 1
fi

DD=$(date +'%d')
MM=$(date +'%m')
YYYY=$(date +'%Y')
COMMIT_MESSAGE="$DD/$MM/$YYYY - Updated configuration and fixed bugs"

# Ensure ssh-agent is running
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add -A >/dev/null 2>&1 || true
fi

# Remove tracked FOLDER_TREE.md if ignored
if git ls-files --error-unmatch FOLDER_TREE.md &>/dev/null; then
  if grep -qF "FOLDER_TREE.md" .gitignore; then
    msg "🧹 Removing FOLDER_TREE.md from Git tracking..."
    git rm --cached FOLDER_TREE.md >/dev/null
  fi
fi

git add . >/dev/null

# --- Commit staged changes if any ---
DID_COMMIT=0
if ! git diff --cached --quiet; then
  msg "📦 Committing staged changes before pull/rebase..."
  git commit -m "$COMMIT_MESSAGE" >/dev/null
  DID_COMMIT=1
fi

# --- Stash unstaged changes if any, then rebase ---
if ! git diff --quiet; then
  msg "💾 Stashing unstaged local changes before rebase..."
  git stash -u >/dev/null
  if ! git pull --rebase origin main >/dev/null 2>&1; then
    echo "❌ Pull/rebase failed! Please resolve manually."
    exit 1
  fi
  git stash pop >/dev/null 2>&1 || true
else
  git pull --rebase origin main >/dev/null 2>&1
fi

git add . >/dev/null
if ! git diff --cached --quiet; then
  msg "📦 Committing new staged changes..."
  git commit -m "$COMMIT_MESSAGE" >/dev/null
  DID_COMMIT=1
fi

# --- Smart Push Logic ---
DID_PUSH=0
try_push() {
  local max_attempts=2
  local attempt=1
  while [[ $attempt -le $max_attempts ]]; do
    # Only push if there are commits ahead
    if [[ $(git log origin/main..HEAD --oneline | wc -l) -gt 0 ]]; then
      if git push origin main >/dev/null 2>&1; then
        DID_PUSH=1
        msg "🚀 Successfully pushed to origin/main."
        return 0
      else
        msg "⚠️  Push failed (maybe due to remote updates). Trying pull --rebase and re-push..."
        if ! git pull --rebase origin main >/dev/null 2>&1; then
          echo "❌ Pull/rebase failed! Please resolve manually."
          exit 1
        fi
        ((attempt++))
      fi
    else
      # Nothing to push
      return 0
    fi
  done
  echo "❌ Push failed after rebase. Please resolve conflicts manually."
  exit 1
}
try_push

# --- Output up-to-date message if nothing to commit or push ---
if [[ $DID_COMMIT -eq 0 && $DID_PUSH -eq 0 ]]; then
  branch=$(git rev-parse --abbrev-ref HEAD)
  always_msg "✅ Current branch $branch is up to date."
  always_msg "🟢 No changes to commit."
fi

if [[ -f .github/dependabot.yml ]]; then
  msg "🔐 Dependabot is enabled. Base image CVEs will be monitored automatically by GitHub."
fi

if command -v folder_tree &>/dev/null; then
  msg "🌳 Generating updated folder tree..."
  folder_tree --preset terraform,github --output markdown >/dev/null
else
  msg "⚠️  'folder_tree' command not found — skipping tree update."
fi
