# vault_radar_builder.sh - v1.0.0 - 2025-07-05 07:24:24

[![Version](https://img.shields.io/badge/version-1.0.0-purple.svg)](./vault_radar_builder.sh)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/vault_radar_builder.md)
[![Size](https://img.shields.io/badge/size-8.3KB-yellow)](./vault_radar_builder.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--05-blue)](./vault_radar_builder.sh)
[![Bash](https://img.shields.io/badge/bash-5--2--21-red)](https://www.gnu.org/software/bash/)

## Table of Contents
- High-level summary - vault_radar_builder.sh
- Variables Set - vault_radar_builder.sh

## High-level summary - vault_radar_builder.sh
- Defaults
- Parse CLI
- Input Validation
- Read Leaks, Filter by Scenario
- Parse Languages
- Pick random count within range
- Prepare Metadata
- Output Files Map
- Generate Headers
- Leak Injection Helpers
- Leak Reporting for Markdown
- Main Output Loop
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
- OUTDIR
- QUIET
- RUNID
- SCENARIO
- TIMESTAMP
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
