#!/usr/bin/env bash
set -euo pipefail

# Load .env variables
if [[ -f .env ]]; then
  echo "🔄 Loading .env file..."
  set -o allexport
  source .env
  set +o allexport
else
  echo "❌ .env file not found."
  exit 1
fi

# ────────────────────────────────────────────────
# 🚀 Parse arguments
SCAN=false
BUMP_TYPE="patch"

for arg in "$@"; do
  case "$arg" in
    --scan)
      SCAN=true
      ;;
    patch|minor|major)
      BUMP_TYPE="$arg"
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      echo "Usage: $0 [patch|minor|major] [--scan]"
      exit 1
      ;;
  esac
done

# ────────────────────────────────────────────────
# 🔧 CONFIG
VERSION_FILE=".image_version"
PACKER_FILE="docker-ubuntu.pkr.hcl"
LOG_DIR="${LOG_DIR:-./logs}"
DOCKERHUB_REPO="repping/ubuntu_hardened"
ORIGINAL_IMAGE_NAME=$(basename "$DOCKERHUB_REPO")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RUN_LOG_DIR="${LOG_DIR}/${ORIGINAL_IMAGE_NAME}/${TIMESTAMP}"

mkdir -p "$RUN_LOG_DIR"

# ────────────────────────────────────────────────
# 🔁 VERSION BUMP
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "v0.1.0" > "$VERSION_FILE"
fi

VERSION=$(cat "$VERSION_FILE")
IFS='.' read -r MAJOR MINOR PATCH <<<"${VERSION#v}"

case "$BUMP_TYPE" in
  major) ((MAJOR+=1)); MINOR=0; PATCH=0 ;;
  minor) ((MINOR+=1)); PATCH=0 ;;
  patch) ((PATCH+=1)) ;;
esac

NEW_VERSION="v$MAJOR.$MINOR.$PATCH"
echo "$NEW_VERSION" > "$VERSION_FILE"

echo "📦 New image version: $NEW_VERSION"
echo "🔧 Running Packer build..."

# ────────────────────────────────────────────────
# 🏗️ BUILD
packer build -var "image_tag=$NEW_VERSION" "$PACKER_FILE" \
  | tee "${RUN_LOG_DIR}/build.log"

docker tag "$DOCKERHUB_REPO:$NEW_VERSION" "$DOCKERHUB_REPO:latest"
echo "🏷️  Tagged locally as: $DOCKERHUB_REPO:latest (not pushed)"

# 📄 version.json
cat > "${RUN_LOG_DIR}/version.json" <<EOF
{
  "version": "${NEW_VERSION}",
  "timestamp": "${TIMESTAMP}"
}
EOF

# 🔗 Symlink latest
ln -sfn "$RUN_LOG_DIR" "${LOG_DIR}/latest_build"
echo "🔗 Linked ${LOG_DIR}/latest_build → ${RUN_LOG_DIR}"

# ────────────────────────────────────────────────
# 🛰 PUSH
echo "🚀 Pushing image to Docker Hub..."
docker push "$DOCKERHUB_REPO:$NEW_VERSION"

echo "✅ Done. Image pushed: $DOCKERHUB_REPO:$NEW_VERSION"

# ────────────────────────────────────────────────
# 🧪 SCAN
if [[ "$SCAN" == "true" ]]; then
  echo ""
  echo "🧪 Scanning image..."
  scan_container --container "$DOCKERHUB_REPO"
  echo ""
  echo "🔍 Scan completed. Check logs in $LOG_DIR"
fi
echo "✅ Build and scan process completed successfully."