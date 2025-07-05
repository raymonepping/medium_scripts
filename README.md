# 🛠️ medium_scripts

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

🛠️ Sample Usage

./bump_version.sh ./sanity_check.sh --minor
./commit_gh.sh --quiet --tree true
./generate_documentation.sh --summary --depth 2 ./sanity_check.sh
./sanity_check.sh --all ./top10_validator.sh
./top10_validator.sh ./commit_gh.sh
./folder_tree.sh --output broot
./trigger_git_scan.sh --badges

📦 Integrate in CI
Sample GitHub Actions workflow:

yaml

# .github/workflows/sanity-check.yml
name: Sanity Check

on: [pull_request]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./sanity_check.sh --all .
🧪 Tooling Required

These scripts rely on:
bash, awk, sed, grep

shellcheck, shfmt, prettier, black, pylint, eslint, etc.

Optional: broot (for folder trees)

Use:

bash
./sanity_check.sh --report
...to check tool availability.

🧠 Learn More

📚 Related Medium articles:
- 🧩 The Bash Top 10 Chronicles
- 🚀 Real-Time Bash Automation & Living Docs
- 🔧 Automating Project Setup with Packer

🧰 Optional: Version Badges

![Commit GH](https://img.shields.io/badge/commit_gh-v1.0.4-blue)
![Sanity Check](https://img.shields.io/badge/sanity_check-pass-brightgreen)
![Top10](https://img.shields.io/badge/top10_validator-2.1.4-yellow)

🧠 Idea? Bug? Improvement?
Open an issue or PR. We believe in continuous improvement — and beautiful automation.

© 2025 Raymon Epping