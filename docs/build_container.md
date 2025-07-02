# build_container.sh - 2025-07-02 19:39:31

[![Version](https://img.shields.io/badge/version-0.0.0-purple.svg)](./build_container.sh)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/build_container.md)
[![Size](https://img.shields.io/badge/size-2.9K-yellow)](./build_container.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--01-blue)](./build_container.sh)
[![Bash](https://img.shields.io/badge/bash-5--2--37-red)](https://www.gnu.org/software/bash/)

## Table of Contents
- High-level summary - build_container.sh
- Variables Set - build_container.sh

## High-level summary - build_container.sh
- !/usr/bin/env bash
- build-container.sh - Pure Docker build/tag/push script with versioning
- 🎨 Colors
- === Load .env file
- === Parse arguments
- === Build context
- === Handle version bump via .image_version
- === Build image
- === Optional log (output to build.log
- === Push tags
- === Optional cleanup

## Variables Set - build_container.sh
- BLUE
- BUILD_CONTEXT
- CLEANUP_ENABLED
- DOCKERFILE
- DOCKERHUB_REPO
- GREEN
- IFS
- LOG_ENABLED
- NC
- NEW_VERSION
- RED
- SCRIPT_DIR
- SERVICE_NAME
- TAG_LATEST
- TAG_VERSION
- VERSION
- VERSION_FILE
- VERSION_TYPE
- YELLOW
