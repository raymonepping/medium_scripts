# generate_documentation.sh - v1.6.0 - 2025-07-02 22:14:03

[![Version](https://img.shields.io/badge/version-1.6.0-purple.svg)](./generate_documentation.sh)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/generate_documentation.md)
[![Size](https://img.shields.io/badge/size-9.6K-yellow)](./generate_documentation.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--02-blue)](./generate_documentation.sh)
[![Bash](https://img.shields.io/badge/bash-5--2--37-red)](https://www.gnu.org/software/bash/)

## Table of Contents
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
