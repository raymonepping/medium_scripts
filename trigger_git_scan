#!/usr/bin/env bash
set -euo pipefail

BRANCH="initial-pr-scan"
CLEANUP=false
MAIN_FILE_CREATED=false

# 🧼 Check for optional --cleanup flag
if [[ "${1:-}" == "--cleanup" ]]; then
  CLEANUP=true
fi

# 🧭 Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "🔍 Current branch: $CURRENT_BRANCH"

# ❌ Check for existing local branch
if git rev-parse --verify "$BRANCH" &>/dev/null; then
  if [[ "$CLEANUP" == true ]]; then
    echo "🧹 Deleting existing local branch '$BRANCH' before recreating..."
    git branch -D "$BRANCH"
  else
    echo "⚠️ Branch '$BRANCH' already exists. Aborting."
    echo "👉 You can delete it manually with: git branch -D $BRANCH"
    exit 1
  fi
fi

# 🔀 Create and switch to PR scan branch
echo "🔀 Creating and switching to branch: $BRANCH"
git checkout -b "$BRANCH"

# 🧱 Ensure a valid main.tf if missing
if [[ ! -f "main.tf" ]]; then
  echo "🌱 Creating minimal main.tf with required_version"
  cat > main.tf <<EOF
terraform {
  required_version = ">= 1.0.0"
}
EOF
  MAIN_FILE_CREATED=true
fi

# 📂 Determine scan trigger file based on project type
if [[ -f "main.tf" || -n "$(find . -name '*.tf' | head -n 1)" ]]; then
  TRIGGER_FILE="trigger_scan.tf"
  cat > "$TRIGGER_FILE" <<EOF
# Dummy output to trigger PR scan
output "trigger_scan" {
  value = "Triggered at $(date)"
}
EOF
else
  TRIGGER_FILE="trigger_scan.txt"
  echo "trigger: $(date)" > "$TRIGGER_FILE"
fi

# 📝 Stage and commit changes
git add "$TRIGGER_FILE"
$MAIN_FILE_CREATED && git add main.tf
git commit -m "test: trigger scan_on_pr workflow"

# 🚀 Push (force if remote branch already exists)
if git ls-remote --exit-code --heads origin "$BRANCH" &>/dev/null; then
  echo "🔁 Remote branch '$BRANCH' exists — using force push"
  git push --force -u origin "$BRANCH"
else
  git push -u origin "$BRANCH"
fi

# 🔁 Create pull request
echo "🚀 Creating pull request..."
gh pr create --base main --head "$BRANCH" --title "Trigger PR scan" --body "Triggering scan_on_pr workflow via dummy change." || \
  echo "ℹ️ A pull request may already exist."

# 🔗 Show PR link
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
PR_NUMBER=$(gh pr list --head "$BRANCH" --json number -q '.[0].number')
echo "🔗 PR Link: https://github.com/${REPO}/pull/${PR_NUMBER}"

# 🔙 Return to main
git checkout "$CURRENT_BRANCH"
echo "✅ Returned to branch: $CURRENT_BRANCH"

# 🧹 Cleanup if requested
if [[ "$CLEANUP" == true ]]; then
  echo "🧼 Cleaning up trigger file and branch..."
  git branch -D "$BRANCH" || true
  rm -f "$TRIGGER_FILE"
  $MAIN_FILE_CREATED && rm -f main.tf
fi

echo "✅ PR scan trigger complete!"
