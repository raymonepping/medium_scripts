# release_update.sh - v1.1.0 - 2025-07-16 12:28:29

[![Version](https://img.shields.io/badge/version-1.1.0-purple.svg)](./release_update.sh)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/release_update.md)
[![Size](https://img.shields.io/badge/size-9.6KB-yellow)](./release_update.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--16-blue)](./release_update.sh)
[![Bash](https://img.shields.io/badge/bash-5--2--21-red)](https://www.gnu.org/software/bash/)

## Table of Contents
- High-level summary - release_update.sh
- Variables Set - release_update.sh

## High-level summary - release_update.sh
- UTILS: Strict Mode Toggle
- Defaults / Args
- Parse Args
- Dependency Check
- Step 1: repository_backup
- Step 2: sanity_check (non-blocking)
- Step 3: bump_version
- Step 4: self_doc
- Step 5: commit_gh
- Step 6: repository_audit
- Bump all scripts to the new version
- Step: Brew Formula Check
- Main function
- Run the main function

## Variables Set - release_update.sh
- AUDIT_DEST
- BIN
- BUMP
- BUMP_FILE
- DEFAULT_LOG
- DEST
- DRYRUN
- IFS
- LOG
- SCRIPT_NAME
- SKIP_AUDIT
- SKIP_BACKUP
- SKIP_BUMP
- SKIP_COMMIT
- SKIP_DOC
- SYNC_VERSION
- TARGET
- TPL
- VERSION
