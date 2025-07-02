# bump_version.sh - 2025-07-02 15:51:23

[![Version](https://img.shields.io/badge/version-1.12.0-blue.svg)](./bump_version.sh)
[![Docs](https://img.shields.io/badge/docs-generated-success.svg)](./docs/bump_version.md)
[![Lint](https://img.shields.io/badge/lint-passing-brightgreen)](https://www.shellcheck.net/)
[![File Size](https://img.shields.io/badge/size-6.9K-yellow)](./bump_version.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--02-blue)](./bump_version.sh)

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
- Set derived metadata
- Set CHANGELOG file name, assuming the script is in the same directory as the CHANGELOG
- Normalize version numbers
- Validate extracted version
- Calculate next version to be used
- Construct new version string
- Handle version already bumped
- Dry-run behavior
- Safely replace VERSION line
- Check if original script was executable
- Replace VERSION line in script safely
- Restore executable flag if it was set originally
- Prepare to write to Changelog
- Create badge for version
- Write to CHANGELOG if enabled
- Generate success message
- Generate updated documentation for this script

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
- CONFIG
- Load ignore list
- Tool checks
- CLI flags
- Utility: Emoji echo
- Lint Badge Generation
- File Size Badge
- Last Updated Badge
- Summary Extraction
- Variable Extraction
- Detect Called Scripts
- Main Parser
- Entry Point

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

