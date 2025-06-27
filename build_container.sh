#!/usr/bin/env bash

# build-container.sh - Pure Docker build/tag/push script with versioning
set -euo pipefail

# 🎨 Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RED='\033[0;31m'
NC='\033[0m'

# === Load .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  source "${SCRIPT_DIR}/.env"
  set +a
else
  echo -e "${RED}❌ .env file missing next to build-container.sh${NC}"
  exit 1
fi

DOCKERHUB_REPO="${DOCKERHUB_REPO:-}"
if [[ -z "$DOCKERHUB_REPO" ]]; then
  echo -e "${RED}❌ DOCKERHUB_REPO not set in .env${NC}"
  exit 1
fi

# === Parse arguments
SERVICE_NAME=""
LOG_ENABLED=false
CLEANUP_ENABLED=false
VERSION_TYPE="patch"

usage() {
  echo -e "${YELLOW}Usage: $0 --name <service> [--log] [--cleanup] [--minor|--major]${NC}"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --name)
    SERVICE_NAME="$2"
    shift 2
    ;;
  --log)
    LOG_ENABLED=true
    shift
    ;;
  --cleanup)
    CLEANUP_ENABLED=true
    shift
    ;;
  --minor)
    VERSION_TYPE="minor"
    shift
    ;;
  --major)
    VERSION_TYPE="major"
    shift
    ;;
  *) usage ;;
  esac
done

if [[ -z "$SERVICE_NAME" ]]; then usage; fi

# === Build context
BUILD_CONTEXT="${SCRIPT_DIR}/${SERVICE_NAME}"
if [[ ! -d "$BUILD_CONTEXT" ]]; then
  echo -e "${RED}❌ Build context folder '$BUILD_CONTEXT' does not exist.${NC}"
  exit 1
fi

DOCKERFILE="${BUILD_CONTEXT}/Dockerfile"
if [[ ! -f "$DOCKERFILE" ]]; then
  echo -e "${RED}❌ Dockerfile not found in ${DOCKERFILE}${NC}"
  exit 1
fi

# === Handle version bump via .image_version
VERSION_FILE="${BUILD_CONTEXT}/.image_version"
if [[ -f "$VERSION_FILE" ]]; then
  VERSION=$(cat "$VERSION_FILE")
  IFS='.' read -r major minor patch <<<"${VERSION:-0.0.0}"
else
  major=0
  minor=1
  patch=0
fi

case $VERSION_TYPE in
patch) patch=$((patch + 1)) ;;
minor)
  minor=$((minor + 1))
  patch=0
  ;;
major)
  major=$((major + 1))
  minor=0
  patch=0
  ;;
esac

NEW_VERSION="${major}.${minor}.${patch}"
echo "$NEW_VERSION" >"$VERSION_FILE"

echo -e "${BLUE}🔖 Using version: $NEW_VERSION${NC}"

# === Build image
TAG_VERSION="${DOCKERHUB_REPO}/${SERVICE_NAME}:${NEW_VERSION}"
TAG_LATEST="${DOCKERHUB_REPO}/${SERVICE_NAME}:latest"

echo -e "${BLUE}🏗️  Building Docker image as ${TAG_VERSION} ...${NC}"
docker build -t "$TAG_VERSION" -t "$TAG_LATEST" "$BUILD_CONTEXT"

# === Optional log (output to build.log)
if $LOG_ENABLED; then
  docker image inspect "$TAG_VERSION" >"${BUILD_CONTEXT}/build.log"
  echo -e "${YELLOW}📄 Build log written to ${BUILD_CONTEXT}/build.log${NC}"
fi

# === Push tags
echo -e "${GREEN}🚀 Pushing tags: $TAG_VERSION and $TAG_LATEST ...${NC}"
docker push "$TAG_VERSION"
docker push "$TAG_LATEST"

# === Optional cleanup
if $CLEANUP_ENABLED; then
  echo -e "${BLUE}🧹 Cleaning up dangling Docker images...${NC}"
  docker image prune -f
  echo -e "${GREEN}✅ Cleanup done.${NC}"
fi

echo -e "${GREEN}✅ Done! ${SERVICE_NAME} built and pushed. Version: $NEW_VERSION${NC}"
