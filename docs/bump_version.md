# bump_version.sh - v1.12.4 - 2025-07-05 05:53:20

[![Version](https://img.shields.io/badge/version-1.12.4-purple.svg)](./bump_version.sh)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/bump_version.md)
[![Size](https://img.shields.io/badge/size-7.3KB-yellow)](./bump_version.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--05-blue)](./bump_version.sh)
[![Bash](https://img.shields.io/badge/bash-5--2--21-red)](https://www.gnu.org/software/bash/)

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
- Insert # shellcheck disable=SC2034 above VERSION if missing
- Replace VERSION in script safely
- Write to CHANGELOG if enabled
- Replace VERSION in script safely and preserve +x permissions

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
