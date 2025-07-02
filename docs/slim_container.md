# slim_container.sh - 2025-07-02 19:39:32

[![Version](https://img.shields.io/badge/version-0.0.0-purple.svg)](./slim_container.sh)
[![Docs](https://img.shields.io/badge/docs-generated-orange.svg)](./docs/slim_container.md)
[![Size](https://img.shields.io/badge/size-6.7K-yellow)](./slim_container.sh)
[![Updated](https://img.shields.io/badge/updated-2025--07--01-blue)](./slim_container.sh)
[![Bash](https://img.shields.io/badge/bash-5--2--37-red)](https://www.gnu.org/software/bash/)

## Table of Contents
- High-level summary - slim_container.sh
- Variables Set - slim_container.sh

## High-level summary - slim_container.sh
- !/bin/bash
- slim_container.sh - Build, slim, scan, version, and optionally push Docker images
- Supports: Hadolint, Dive, Trivy, Syft, Grype, Dockle (logs only
- Load LOG_DIR and DOCKERHUB_REPO from .env
- Check DOCKERHUB_REPO is set
- Default values
- Create a timestamped log directory
- Create log path based on actual image name
- Get folder for .image_version
- Versioning logic
- SLIM_IMAGE_REPO="${IMAGE}.slim
- Tag with repo, version, and latest

## Variables Set - slim_container.sh
- DOCKERFILE_DIR
- DOCKERFILE_PATH
- DOCKLE_LOG
- IFS
- IMAGE
- IMAGE_DIR
- IMAGE_NAME
- IMAGE_VERSION
- OPTIMIZED_SIZE
- OPTIMIZED_SIZE_MB
- ORIGINAL_IMAGE_NAME
- ORIGINAL_SIZE
- ORIGINAL_SIZE_MB
- PERCENT
- PUSH
- REPO_IMAGE
- REPO_IMAGE_LATEST
- RUN_LOG_DIR
- SAVED_MB
- SCAN
- SLIM_IMAGE
- SLIM_IMAGE_REPO
- SLIM_IMAGE_TAG
- TIMESTAMP
- VERSION
- VERSION_FILE
