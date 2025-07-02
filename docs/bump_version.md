# bump_version.sh - v1.12.0 - 2025-07-02 21:39:28

[![Version](https://img.shields.io/badge/version-1.12.0-purple.svg)](./bump_version.sh)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/bump_version.md)
[![Size](https://img.shields.io/badge/size-6.0K-yellow)](./bump_version.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--02-blue)](./bump_version.sh)
[![Bash](https://img.shields.io/badge/bash-5--2--37-red)](https://www.gnu.org/software/bash/)

## Table of Contents
- High-level summary - bump_version.sh
- Variables Set - bump_version.sh

## High-level summary - bump_version.sh
- Define Colors for Output
- Setting Defaults to be used later
- Parse script arguments
- Handle --help flag
- Handling additional flags
- Validate bump type
- Resolve script path
- Find and validate VERSION line
- Normalize version numbers
- Validate extracted version
- Calculate next version
- DRY RUN
- Replace VERSION in script safely
- Write to CHANGELOG if enabled

## Variables Set - bump_version.sh
- BADGE
- BUMP_TYPE
- CHANGELOG
- CYAN
- DRY_RUN
- GREEN
- IFS
- NR
- RAW_SCRIPT
- RED
- RESET
- SCRIPT_BASENAME
- SCRIPT_PATH
- TMPFILE
- VERSION
- WRITE_CHANGELOG
- YELLOW

- High-level summary - generate_documentation.sh
- Variables Set - generate_documentation.sh

## High-level summary - generate_documentation.sh
- Handle --help and --version flags early
- Handle --version flag
- Define configuration variables
- Load ignore list
- Tool checks
- CLI flags
- Utility: Emoji echo
- Lint Badge Generation
- Bash Version Badge Generation
- File Size Badge Generation
- Last Updated Badge Generation
- Compose Badges Line
- Summary Extraction
- Variable Extraction
- Detect Called Scripts
- Main Parser
- Generate Entry Point
- Remove all trailing blank lines in generated markdown files

## Variables Set - generate_documentation.sh
- ARGS
- CLEAN_MODE
- EMOJI_MODE
- GENERATED
- IGNORE_FILE
- IGNORED_COMMANDS
- INCLUDE_CALLED_SCRIPTS
- INCLUDE_LINT
- LINT_ENABLED
- MAX_DEPTH
- OUTPUT_DIR
- SCRIPT_DIR
- STRICT_MODE
- SUMMARY_MODE
- TOP_LEVEL_CALL
- VERSION
- VISITED
