# build_image.sh - 2025-07-02 20:05:56

⚠️ No version detected — please run `bump_version` against this script.

[![Version](https://img.shields.io/badge/version-0.0.0-purple.svg)](./build_image)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/build_image.md)
[![Size](https://img.shields.io/badge/size-3.1K-yellow)](./build_image)
[![Updated](https://img.shields.io/badge/updated-2025--07--01-blue)](./build_image)
[![Bash](https://img.shields.io/badge/bash-5--2--37-red)](https://www.gnu.org/software/bash/)

## Table of Contents
- High-level summary - build_image.sh
- Variables Set - build_image.sh

## High-level summary - build_image.sh
- !/usr/bin/env bash
- Load .env variables
- 🚀 Parse arguments
- 🔧 CONFIG
- 🔁 VERSION BUMP
- 🏗️ BUILD
- 📄 version.json
- 🔗 Symlink latest
- 🛰 PUSH
- 🧪 SCAN

## Variables Set - build_image.sh
- BUMP_TYPE
- DOCKERHUB_REPO
- IFS
- LOG_DIR
- NEW_VERSION
- ORIGINAL_IMAGE_NAME
- PACKER_FILE
- RUN_LOG_DIR
- SCAN
- TIMESTAMP
- VERSION
- VERSION_FILE
