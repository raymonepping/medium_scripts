# radar_love.sh - 2025-07-05 17:26:36

⚠️ No version detected — please run `bump_version` against this script.

[![Version](https://img.shields.io/badge/version-0.0.0-purple.svg)](./radar_love.sh)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/radar_love.md)
[![Size](https://img.shields.io/badge/size-13KB-yellow)](./radar_love.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--05-blue)](./radar_love.sh)
[![Bash](https://img.shields.io/badge/bash-5--2--21-red)](https://www.gnu.org/software/bash/)

## Table of Contents
- High-level summary - radar_love.sh
- Variables Set - radar_love.sh

## High-level summary - radar_love.sh


## Variables Set - radar_love.sh
- BUILD
- COMMIT
- CREATE
- DIR
- FILE_BUILDER
- FILE_FOOTER
- FILE_HEADER
- FILE_INPUT
- FRESH
- GH_USER
- GITIGNORE_SOURCES
- LANGUAGE
- PROJECT_FOLDER
- REPO_NAME
- REQUEST
- SCENARIO
- SCRIPTS_FOLDER
- STAGED_FILES

- High-level summary - commit_gh.sh
- Variables Set - commit_gh.sh

## High-level summary - commit_gh.sh
- Detect in-progress rebase or merge and exit if found
- Commit staged changes if any
- Stash unstaged changes if any, then rebase
- Smart Push Logic
- Output up-to-date message if nothing to commit or push

## Variables Set - commit_gh.sh
- COMMIT_MESSAGE
- DD
- DID_COMMIT
- DID_PUSH
- GENERATE_TREE
- MM
- QUIET
- VERSION
- YYYY

- High-level summary - trigger_git_scan.sh
- Variables Set - trigger_git_scan.sh

## High-level summary - trigger_git_scan.sh


## Variables Set - trigger_git_scan.sh
- BRANCH
- CLEANUP
- CURRENT_BRANCH
- MAIN_FILE_CREATED
- PR_NUMBER
- REPO
- TRIGGER_FILE

- High-level summary - vault_radar_builder.sh
- Variables Set - vault_radar_builder.sh

## High-level summary - vault_radar_builder.sh
- Defaults
- Parse CLI
- Input Validation
- Read Leaks, Filter by Scenario
- Parse Languages
- Pick random count within range
- Shebang + VERSION injector (only for bash/python/node/etc)
- Template substitution (no sed!)
- Output Files Map
- Leak Injection Helpers
- Main Output Loop
- Deduplicate and collect generated languages
- Add Markdown Table Header
- Add Footers
- Write Cleanup Script
- Run Lint/Sanity Check if Requested
- Output Results

## Variables Set - vault_radar_builder.sh
- AUTHOR
- CLEANUP_SCRIPT
- COUNT
- DRYRUN
- FOOTER_TEMPLATE
- HEADER_TEMPLATE
- IFS
- INPUT
- LANGS
- LANGS_TO_GEN
- LEAKS
- LEAKS_TO_USE
- LINT
- LOGFILE
- MAX
- MDH
- MIN
- NR
- OUTDIR
- QUIET
- RUNID
- SCENARIO
- TIMESTAMP
- TMP_GEN_FILE
- VERSION

- High-level summary - sanity_check.sh
- Variables Set - sanity_check.sh

## High-level summary - sanity_check.sh
- 🛠️ Print version of a tool, or warn if not installed
- 🛠️ Default settings
- 🎛️ Parse arguments
- 🚀 Process each file
- 🔇 Quiet mode result output
- 📊 Summary output
- ✅ Final status
- 🧾 Markdown report (auto-generated on --report OR missing tools/issues)

## Variables Set - sanity_check.sh
- BASENAME
- EXT
- FILES
- FORMATTER
- LINTER
- MISSING_TOOL_WARNINGS
- MODE
- PROBLEM_FILES
- QUIET
- REPORT
- REPORT_FILE
- SEEN_TOOLS
- SUMMARY
- SUPPORTED_EXTENSIONS
- TOOL
- TOOL_CMD
- VERSION
