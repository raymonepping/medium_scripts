# 🛠️ medium_scripts

A battle-tested collection of Bash scripts to automate, validate, and optimize your development workflow.

---

## 🚀 Included Scripts

| Script | Purpose |
|--------|---------|
| `commit_gh.sh` | Smart Git commit and push automation with tree regen and Dependabot awareness |
| `sanity_check.sh` | Multi-tool validator with linting, formatting, and report generation |
| `bump_version.sh` | Semantic versioning bump for any script, with changelog tracking |
| `generate_documentation.sh` | Markdown doc generator for scripts with optional lint output |
| `folder_tree.sh` | Visual folder tree generator (uses `broot`, optional) |
| `top10_validator.sh` | Bash Top 10 best practice enforcer, scoring your scripts |

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
Kopiëren
Bewerken
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