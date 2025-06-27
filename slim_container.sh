#!/bin/bash

# slim_container.sh - Build, slim, scan, version, and optionally push Docker images.
# Supports: Hadolint, Dive, Trivy, Syft, Grype, Dockle (logs only)

set -euo pipefail
export PATH="/opt/homebrew/bin:$PATH"

# Load LOG_DIR and DOCKERHUB_REPO from .env
if [[ -f .env ]]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    export "$key=$value"
  done < <(grep -v '^\s*#' .env | grep '=')
else
  echo "❌ .env file not found."
  exit 1
fi

# Check DOCKERHUB_REPO is set
if [[ -z "${DOCKERHUB_REPO:-}" ]]; then
  echo "❌ DOCKERHUB_REPO not set in .env"
  exit 1
fi

# Default values
IMAGE=""
DOCKERFILE_PATH=""
SCAN=false
PUSH=false
ORIGINAL_IMAGE_NAME=""

# Create a timestamped log directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

print_help() {
  echo "Usage:"
  echo "  ./slim_container.sh --image <image-name> [--dockerfile <Dockerfile>] [--scan true] [--push true]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --image)
    shift
    IMAGE="$1"
    ORIGINAL_IMAGE_NAME=$(basename "$IMAGE")
    ;;
  --dockerfile)
    shift
    DOCKERFILE_PATH="$1"
    if [[ ! -f "$DOCKERFILE_PATH" ]]; then
      echo "❌ Dockerfile not found at: $DOCKERFILE_PATH"
      exit 1
    fi
    DOCKERFILE_DIR=$(dirname "$DOCKERFILE_PATH")
    # IMAGE_NAME="temp-$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')"
    IMAGE_NAME=$(basename "$DOCKERFILE_DIR")
    ORIGINAL_IMAGE_NAME="$IMAGE_NAME"
    IMAGE="$IMAGE_NAME"

    echo "📦 Building image from Dockerfile: $DOCKERFILE_PATH"
    DOCKERFILE_DIR=$(dirname "$DOCKERFILE_PATH")
    docker build -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" "$DOCKERFILE_DIR" >/dev/null
    IMAGE="$IMAGE_NAME"
    ;;
  --scan)
    shift
    SCAN="$1"
    ;;
  --push)
    shift
    PUSH="$1"
    ;;
  -h | --help)
    print_help
    exit 0
    ;;
  *)
    echo "❌ Unknown argument: $1"
    print_help
    exit 1
    ;;
  esac
  shift
done

if [[ -z "$IMAGE" ]]; then
  echo "❌ Image name is required."
  print_help
  exit 1
fi

# Create log path based on actual image name
RUN_LOG_DIR="${LOG_DIR}/${ORIGINAL_IMAGE_NAME}/${TIMESTAMP}"
mkdir -p "$RUN_LOG_DIR"

# Get folder for .image_version
if [[ -n "${DOCKERFILE_PATH:-}" ]]; then
  IMAGE_DIR=$(dirname "$DOCKERFILE_PATH")
else
  IMAGE_DIR="."
fi
VERSION_FILE="${IMAGE_DIR}/.image_version"

# Versioning logic
if [[ -f "$VERSION_FILE" ]]; then
  VERSION=$(cat "$VERSION_FILE")
  IFS='.' read -r MAJOR MINOR <<<"$VERSION"
  ((MINOR++))
  IMAGE_VERSION="${MAJOR}.${MINOR}"
else
  IMAGE_VERSION="1.0"
fi
echo "$IMAGE_VERSION" >"$VERSION_FILE"

ORIGINAL_SIZE=$(docker image inspect "$IMAGE" --format='{{.Size}}')
ORIGINAL_SIZE_MB=$((ORIGINAL_SIZE / 1024 / 1024))
echo "🔍 Optimizing image: $IMAGE (${ORIGINAL_SIZE_MB}MB)"

docker-slim build \
  --target "$IMAGE" \
  --http-probe=false \
  --continue-after=5 \
  --copy-meta-artifacts "$RUN_LOG_DIR" \
  >"${RUN_LOG_DIR}/docker_slim.log"

# SLIM_IMAGE_REPO="${IMAGE}.slim"
SLIM_IMAGE_REPO="${ORIGINAL_IMAGE_NAME}.slim"

SLIM_IMAGE_TAG="latest"
SLIM_IMAGE="${SLIM_IMAGE_REPO}:${SLIM_IMAGE_TAG}"

OPTIMIZED_SIZE=$(docker image inspect "$SLIM_IMAGE" --format='{{.Size}}')
OPTIMIZED_SIZE_MB=$((OPTIMIZED_SIZE / 1024 / 1024))
SAVED_MB=$((ORIGINAL_SIZE_MB - OPTIMIZED_SIZE_MB))
PERCENT=$((100 * SAVED_MB / ORIGINAL_SIZE_MB))

echo ""
echo "📊 Optimization Summary:"
echo "   Original size : ${ORIGINAL_SIZE_MB}MB"
echo "   Optimized size: ${OPTIMIZED_SIZE_MB}MB"
echo "   Space saved   : ${SAVED_MB}MB (${PERCENT}%)"
echo "✅ Done! Optimized image: ${SLIM_IMAGE}"
echo ""

# Tag with repo, version, and latest
REPO_IMAGE="${DOCKERHUB_REPO}/${ORIGINAL_IMAGE_NAME}:${IMAGE_VERSION}"
REPO_IMAGE_LATEST="${DOCKERHUB_REPO}/${ORIGINAL_IMAGE_NAME}:latest"
docker tag "$SLIM_IMAGE" "$REPO_IMAGE"
docker tag "$SLIM_IMAGE" "$REPO_IMAGE_LATEST"

if [[ "$SCAN" == "true" ]]; then
  echo "🛡️  Running security scans on ${SLIM_IMAGE} (logs only)"

  echo "🧪 Running Hadolint on Dockerfile..."
  if [[ -x "$(which hadolint 2>/dev/null)" ]]; then
    hadolint "$DOCKERFILE_PATH" >"${RUN_LOG_DIR}/hadolint.log" 2>&1 || true
    if [[ -s "${RUN_LOG_DIR}/hadolint.log" ]]; then
      echo "⚠️  Hadolint issues found. Check hadolint.log."
    else
      echo "✅ No Hadolint issues found!" | tee -a "${RUN_LOG_DIR}/scan_summary.log"
    fi
  else
    echo "⚠️  Hadolint not installed." | tee -a "${RUN_LOG_DIR}/scan_warnings.log"
  fi

  echo "🔬 Running Dive image analysis on ${SLIM_IMAGE}..."
  if [[ -x "$(which dive 2>/dev/null)" ]]; then
    dive "$SLIM_IMAGE" --ci >"${RUN_LOG_DIR}/dive_${SLIM_IMAGE_REPO}.log" 2>&1 || true
    [[ -s "${RUN_LOG_DIR}/dive_${SLIM_IMAGE_REPO}.log" ]] && echo "✔ Dive scan complete."
  else
    echo "⚠️  Dive not installed." | tee -a "${RUN_LOG_DIR}/scan_warnings.log"
  fi

  echo "🔍 Running Trivy scan..."
  if [[ -x "$(which trivy 2>/dev/null)" ]]; then
    trivy image --quiet --scanners vuln --severity HIGH,CRITICAL "$SLIM_IMAGE" >"${RUN_LOG_DIR}/trivy_${SLIM_IMAGE_REPO}.log" 2>&1 || true
    [[ -s "${RUN_LOG_DIR}/trivy_${SLIM_IMAGE_REPO}.log" ]] && echo "✔ Trivy scan complete."
  else
    echo "⚠️  Trivy not installed." | tee -a "${RUN_LOG_DIR}/scan_warnings.log"
  fi

  echo "📦 Running Syft SBOM scan..."
  if [[ -x "$(which syft 2>/dev/null)" ]]; then
    syft "$SLIM_IMAGE" -o json | jq '[.artifacts[] | {name, version, type}]' >"${RUN_LOG_DIR}/syft_${SLIM_IMAGE_REPO}.log" 2>/dev/null || true
    [[ -s "${RUN_LOG_DIR}/syft_${SLIM_IMAGE_REPO}.log" ]] && echo "✔ Syft SBOM generated."
  else
    echo "⚠️  Syft not installed." | tee -a "${RUN_LOG_DIR}/scan_warnings.log"
  fi

  echo "🚨 Running Grype vulnerability scan..."
  if [[ -x "$(which grype 2>/dev/null)" ]]; then
    grype "$SLIM_IMAGE" --only-fixed --fail-on high --quiet >"${RUN_LOG_DIR}/grype_${SLIM_IMAGE_REPO}.log" 2>&1 || true
    [[ -s "${RUN_LOG_DIR}/grype_${SLIM_IMAGE_REPO}.log" ]] && echo "✔️  Grype scan complete: grype_${SLIM_IMAGE_REPO}.log"
  else
    echo "⚠️  Grype not installed." | tee -a "${RUN_LOG_DIR}/scan_warnings.log"
  fi

  echo "🛡️  Running Dockle scan..."
  DOCKLE_LOG="${RUN_LOG_DIR}/dockle_${SLIM_IMAGE_REPO}.log"
  if docker image inspect "$SLIM_IMAGE" &>/dev/null; then
    if command -v dockle &>/dev/null; then
      dockle --exit-code 0 --format simple "$SLIM_IMAGE" >"$DOCKLE_LOG" 2>&1
      [[ -s "$DOCKLE_LOG" ]] && echo "✔ Dockle scan completed: $(basename "$DOCKLE_LOG")"
    else
      echo "⚠️  Dockle not installed." | tee -a "${RUN_LOG_DIR}/scan_warnings.log"
    fi
  else
    echo "❌ [ERROR] Optimized image $SLIM_IMAGE not found for Dockle"
  fi
fi

if [[ "$PUSH" == "true" ]]; then
  echo "🚀 Pushing images to Docker Hub..."
  docker push "$REPO_IMAGE"
  docker push "$REPO_IMAGE_LATEST"
  echo "✔ Images pushed: $REPO_IMAGE and $REPO_IMAGE_LATEST"
fi
