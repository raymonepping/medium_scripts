# generate_documentation.sh - v2.5.0 - 2025-07-03 11:24:42

[![Version](https://img.shields.io/badge/version-2.5.0-purple.svg)](./generate_documentation.sh)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/generate_documentation.md)
[![Size](https://img.shields.io/badge/size-9.8KB-yellow)](./generate_documentation.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--03-blue)](./generate_documentation.sh)
[![Bash](https://img.shields.io/badge/bash-5--2--21-red)](https://www.gnu.org/software/bash/)

## Table of Contents
- High-level summary - generate_documentation.sh
- Variables Set - generate_documentation.sh

## High-level summary - generate_documentation.sh
- Handle --help and --version flags early
- Define configuration variables
- CLI flags, including output dir
- Set OUTPUT_DIR to ./docs if not set
- Load ignore list
- Tool checks
- Utility: Emoji echo
- Resolve input scripts (supporting $PATH and relative/absolute)

## Variables Set - generate_documentation.sh
- ARGS
- EMOJI_MODE
- GENERATED
- IGNORED_COMMANDS
- IGNORE_FILE
- INCLUDE_CALLED_SCRIPTS
- INCLUDE_LINT
- LINT_ENABLED
- MAX_DEPTH
- OUTPUT_DIR
- SCRIPT_DIR
- STRICT_MODE
- TOP_LEVEL_CALL
- VERSION
- VISITED
