## 🚀 Included Scripts
# 🧩 medium_scripts

A curated toolbox of Bash automation scripts designed to simplify, standardize, and secure your development workflows.

> Created and maintained by [@raymonepping](https://github.com/raymonepping)  
> ✨ Featured in multiple [Medium articles](https://medium.com/@raymonepping)

---

## 📜 Scripts Included

| Script                        | Description                                                                   |
|-------------------------------|-------------------------------------------------------------------------------|
| `bump_version.sh`             | Semantic version bumper with changelog support (`--major`, `--minor`, etc.)   |
| `commit_gh.sh`                | Smart Git commit/push helper with rebase safety, tree regen, Dependabot       |
| `folder_tree.sh`              | Folder structure visualizer using `broot` or `tree`                           |
| `generate_documentation.sh`   | Auto-generates Markdown docs for your Bash scripts (`--summary`, `--depth`)   |
| `sanity_check.sh`             | Linter/formatter for `.sh`, `.py`, `.js`, and `.tf` (with Markdown report)    |
| `top10_validator.sh`          | Validates scripts against the Bash Top 10 best practices                      |
| `trigger_git_scan.sh`         | Adds GitHub Actions status badges to your `README.md` automatically           |

---

## ⚡ Quickstart: Plug-and-Play in Your Repo

1. **Add Scripts**  
   Copy `*.sh` files into your project root or `/scripts`.

2. **Add Workflows**  
   Place GitHub Actions YAMLs in `.github/workflows` (see below).

3. **Set Permissions**  
   ```bash
   chmod +x *.sh
Run Locally or in CI
Use the CLI or automate via CI for PRs or merges.

📦 Sample GitHub Workflow
yaml

# .github/workflows/sanity-check.yml
name: Sanity Check

on:
  pull_request:
    paths:
      - '**.sh'

jobs:
  bash-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./sanity_check.sh --all .
🧪 Script Badges (optional)
You can add version and status badges for each tool like:

markdown
Kopiëren
Bewerken
![Version](https://img.shields.io/badge/commit_gh-v1.0.4-blue)
![Sanity](https://img.shields.io/badge/sanity_check-passed-brightgreen)
📖 Learn More
Each script is documented inline via --help.
You can also explore the detailed Medium articles for deep dives:

🔗 The Bash Top 10 Chronicles

🔗 Streamlining Project Creation with Packer and Automation

🧰 Requirements
Most scripts assume:

bash

awk, sed, shfmt, shellcheck

Optional: prettier, black, eslint, pylint, etc.

Use sanity_check.sh --report to validate your tooling setup.

🔐 Security & Hygiene by Default
All scripts follow:

set -euo pipefail for safety

Strict quoting and variable checks

ShellCheck-verified structure

Optional commit hygiene via commit_gh.sh

🧠 Idea? Bug? Improvement?
Open an issue or PR. We believe in continuous improvement — and beautiful automation.

© 2025 Raymon Epping